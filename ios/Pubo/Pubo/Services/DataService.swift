import SwiftData
import Foundation
import Combine
import SwiftUI

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    var modelContext: ModelContext?
    
    @Published var isProcessingLink: Bool = false
    @Published var linkProgress: Double = 0.0
    @Published var readyImport: PendingImport? = nil
    @Published var pendingImport: PendingImport? = nil
    @Published var curatedPosts: [CuratedPost] = []
    
    private init() {}
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        // 初始化快取，用於快速重複偵測
        preloadCollectionStats()
    }
    
    /// 同步收藏到雲端並包含指定的景點 ID
    func syncCollectionWithPlaces(url: String, placeIds: [String]) async {
        do {
            let collectionUrl = URL(string: "\(baseURL)/collection")!
            var request = URLRequest(url: collectionUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "url": url,
                "place_ids": placeIds
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("📡 [DataService] Sync Collection with \(placeIds.count) places Status: \(status)")
            if status != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                print("❌ [DataService] Sync failed: \(errorBody)")
            }
        } catch {
            print("❌ [DataService] Sync error: \(error)")
        }
    }
    
    // --- 防重複辨認機制 ---
    
    @Published var collectedIds: Set<String> = []
    @Published var collectedTitles: Set<String> = []
    
    /// 提取網址的唯一識別碼 (例如 IG Shortcode)
    func extractCanonicalID(from urlString: String) -> String {
        // 去除空格與網址參數之前的雜訊
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 強化版 Regex: 捕捉 /p/ 或 /reels/ 或 /tv/ 後面的 10-12 位 ID
        // 支援包含 /share/ 或其他路徑的情況
        let pattern = "(?:/p/|/reels/|/tv/|/sh/)([^/?#\\s]+)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = cleanUrl as NSString
            let results = regex.matches(in: cleanUrl, options: [], range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges > 1 {
                let id = nsString.substring(with: match.range(at: 1))
                // 去除可能帶到的結尾斜線
                return id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        
        // 如果不是 IG 或是連不到，就返回原始網址去除 Parameter 的結果
        return cleanUrl.components(separatedBy: "?").first ?? cleanUrl
    }
    
    /// 自動清理重複的收藏 (三合一)
    private func cleanupDuplicates() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<SDContent>()
        do {
            let contents = try context.fetch(descriptor)
            var seenIds = Set<String>()
            var duplicatesCount = 0
            
            // 排序：讓舊的排前面，保留最舊的一份（或開發者自訂邏輯）
            let sortedContents = contents.sorted { $0.createdAt < $1.createdAt }
            
            for post in sortedContents {
                let id = extractCanonicalID(from: post.sourceUrl ?? "")
                if seenIds.contains(id) {
                    context.delete(post)
                    duplicatesCount += 1
                } else {
                    seenIds.insert(id)
                }
            }
            
            if duplicatesCount > 0 {
                try context.save()
                print("🧹 [DataService] Cleaned up \(duplicatesCount) duplicates from collection")
                // 重新刷新快取
                self.collectedIds = seenIds
                self.collectedTitles = Set(contents.compactMap { $0.title })
            }
        } catch {
            print("❌ [DataService] Cleanup failed: \(error)")
        }
    }
    
    /// 預加載現有的收藏 ID 與標題
    private func preloadCollectionStats() {
        guard let context = modelContext else { return }
        
        // 先執行清理
        cleanupDuplicates()
        
        let descriptor = FetchDescriptor<SDContent>()
        do {
            let contents = try context.fetch(descriptor)
            self.collectedIds = Set(contents.compactMap { $0.sourceUrl }.map { extractCanonicalID(from: $0) })
            self.collectedTitles = Set(contents.compactMap { $0.title })
            print("📊 [DataService] Preloaded \(collectedIds.count) IDs and \(collectedTitles.count) Titles")
        } catch {
            print("❌ [DataService] Preload failed: \(error)")
        }
    }
    
    /// 檢查貼文是否已收藏 (使用 ID 與標題雙重過濾)
    func isPostCollected(url: String, title: String? = nil) -> Bool {
        let id = extractCanonicalID(from: url)
        if collectedIds.contains(id) { return true }
        if let t = title, !t.isEmpty && collectedTitles.contains(t) { return true }
        return false
    }
    
    /// 手動加入快取 (供其他 Manager 呼叫)
    func addToCache(url: String, title: String? = nil) {
        let id = extractCanonicalID(from: url)
        self.collectedIds.insert(id)
        if let t = title { self.collectedTitles.insert(t) }
    }
    
    /// 從雲端收藏庫移除
    private func removeFromCloudCollection(url: String) async {
        do {
            var components = URLComponents(string: "\(baseURL)/collection")
            components?.queryItems = [URLQueryItem(name: "url", value: url)]
            
            guard let deleteUrl = components?.url else { return }
            
            var request = URLRequest(url: deleteUrl)
            request.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("📡 [DataService] Cloud Remove Status: \(status)")
        } catch {
            print("❌ [DataService] Cloud Remove error: \(error)")
        }
    }
    
    /// 從收藏庫移除 (本地 + 雲端同步)
    func removeFromCollection(url: String) async {
        guard let context = modelContext else { return }
        let id = extractCanonicalID(from: url)
        
        // 1. 雲端連動刪除
        await removeFromCloudCollection(url: url)
        
        // 2. 本地 SwiftData 刪除
        await MainActor.run {
            let descriptor = FetchDescriptor<SDContent>()
            do {
                let contents = try context.fetch(descriptor)
                if let post = contents.first(where: { extractCanonicalID(from: $0.sourceUrl ?? "") == id }) {
                    let oldTitle = post.title
                    context.delete(post)
                    try context.save()
                    
                    // 更新快取
                    self.collectedIds.remove(id)
                    if let t = oldTitle { self.collectedTitles.remove(t) }
                    
                    print("✅ [DataService] Removed from collection: \(id)")
                }
            } catch {
                print("❌ [DataService] Remove failed: \(error)")
            }
        }
    }
    
    /// 儲存內容與地點
    /// - Parameters:
    ///   - content: 原始 Content Struct
    ///   - relatedPlaces: 關聯的地點資訊列表
    ///   - unresolvedQueries: 無法自動對齊的地點名稱
    func saveContent(_ content: Content, relatedPlaces: [ContentPlaceInfo], unresolvedQueries: [String] = []) {
        guard let context = modelContext else {
            print("DataService Error: Context not set")
            return
        }
        
        Task {
            // 1. 同步到雲端收藏庫 (帶景點 ID)
            let placeIds = relatedPlaces.map { $0.place.placeId }.filter { !$0.isEmpty }
            await syncCollectionWithPlaces(url: content.sourceUrl, placeIds: placeIds)
            
            // 2. 本地 SwiftData 儲存 (為了離線存取與效能)
            await MainActor.run {
                do {
                    let contentId = content.sourceUrl
                    var sdContent: SDContent!
                    
                    let contentDescriptor = FetchDescriptor<SDContent>()
                    let allContent = try context.fetch(contentDescriptor)
                    let canonicalId = extractCanonicalID(from: contentId)
                    
                    if let existingContent = allContent.first(where: { extractCanonicalID(from: $0.sourceUrl ?? "") == canonicalId }) {
                        sdContent = existingContent
                        sdContent.unresolvedQueries = unresolvedQueries
                    } else {
                        sdContent = SDContent(
                            sourceType: content.sourceType.rawValue,
                            sourceUrl: content.sourceUrl,
                            title: content.title,
                            text: content.text,
                            authorName: content.authorName,
                            authorAvatarUrl: content.authorAvatarUrl,
                            previewThumbnailUrl: content.previewThumbnailUrl,
                            publishedAt: content.publishedAt,
                            unresolvedQueries: unresolvedQueries
                        )
                        context.insert(sdContent)
                    }
                    
                    // 更新快取
                    self.collectedIds.insert(canonicalId)
                    if let t = content.title { self.collectedTitles.insert(t) }
                    
                    for info in relatedPlaces {
                        let place = info.place
                        let placeId = place.placeId
                        
                        var openingHoursJSON: String? = nil
                        if let hours = place.openingHours {
                            if let data = try? JSONEncoder().encode(hours) {
                                openingHoursJSON = String(data: data, encoding: .utf8)
                            }
                        }
                        
                        let placeDescriptor = FetchDescriptor<SDPlace>(predicate: #Predicate { $0.id == placeId })
                        if let existingPlace = try context.fetch(placeDescriptor).first {
                            if existingPlace.openingHours == nil {
                                existingPlace.openingHours = openingHoursJSON
                            }
                            if let cloudImg = place.imageUrl {
                                existingPlace.imageUrl = cloudImg
                            }
                            // Link to content if missing
                            if !existingPlace.contents.contains(where: { $0.id == sdContent.id }) {
                                existingPlace.contents.append(sdContent)
                            }
                        } else {
                            let sdPlace = SDPlace(
                                id: place.placeId,
                                name: place.name,
                                address: place.address,
                                latitude: place.latitude,
                                longitude: place.longitude,
                                category: place.category,
                                rating: place.rating,
                                userRatingCount: place.userRatingCount,
                                openNow: place.openNow,
                                confidenceScore: info.confidenceScore,
                                openingHours: openingHoursJSON
                            )
                            sdPlace.imageUrl = place.imageUrl
                            context.insert(sdPlace)
                            sdPlace.contents.append(sdContent)
                        }
                    }
                    try context.save()
                    print("✅ [DataService] Local save successful for \(relatedPlaces.count) places")
                } catch {
                    print("❌ [DataService] Local save error: \(error)")
                }
            }
        }
    }
    
    /// 從雲端抓取所有已收藏的內容
    func fetchCollectionFromCloud() async throws -> [Content] {
        let url = URL(string: "\(baseURL)/collection")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = jsonDecoder
        return try decoder.decode([Content].self, from: data)
    }
    
    /// 上次同步雲端的時間 (門禁機制，防止無限迴圈)
    private var lastSyncTime: Date?
    
    /// 以雲端為準的同步機制 (鏡像同步，自動清除手機殘留)
    func syncCloudCollectionToLocal() async {
        guard let context = modelContext else { return }
        
        // 門禁機制：如果距離上次同步不到 300 秒 (5 分鐘)，則跳過以節省效能並防止無限循環
        if let last = lastSyncTime, Date().timeIntervalSince(last) < 300 {
            print("⏳ [DataService] Skipping mirror sync (sync currently throttled)")
            return
        }
        
        do {
            lastSyncTime = Date()
            print("🔄 [DataService] Starting Cloud Mirror Sync...")
            
            // 1. 抓取目前雲端最準確的名單
            let cloudContents = try await fetchCollectionFromCloud()
            
            // 2. 建立雲端 Canonical ID 集合
            let cloudIds = Set(cloudContents.map { extractCanonicalID(from: $0.sourceUrl) })
            
            // 3. 遍歷本地所有 SDContent 進行「校對與剪枝 (Pruning)」
            await MainActor.run {
                do {
                    let descriptor = FetchDescriptor<SDContent>()
                    let localResults = try context.fetch(descriptor)
                    var prunedCount = 0
                    
                    for localContent in localResults {
                        let localId = extractCanonicalID(from: localContent.sourceUrl ?? "")
                        
                        // 如果這篇貼文在雲端「不存在」，且它不屬於本地新建立的草稿，就把它刪掉
                        if !cloudIds.contains(localId) {
                            context.delete(localContent)
                            prunedCount += 1
                        }
                    }
                    
                    // 4. 重建快取清單以反映最新狀態
                    self.collectedIds = cloudIds
                    self.collectedTitles = Set(cloudContents.compactMap { $0.title })
                    
                    // 5. 將雲端有但本地沒有的補齊
                    for cloudItem in cloudContents {
                        saveContent(cloudItem, relatedPlaces: cloudItem.places ?? [])
                    }
                    
                    try context.save()
                    print("✅ [DataService] Sync complete. \(cloudContents.count) in cloud. \(prunedCount) local zombies pruned.")
                } catch {
                    print("❌ [DataService] Sync processing failed: \(error)")
                }
            }
        } catch {
            print("☁️ [DataService] Sync failed (Server might be down): \(error)")
        }
    }
    
    /// 取得所有地點
    func fetchAllPlaces() -> [SDPlace] {
        guard let context = modelContext else { return [] }
        do {
            return try context.fetch(FetchDescriptor<SDPlace>())
        } catch {
            print("Fetch Error: \(error)")
            return []
        }
    }
    /// 從後端獲取任務結果並回傳
    func fetchTaskResult(taskId: String) async throws -> TaskResponse {
        // 使用 Localhost URL
        let urlString = "\(baseURL)/task/\(taskId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        print("🔗 [AGENT_VERIFIED_DataService] Fetching: \(urlString)")
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 20  // 增加到 20 秒，容忍 Vercel 冷啟動
        
        // 使用 async API
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 偵錯日誌：顯示伺服器狀態碼
        print("📡 [DataService] Server Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 {
            // 任務尚未進入資料庫 (後端延遲)
            print("⏳ [DataService] Task not found on server yet (404).")
            throw NSError(domain: "PuboError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
        
        if httpResponse.statusCode == 500 {
            print("❌ [DataService] Server Error (500). Please check Vercel Logs.")
            throw NSError(domain: "PuboError", code: 500, userInfo: [NSLocalizedDescriptionKey: "伺服器發生錯誤 (500)，請檢查後端配置。"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let taskResponse = try jsonDecoder.decode(TaskResponse.self, from: data)
        return taskResponse
    }
    
    func submitShareTask(url: String) async throws -> String {
        let urlString = "\(baseURL)/share"
        guard let apiURL = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: apiURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["url": url]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = jsonDecoder
        let result = try decoder.decode(TaskResponse.self, from: data)
        return result.taskId
    }
    
    func startSmartImport(url: String) {
        self.isProcessingLink = true
        self.linkProgress = 0.0
        self.readyImport = nil
        
        Task {
            do {
                let taskId = try await submitShareTask(url: url)
                resumeTask(taskId: taskId)
            } catch {
                self.isProcessingLink = false
                print("Start smart import error: \(error)")
            }
        }
    }
    
    func resumeTask(taskId: String) {
        self.isProcessingLink = true
        self.linkProgress = 0.0
        self.readyImport = nil
        
        Task {
            if let (content, places) = await pollTaskResult(taskId: taskId) {
                self.isProcessingLink = false
                self.readyImport = PendingImport(content: content, places: places)
            } else {
                self.isProcessingLink = false
            }
        }
    }
    
    func analyzeScreenshot(imageData: Data, mimeType: String = "image/jpeg") async throws -> (Content, [ContentPlaceInfo]) {
        let urlString = "\(baseURL)/analyze/screenshot"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var uploadData = imageData
        if let image = UIImage(data: imageData),
           let compressed = image.jpegData(compressionQuality: 0.1) {
            uploadData = compressed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"screenshot.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(uploadData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "Unreadable binary data"
        print("📡 [DataService] Screenshot API Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            print("❌ [DataService] Screenshot analysis failed (Not 200). Raw body:\n\(responseString)")
            throw NSError(domain: "PuboError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "截圖辨識失敗 (狀態碼: \(httpResponse.statusCode))，無法提取景點。"])
        }
        
        do {
            let result = try jsonDecoder.decode(ExtractionResponse.self, from: data)
            return (result.content, result.suggestedPlaces)
        } catch {
            print("❌ [DataService] JSON Decode Failed! Raw Server Response:\n\(responseString)")
            throw error
        }
    }
    
    /// 輪詢任務直到完成或失敗 (適合處理 YouTube/Threads 等長任務)
    /// Default: 90 retries * 2s = 180s (3 minutes)
    func pollTaskResult(taskId: String, maxRetries: Int = 90) async -> (Content, [ContentPlaceInfo])? {
        print("🔄 [AGENT_VERIFIED_DataService] Start polling for task: \(taskId)")
        var attempts = 0
        
        while attempts < maxRetries {
            do {
                let taskResponse = try await fetchTaskResult(taskId: taskId)
                if taskResponse.status == .completed, let result = taskResponse.result {
                    print("✅ Task \(taskId) completed.")
                    return (result.content, result.suggestedPlaces)
                } else if taskResponse.status == .failed {
                    print("❌ Task \(taskId) failed: \(taskResponse.error ?? "Unknown")")
                    return nil
                } else {
                    if let progress = taskResponse.progress {
                        self.linkProgress = progress
                    }
                    print("⏳ Task \(taskId) is still processing... (Attempt \(attempts + 1)/\(maxRetries))")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 等待 2 秒
                    attempts += 1
                }
            } catch {
                print("⚠️ [DataService] Error polling task: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 等待 2 秒
                attempts += 1
            }
        }
        print("❌ Polling timeout for task: \(taskId)")
        return nil
    }
    
    // MARK: - Trip Planning API (Backend Phase 2)
    private let baseURL = "https://pubo-api-641234109681.asia-east1.run.app/api/v1"
    
    // Helper to decode dates correctly
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Clean date string: replace space with T for ISO consistency if needed
            let cleanedDate = dateString.replacingOccurrences(of: " ", with: "T")
            
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // 1. Try yyyy-MM-dd (Standard Date)
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: cleanedDate) {
                return date
            }
            
            // 2. Try ISO8601 (Full Timestamp)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: cleanedDate) {
                return date
            }
            
            // 3. Try ISO with Microseconds
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            if let date = formatter.date(from: cleanedDate) {
                return date
            }
             
            // 4. Try Standard ISO8601 Strategy callback (fallback)
            if let date = ISO8601DateFormatter().date(from: cleanedDate) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        // 注意：這裡不使用 .convertFromSnakeCase，因為模型已手動定義 CodingKeys 對應
        return decoder
    }
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        encoder.dateEncodingStrategy = .formatted(formatter)
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
    
    func fetchTrips() async throws -> [Trip] {
        let url = URL(string: "\(baseURL)/trips")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([Trip].self, from: data)
    }
    
    func createTrip(title: String, destination: String, startDate: Date, endDate: Date, transportMode: String) async throws -> Trip {
        let url = URL(string: "\(baseURL)/trips")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use a temporary struct for creation payload to match backend expectation
        struct TripCreatePayload: Encodable {
            let title: String
            let destination: String
            let start_date: Date
            let end_date: Date
            let transport_mode: String
        }
        
        let payload = TripCreatePayload(
            title: title,
            destination: destination,
            start_date: startDate,
            end_date: endDate,
            transport_mode: transportMode
        )
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("Create Error: \(body)")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(Trip.self, from: data)
    }
    
    func getTrip(id: String) async throws -> Trip {
        let url = URL(string: "\(baseURL)/trips/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try jsonDecoder.decode(Trip.self, from: data)
    }
    
    func deleteTrip(id: String) async throws {
        let url = URL(string: "\(baseURL)/trips/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func updateTrip(id: String, title: String? = nil, destination: String? = nil, startDate: Date? = nil, endDate: Date? = nil, transportMode: String? = nil) async throws -> Trip {
        let url = URL(string: "\(baseURL)/trips/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TripUpdatePayload: Encodable {
            let title: String?
            let destination: String?
            let start_date: Date?
            let end_date: Date?
            let transport_mode: String?
        }
        
        let payload = TripUpdatePayload(
            title: title,
            destination: destination,
            start_date: startDate,
            end_date: endDate,
            transport_mode: transportMode
        )
        
        request.httpBody = try jsonEncoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(Trip.self, from: data)
    }
    
    // MARK: - Spots API
    
    func addSpot(dayId: Int, spot: ItinerarySpot) async throws -> ItinerarySpot {
        let url = URL(string: "\(baseURL)/days/\(dayId)/spots")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode spot (excluding ID/dayId which are ignored/handled by backend creation)
        // But backend expects fields like name, category, notes, start_time...
        request.httpBody = try jsonEncoder.encode(spot)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            print("Add Spot Error: \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(ItinerarySpot.self, from: data)
    }
    
    func updateSpot(spot: ItinerarySpot) async throws -> ItinerarySpot {
        let url = URL(string: "\(baseURL)/spots/\(spot.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try jsonEncoder.encode(spot)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
             throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(ItinerarySpot.self, from: data)
    }
    
    func deleteSpot(spotId: String) async throws {
        let url = URL(string: "\(baseURL)/spots/\(spotId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func reorderSpots(dayId: Int, spotIds: [String]) async throws {
        var components = URLComponents(string: "\(baseURL)/spots/reorder")!
        components.queryItems = [URLQueryItem(name: "day_id", value: String(dayId))]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(spotIds)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Curated Posts API
    
    func promoteToCurated(content: Content, places: [ContentPlaceInfo]) async throws {
        let url = URL(string: "\(baseURL)/curated")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Transform places to the simple dictionary format expected by the backend
        let spots = places.map { info -> [String: Any] in
            return [
                "place_id": info.place.placeId,
                "name": info.place.name,
                "category": info.place.category ?? "景點",
                "latitude": info.place.latitude,
                "longitude": info.place.longitude
            ]
        }
        
        // Use actual post caption as title (truncated), fallback to content.title
        var displayTitle = content.title ?? "來自社群的推薦"
        if let text = content.text, !text.isEmpty {
            // Remove common hashtags and links from first line
            let lines = text.components(separatedBy: "\n")
            let firstNonEmptyRow = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? text
            let processed = firstNonEmptyRow
                .replacingOccurrences(of: "#[\\w\\d]+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !processed.isEmpty {
                displayTitle = String(processed.prefix(35))
            }
        }
        
        let payload: [String: Any] = [
            "title": displayTitle,
            "cover_image": content.previewThumbnailUrl ?? "",
            "author": content.authorName ?? "未知作者",
            "source_url": content.sourceUrl,
            "spots": spots,
            "spot_count": spots.count,
            "country": "" // Allow backend to auto-detect
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("📤 [Curated] Promoting post: \(content.title ?? "?") with \(spots.count) spots")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        print("📡 [Curated] Response status: \(httpResponse?.statusCode ?? -1)")
        
        if let statusCode = httpResponse?.statusCode, statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ [Curated] Server error body: \(body)")
            throw URLError(.badServerResponse)
        }
        
        // 🔄 Success! Now refresh the home screen list immediately
        print("✅ [Curated] Promotion successful, refreshing list...")
        fetchCuratedPosts()
    }
    

    func fetchCuratedPosts(country: String? = nil) {
        Task {
            do {
                var urlString = "\(baseURL)/curated"
                if let country = country {
                    urlString += "?country=\(country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                
                guard let url = URL(string: urlString) else { return }
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                
                let decoder = jsonDecoder
                let posts = try decoder.decode([CuratedPost].self, from: data)
                
                if let first = posts.first {
                    print("📸 [DataService] Decoded CuratedPost: \(first.title), Image URL: \(first.coverImageUrl ?? "nil")")
                }
                
                self.curatedPosts = posts
                print("✅ [DataService] Fetched \(posts.count) curated posts")
            } catch {
                print("❌ [DataService] Fetch curated posts failed: \(error)")
            }
        }
    }
}
