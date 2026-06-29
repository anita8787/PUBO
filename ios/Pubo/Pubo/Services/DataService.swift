import SwiftData
import Foundation
import Combine
import SwiftUI
import FirebaseStorage
import CryptoKit
struct LinkAnalysisTask: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var url: String
    var taskId: String? = nil
    var status: TaskStatus = .pending
    var progress: Double = 0.0
    var content: Content? = nil
    var places: [ContentPlaceInfo] = []
    var errorMessage: String? = nil
    var createdAt: Date = Date()
    var isImported: Bool = false
    
    enum TaskStatus: String, Equatable, Codable {
        case pending
        case analyzing
        case completed
        case failed
    }
    
    static func == (lhs: LinkAnalysisTask, rhs: LinkAnalysisTask) -> Bool {
        return lhs.id == rhs.id &&
               lhs.url == rhs.url &&
               lhs.taskId == rhs.taskId &&
               lhs.status == rhs.status &&
               lhs.progress == rhs.progress &&
               lhs.errorMessage == rhs.errorMessage &&
               lhs.createdAt == rhs.createdAt &&
               lhs.isImported == rhs.isImported
    }
}

struct AnalysisCacheEntry: Codable {
    var content: Content
    var places: [ContentPlaceInfo]
    var cachedAt: Date
}

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    var modelContext: ModelContext?
    
    @Published var isProcessingLink: Bool = false
    @Published var linkProgress: Double = 0.0
    @Published var readyImport: PendingImport? = nil
    @Published var pendingImport: PendingImport? = nil
    @Published var curatedPosts: [CuratedPost] = []
    @Published var activeLinkTasks: [LinkAnalysisTask] = [] {
        didSet {
            saveActiveLinkTasks()
        }
    }
    
    private let tasksKey = "saved_active_link_tasks"
    private let analysisCacheKey = "analysis_result_cache"
    private var analysisCache: [String: AnalysisCacheEntry] = [:]
    
    private init() {
        loadActiveLinkTasks()
        loadAnalysisCache()
    }
    
    private func saveActiveLinkTasks() {
        if let data = try? JSONEncoder().encode(activeLinkTasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }
    
    private func loadActiveLinkTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let tasks = try? JSONDecoder().decode([LinkAnalysisTask].self, from: data) {
            self.activeLinkTasks = tasks
        }
    }
    
    private func saveAnalysisCache() {
        if let data = try? JSONEncoder().encode(analysisCache) {
            UserDefaults.standard.set(data, forKey: analysisCacheKey)
        }
    }
    
    private func loadAnalysisCache() {
        // 暫時強制清空所有快取，以修復舊有的壞資料 (沒有地點或圖片網址 403)
        self.analysisCache = [:]
        saveAnalysisCache()
        
        // 註解掉原本讀取舊快取的邏輯
        /*
        if let data = UserDefaults.standard.data(forKey: analysisCacheKey),
           let cache = try? JSONDecoder().decode([String: AnalysisCacheEntry].self, from: data) {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            self.analysisCache = cache.filter { $0.value.cachedAt > sevenDaysAgo }
        }
        */
    }
    
    /// Look up a previously analyzed result by URL
    func getCachedAnalysis(for url: String) -> (Content, [ContentPlaceInfo])? {
        let canonicalId = extractCanonicalID(from: url)
        if let entry = analysisCache[canonicalId] {
            // Check if expired (7 days)
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            if entry.cachedAt > sevenDaysAgo {
                // 防呆：如果之前快取的是「0個地點」或是「過期的Firebase圖片網址」，就當作快取無效，強制重讀！
                if entry.places.isEmpty {
                    print("⚠️ [AnalysisCache] Cache hit but 0 places (orphaned). Ignoring cache for: \(canonicalId)")
                    analysisCache.removeValue(forKey: canonicalId)
                    saveAnalysisCache()
                    return nil
                }
                
                print("🎯 [AnalysisCache] Cache hit for: \(canonicalId)")
                return (entry.content, entry.places)
            } else {
                // Expired, remove it
                analysisCache.removeValue(forKey: canonicalId)
                saveAnalysisCache()
            }
        }
        return nil
    }
    
    /// Save an analysis result to cache
    func cacheAnalysisResult(url: String, content: Content, places: [ContentPlaceInfo]) {
        let canonicalId = extractCanonicalID(from: url)
        let entry = AnalysisCacheEntry(content: content, places: places, cachedAt: Date())
        analysisCache[canonicalId] = entry
        
        // Keep cache size under 100 entries
        if analysisCache.count > 100 {
            let sorted = analysisCache.sorted { $0.value.cachedAt < $1.value.cachedAt }
            let toRemove = sorted.prefix(analysisCache.count - 100)
            for (key, _) in toRemove {
                analysisCache.removeValue(forKey: key)
            }
        }
        
        saveAnalysisCache()
        print("💾 [AnalysisCache] Cached result for: \(canonicalId) (total: \(analysisCache.count))")
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        // 初始化快取，用於快速重複偵測
        preloadCollectionStats()
        
        // 從雲端還原收藏庫
        restoreLibraryFromCloud()
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
        
        // 強化版 Regex: 捕捉 /p/ 或 /reels/ 或 /reel/ 或 /tv/ 或 /sh/ 後面的 10-12 位 ID
        // 支援包含 /share/ 或其他路徑的情況
        let pattern = "(?:/p/|/reels/|/reel/|/tv/|/sh/)([^/?#\\s]+)"
        
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
    
    /// 手動從快取移除 (供其他 Manager 呼叫)
    func removeFromCache(title: String) {
        self.collectedTitles.remove(title)
        // trigger UI update
        self.objectWillChange.send()
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
                            sdPlace.imageUrl = content.previewThumbnailUrl ?? place.imageUrl
                            context.insert(sdPlace)
                            sdPlace.contents.append(sdContent)
                        }
                    }
                    try context.save()
                    
                    // 同步到雲端備份
                    if AuthManager.shared.isSignedIn {
                        let uid = AuthManager.shared.currentUID
                        let placesToSync = (try? context.fetch(FetchDescriptor<SDPlace>())) ?? []
                        Task {
                            for p in placesToSync {
                                try? await FirestoreService.shared.backupPlaceToUserCloud(p, ownerUID: uid)
                            }
                        }
                    }
                    
                    print("✅ [DataService] Local save successful for \(relatedPlaces.count) places")
                } catch {
                    print("❌ [DataService] Local save error: \(error)")
                }
            }
        }
    }
    
    // MARK: - 收藏庫雲端還原
    func restoreLibraryFromCloud() {
        guard AuthManager.shared.isSignedIn, let context = modelContext else { return }
        let uid = AuthManager.shared.currentUID
        Task {
            do {
                print("☁️ [DataService] Fetching library places from cloud backup...")
                let cloudPlaces = try await FirestoreService.shared.fetchUserCloudPlaces(ownerUID: uid)
                
                // Merge into SwiftData
                await MainActor.run {
                    let localPlaces = fetchAllPlaces()
                    let localIds = Set(localPlaces.map { $0.id })
                    var didAdd = false
                    
                    for cp in cloudPlaces {
                        if !localIds.contains(cp.id) {
                            let newPlace = cp.toSDPlace()
                            context.insert(newPlace)
                            didAdd = true
                        }
                    }
                    
                    if didAdd {
                        try? context.save()
                        print("✅ [DataService] Restored places from cloud backup.")
                    }
                }
            } catch {
                print("❌ [DataService] Restore places error: \(error)")
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
        let urlString = "https://pubo-api-641234109681.asia-east1.run.app/api/v1/task/\(taskId)"
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
        let urlString = "https://pubo-api-641234109681.asia-east1.run.app/api/v1/share"
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
    
    /// 從任何文字中提取出所有的 HTTP/HTTPS 連結
    func extractURLs(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
        
        var urls: [String] = []
        for match in matches {
            if let urlStr = match.url?.absoluteString {
                urls.append(urlStr)
            }
        }
        // 去重並保持順序
        var uniqueUrls: [String] = []
        for url in urls {
            if !uniqueUrls.contains(url) {
                uniqueUrls.append(url)
            }
        }
        return uniqueUrls
    }
    
    func startSmartImport(url: String) {
        let urls = extractURLs(from: url)
        
        if urls.isEmpty {
            // 無連結：純文字列表輸入
            self.isProcessingLink = true
            self.linkProgress = 0.0
            self.readyImport = nil
            
            Task {
                do {
                    let backendTaskId = try await submitShareTask(url: url)
                    if let (content, places) = await pollTaskResult(taskId: backendTaskId) {
                        self.isProcessingLink = false
                        self.readyImport = PendingImport(content: content, places: places)
                    } else {
                        self.isProcessingLink = false
                    }
                } catch {
                    self.isProcessingLink = false
                    print("Start smart import plain text error: \(error)")
                }
            }
        } else {
            // 所有連結（單一或多重）都統一使用多重並行分析，以進入佇列與懸浮按鈕機制
            startMultiSmartImport(urls: urls)
        }
    }
    
    func startMultiSmartImport(urls: [String]) {
        for url in urls {
            if isPostCollected(url: url) {
                print("⚠️ Post already collected: \(url)")
                continue
            }
            
            // 🎯 Layer 0: Check local analysis cache FIRST — avoid calling backend entirely
            if let (cachedContent, cachedPlaces) = getCachedAnalysis(for: url) {
                print("🎯 [Cache] Using cached analysis result for: \(url)")
                let task = LinkAnalysisTask(url: url, status: .completed)
                var mutableTask = task
                mutableTask.content = cachedContent
                mutableTask.places = cachedPlaces
                self.activeLinkTasks.append(mutableTask)
                continue
            }
            
            // 🔍 Layer 0.5: Check if activeLinkTasks already has a completed result for same URL
            let canonicalId = extractCanonicalID(from: url)
            if let existingTask = activeLinkTasks.first(where: {
                extractCanonicalID(from: $0.url) == canonicalId && $0.status == .completed && $0.content != nil
            }) {
                print("🎯 [Queue] Using existing completed task result for: \(url)")
                let task = LinkAnalysisTask(url: url, status: .completed)
                var mutableTask = task
                mutableTask.content = existingTask.content
                mutableTask.places = existingTask.places
                self.activeLinkTasks.append(mutableTask)
                continue
            }
            
            let task = LinkAnalysisTask(url: url, status: .pending)
            self.activeLinkTasks.append(task)
            let taskUUID = task.id
            
            Task {
                do {
                    let backendTaskId = try await submitShareTask(url: url)
                    updateTask(id: taskUUID, status: .analyzing, taskId: backendTaskId)
                    
                    if let (content, places) = await pollTaskResultForQueue(taskUUID: taskUUID, taskId: backendTaskId) {
                        updateTask(id: taskUUID, status: .completed, content: content, places: places)
                    } else {
                        updateTask(id: taskUUID, status: .failed, errorMessage: "分析失敗或逾時")
                    }
                } catch {
                    updateTask(id: taskUUID, status: .failed, errorMessage: error.localizedDescription)
                }
            }
        }
        updateGlobalProcessingStatus()
    }
    
    func resumeTask(taskId: String) {
        let task = LinkAnalysisTask(url: "外部匯入貼文", taskId: taskId, status: .analyzing)
        self.activeLinkTasks.append(task)
        let taskUUID = task.id
        
        Task {
            if let (content, places) = await pollTaskResultForQueue(taskUUID: taskUUID, taskId: taskId) {
                updateTask(id: taskUUID, status: .completed, content: content, places: places)
            } else {
                updateTask(id: taskUUID, status: .failed, errorMessage: "分析失敗或逾時")
            }
            updateGlobalProcessingStatus()
        }
    }
    
    // --- 佇列管理輔助方法 ---
    
    func updateTask(id: UUID, status: LinkAnalysisTask.TaskStatus, progress: Double = 0.0, taskId: String? = nil, content: Content? = nil, places: [ContentPlaceInfo] = [], errorMessage: String? = nil) {
        if let index = activeLinkTasks.firstIndex(where: { $0.id == id }) {
            activeLinkTasks[index].status = status
            activeLinkTasks[index].progress = progress
            if let taskId = taskId {
                activeLinkTasks[index].taskId = taskId
            }
            if let content = content {
                activeLinkTasks[index].content = content
            }
            if !places.isEmpty {
                activeLinkTasks[index].places = places
            }
            
            // 💾 Cache analysis result on completion for future reuse
            if status == .completed, let content = content ?? activeLinkTasks[index].content {
                let taskUrl = activeLinkTasks[index].url
                let taskPlaces = !places.isEmpty ? places : activeLinkTasks[index].places
                cacheAnalysisResult(url: taskUrl, content: content, places: taskPlaces)
            }
            if let errorMessage = errorMessage {
                activeLinkTasks[index].errorMessage = errorMessage
            }
            
            // 強制重分派以發布更新
            let copy = activeLinkTasks
            self.activeLinkTasks = copy
            
            updateGlobalProcessingStatus()
        }
    }
    
    func retryTask(id: UUID) {
        guard let task = activeLinkTasks.first(where: { $0.id == id }) else { return }
        updateTask(id: id, status: .pending, progress: 0.0, errorMessage: "")
        
        let url = task.url
        Task {
            do {
                let backendTaskId = try await submitShareTask(url: url)
                updateTask(id: id, status: .analyzing, taskId: backendTaskId)
                if let (content, places) = await pollTaskResultForQueue(taskUUID: id, taskId: backendTaskId) {
                    updateTask(id: id, status: .completed, content: content, places: places)
                } else {
                    updateTask(id: id, status: .failed, errorMessage: "分析失敗或逾時")
                }
            } catch {
                updateTask(id: id, status: .failed, errorMessage: error.localizedDescription)
            }
        }
    }
    
    func deleteTask(id: UUID) {
        activeLinkTasks.removeAll(where: { $0.id == id })
        updateGlobalProcessingStatus()
    }
    
    // --- App Group Share Extension Tasks ---
    func processPendingShareTasks() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo") else { return }
        let tasks = userDefaults.stringArray(forKey: "pending_tasks") ?? []
        if tasks.isEmpty { return }
        
        for taskId in tasks {
            // 防止重複載入相同的 taskId
            if !activeLinkTasks.contains(where: { $0.taskId == taskId }) {
                resumeTask(taskId: taskId)
            }
        }
        
        userDefaults.set([String](), forKey: "pending_tasks")
        userDefaults.synchronize()
    }
    
    func clearCompletedTasks() {
        activeLinkTasks.removeAll(where: { $0.isImported || $0.status == .failed })
        updateGlobalProcessingStatus()
    }
    
    private func updateGlobalProcessingStatus() {
        let hasActiveTasks = activeLinkTasks.contains { $0.status == .pending || $0.status == .analyzing }
        self.isProcessingLink = hasActiveTasks
        
        if hasActiveTasks {
            let activeTasks = activeLinkTasks.filter { $0.status == .pending || $0.status == .analyzing }
            let activeTasksCount = Double(activeTasks.count)
            let progressSum = activeTasks.reduce(0.0) { $0 + $1.progress }
            self.linkProgress = progressSum / activeTasksCount
        } else {
            self.linkProgress = 1.0
        }
    }
    
    func pollTaskResultForQueue(taskUUID: UUID, taskId: String, maxRetries: Int = 90) async -> (Content, [ContentPlaceInfo])? {
        print("🔄 [DataService] Start polling for queue task: \(taskId)")
        let startTime = Date()
        var attempts = 0
        
        while attempts < maxRetries {
            let taskExists = activeLinkTasks.contains { $0.id == taskUUID }
            guard taskExists else {
                print("🛑 Task deleted from queue. Stopping poll for: \(taskId)")
                return nil
            }
            
            do {
                let taskResponse = try await fetchTaskResult(taskId: taskId)
                if taskResponse.status == .completed, let result = taskResponse.result {
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ [DataService] Task \(taskId) completed in \(String(format: "%.2f", duration)) seconds.")
                    return (result.content, result.suggestedPlaces)
                } else if taskResponse.status == .failed {
                    let duration = Date().timeIntervalSince(startTime)
                    print("❌ [DataService] Task \(taskId) failed after \(String(format: "%.2f", duration)) seconds: \(taskResponse.error ?? "Unknown")")
                    return nil
                } else {
                    let progress = Double(taskResponse.progress ?? 0)
                    updateTask(id: taskUUID, status: .analyzing, progress: progress)
                    
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("⏳ Task \(taskId) is still processing... (Attempt \(attempts + 1)/\(maxRetries), Elapsed: \(String(format: "%.1f", elapsed))s)")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    attempts += 1
                }
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                print("⚠️ [DataService] Error polling task: \(error.localizedDescription) (Elapsed: \(String(format: "%.1f", elapsed))s)")
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                attempts += 1
            }
        }
        return nil
    }
    func uploadImage(imageData: Data) async throws -> String {
        // 【去重核心】使用最原始、未經任何壓縮的圖片 Data 來計算 Hash
        // 這樣可以保證同一張照片就算被選取多次，指紋也會絕對一致
        let hash = SHA256.hash(data: imageData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        let filename = "\(hashString).jpg"
        let storageRef = Storage.storage().reference().child("user_image/\(filename)")
        
        // 1. 先去雲端檢查這張照片是不是已經存在了 (去重機制)
        do {
            let _ = try await storageRef.getMetadata()
            // 如果成功取得 Metadata，代表照片已存在，直接取得下載網址並回傳，省下上傳時間與空間！
            print("⏩ [DataService] 照片已存在雲端 (Hash: \(hashString.prefix(6))...)，跳過重複上傳！")
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            // 發生錯誤（通常是 file not found），代表這是一張新照片，繼續執行上傳邏輯
            print("☁️ [DataService] 新照片，準備進行壓縮與上傳...")
        }
        
        // 2. 進行圖片壓縮以節省空間與傳輸時間
        var uploadData = imageData
        if let image = UIImage(data: imageData) {
            let targetWidth: CGFloat = 800 // Reduced from 1024 for speed
            let scale = targetWidth / image.size.width
            if scale < 1.0 {
                let targetSize = CGSize(width: targetWidth, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: targetSize))
                if let resized = UIGraphicsGetImageFromCurrentImageContext(),
                   let compressed = resized.jpegData(compressionQuality: 0.3) { // Reduced quality for speed
                    uploadData = compressed
                }
                UIGraphicsEndImageContext()
            } else if let compressed = image.jpegData(compressionQuality: 0.3) {
                uploadData = compressed
            }
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // 3. 正式上傳
        let _ = try await storageRef.putDataAsync(uploadData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        // 4. 【極速優化】上傳完畢後，直接把壓好的圖片塞進快取！
        // 這樣 UI 載入這張圖片時，就可以瞬間從本地讀取，不需要再等網路下載！
        if let compressedImage = UIImage(data: uploadData) {
            ImageCache.shared.set(compressedImage, for: downloadURL.absoluteString)
        }
        
        print("✅ [DataService] 上傳成功：\(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    func deleteImage(url: String) async {
        guard url.contains("firebasestorage.googleapis.com") else { return }
        guard let storageRef = try? Storage.storage().reference(forURL: url) else { return }
        
        do {
            try await storageRef.delete()
            print("🗑 [DataService] 成功刪除雲端圖片: \(url)")
        } catch {
            print("❌ [DataService] 刪除圖片失敗: \(error.localizedDescription)")
        }
    }
    func analyzeScreenshot(imageData: Data, mimeType: String = "image/jpeg") async throws -> (Content, [ContentPlaceInfo]) {
        let startTime = Date()
        print("📸 [DataService] Starting screenshot analysis...")
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
        let duration = Date().timeIntervalSince(startTime)
        print("📡 [DataService] Screenshot API Status: \(httpResponse.statusCode) (Took \(String(format: "%.2f", duration)) seconds)")
        
        if httpResponse.statusCode != 200 {
            print("❌ [DataService] Screenshot analysis failed after \(String(format: "%.2f", duration)) seconds. Raw body:\n\(responseString)")
            throw NSError(domain: "PuboError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "截圖辨識失敗 (狀態碼: \(httpResponse.statusCode))，無法提取景點。"])
        }
        
        do {
            let result = try jsonDecoder.decode(ExtractionResponse.self, from: data)
            print("✅ [DataService] Screenshot analysis completed in \(String(format: "%.2f", duration)) seconds.")
            return (result.content, result.suggestedPlaces)
        } catch {
            print("❌ [DataService] JSON Decode Failed after \(String(format: "%.2f", duration)) seconds! Raw Server Response:\n\(responseString)")
            throw error
        }
    }
    
     /// 輪詢任務直到完成或失敗 (適合處理 YouTube/Threads 等長任務)
    /// Default: 90 retries * 2s = 180s (3 minutes)
    func pollTaskResult(taskId: String, maxRetries: Int = 90) async -> (Content, [ContentPlaceInfo])? {
        print("🔄 [AGENT_VERIFIED_DataService] Start polling for task: \(taskId)")
        let startTime = Date()
        var attempts = 0
        
        while attempts < maxRetries {
            do {
                let taskResponse = try await fetchTaskResult(taskId: taskId)
                if taskResponse.status == .completed, let result = taskResponse.result {
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ [DataService] Task \(taskId) completed in \(String(format: "%.2f", duration)) seconds.")
                    return (result.content, result.suggestedPlaces)
                } else if taskResponse.status == .failed {
                    let duration = Date().timeIntervalSince(startTime)
                    print("❌ [DataService] Task \(taskId) failed after \(String(format: "%.2f", duration)) seconds: \(taskResponse.error ?? "Unknown")")
                    return nil
                } else {
                    if let progress = taskResponse.progress {
                        self.linkProgress = progress
                    }
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("⏳ Task \(taskId) is still processing... (Attempt \(attempts + 1)/\(maxRetries), Elapsed: \(String(format: "%.1f", elapsed))s)")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 等待 2 秒
                    attempts += 1
                }
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                print("⚠️ [DataService] Error polling task: \(error.localizedDescription) (Elapsed: \(String(format: "%.1f", elapsed))s)")
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 等待 2 秒
                attempts += 1
            }
        }
        print("❌ Polling timeout for task: \(taskId)")
        return nil
    }
    
    // MARK: - FastAPI Backend Endpoints
    // private let baseURL = "https://tangy-peas-dance.loca.lt/api/v1"
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
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
    func fetchTrips() async throws -> [Trip] {
        let url = URL(string: "\(baseURL)/trips")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([Trip].self, from: data)
    }
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
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
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
    func getTrip(id: String) async throws -> Trip {
        let url = URL(string: "\(baseURL)/trips/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try jsonDecoder.decode(Trip.self, from: data)
    }
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
    func deleteTrip(id: String) async throws {
        let url = URL(string: "\(baseURL)/trips/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
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
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
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
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
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
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
    func deleteSpot(spotId: String) async throws {
        let url = URL(string: "\(baseURL)/spots/\(spotId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    @available(*, deprecated, message: "Trips are now fully migrated to Firebase. Do not use legacy Python REST APIs.")
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
        guard let url = URL(string: "https://pubo-api-641234109681.asia-east1.run.app/api/v1/curated") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Transform places to the simple dictionary format expected by the backend
        let spots = places.map { info -> [String: Any] in
            var dict: [String: Any] = [
                "place_id": info.place.placeId,
                "name": info.place.name,
                "category": info.place.category ?? "景點",
                "latitude": info.place.latitude,
                "longitude": info.place.longitude
            ]
            if let address = info.place.address { dict["address"] = address }
            if let imageUrl = info.place.imageUrl { dict["image_url"] = imageUrl }
            if let rating = info.place.rating { dict["rating"] = rating }
            return dict
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
            "country": "", // Allow backend to auto-detect
            "uploader_id": AuthManager.shared.currentUID
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
                var urlString = "https://pubo-api-641234109681.asia-east1.run.app/api/v1/curated"
                if let country = country {
                    urlString += "?country=\(country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                
                guard let url = URL(string: urlString) else { return }
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                
                let decoder = jsonDecoder
                var posts = try decoder.decode([CuratedPost].self, from: data)
                
                // 過濾掉舊版的兩篇測試貼文 (沒有地址資訊)
                let blockedIds: Set<String> = [
                    "57761b47-6853-44b3-bac5-b4de56a860b3", // 日本🇯🇵東京 5間推薦美食
                    "97267014-40f0-4056-955b-158a298ab589"  // 日本東京｜吉祥寺5間必逛的店
                ]
                posts.removeAll { blockedIds.contains($0.id) }
                
                // Fix: Removed the hack that restricted curated posts to only 1 item.
                // It was hiding all newly added posts!
                
                self.curatedPosts = posts
                print("✅ [DataService] Fetched \(posts.count) curated posts")
            } catch {
                print("❌ [DataService] Fetch curated posts failed: \(error)")
            }
        }
    }
    
    func deleteCuratedPost(postId: String) async throws {
        guard let url = URL(string: "https://pubo-api-641234109681.asia-east1.run.app/api/v1/curated/\(postId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ [DataService] Delete curated post failed: \(body)")
            throw URLError(.badServerResponse)
        }
        
        print("✅ [DataService] Delete curated post successful")
        // Refresh curated posts locally
        await MainActor.run {
            self.curatedPosts.removeAll { $0.id == postId }
        }
    }
    
    // MARK: - Share Extension Integration
    func syncTripsToAppGroup() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<SDTrip>()
            var trips = try context.fetch(descriptor)
            
            if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo"),
               let orderedIds = userDefaults.stringArray(forKey: "ordered_trip_ids") {
                trips.sort { (t1, t2) -> Bool in
                    let index1 = orderedIds.firstIndex(of: t1.id) ?? Int.max
                    let index2 = orderedIds.firstIndex(of: t2.id) ?? Int.max
                    return index1 < index2
                }
            }
            
            let summaries = trips.map { trip -> TripSummary in
                let sortedDays = trip.days.sorted { ($0.dayOrder ?? 0) < ($1.dayOrder ?? 0) }
                let daysSummary = sortedDays.enumerated().map { (index, day) -> DaySummary in
                    let label = "第 \(index + 1) 天"
                    var dateString = "未定"
                    if let d = day.date {
                        let df = DateFormatter()
                        df.dateFormat = "MM/dd EEEE"
                        dateString = df.string(from: d)
                    }
                    
                    let spots = day.spots.map { spot in
                        SpotCoordinate(latitude: spot.latitude ?? 0, longitude: spot.longitude ?? 0)
                    }
                    
                    return DaySummary(dayLabel: label, dateString: dateString, spotCount: day.spots.count, spotCoordinates: spots)
                }
                
                var startDateStr = "未定"
                if let d = trip.startDate {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy/MM/dd"
                    startDateStr = df.string(from: d)
                }
                
                return TripSummary(id: trip.id, title: trip.title, startDate: startDateStr, totalDays: trip.days.count, isCollaborative: !trip.collaborators.isEmpty, days: daysSummary)
            }
            
            if let data = try? JSONEncoder().encode(summaries) {
                UserDefaults(suiteName: "group.com.anita.Pubo")?.set(data, forKey: "trip_summaries")
            }
        } catch {
            print("❌ [DataService] Sync Trips error: \(error)")
        }
    }

    func syncPendingPlaceActions(tripManager: TripManager? = nil) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo") else { return }
        guard let data = userDefaults.data(forKey: "pending_place_actions"),
              let actions = try? JSONDecoder().decode([PendingPlaceAction].self, from: data),
              !actions.isEmpty else {
            return
        }
        
        guard let context = modelContext else { return }
        
        var remainingActions: [PendingPlaceAction] = []
        var didModify = false
        
        for action in actions {
            switch action.destination {
            case .library:
                let place = SDPlace(name: action.placeName, latitude: action.latitude ?? 0, longitude: action.longitude ?? 0)
                place.sourceUrl = action.googleMapsUrl
                context.insert(place)
                didModify = true
            case .itinerary:
                guard let tripId = action.tripId, let dayIndex = action.dayIndex, let tm = tripManager else {
                    remainingActions.append(action)
                    continue
                }
                
                // If trip days are not loaded in memory yet, do NOT drop it; keep it for a future retry
                guard let dayList = tm.days[tripId], dayIndex < dayList.count else {
                    print("⚠️ [DataService] Trip (\(tripId)) days not loaded in memory yet. Keeping action in queue for retry.")
                    remainingActions.append(action)
                    continue
                }
                
                let spot = ItinerarySpot(
                    id: UUID().uuidString,
                    name: action.placeName,
                    category: .spot,
                    latitude: action.latitude,
                    longitude: action.longitude,
                    place: action.address != nil ? PlaceInfo(
                        name: action.placeName,
                        placeId: nil,
                        address: action.address,
                        latitude: action.latitude,
                        longitude: action.longitude,
                        category: "景點",
                        rating: nil,
                        userRatingsTotal: nil,
                        openingHours: nil,
                        imageUrl: nil
                    ) : nil
                )
                tm.addSpot(to: tripId, dayIndex: dayIndex, spot: spot)
                didModify = true
            case .newTrip:
                guard let newTripName = action.newTripName, let tm = tripManager else {
                    remainingActions.append(action)
                    continue
                }
                didModify = true
                // Create the trip, and then when it finishes, add the spot
                Task {
                    do {
                        let newTrip = try await self.createTrip(
                            title: newTripName,
                            destination: "未知地點",
                            startDate: Date(),
                            endDate: Date(),
                            transportMode: "大眾運輸"
                        )
                        let spot = ItinerarySpot(
                            id: UUID().uuidString,
                            name: action.placeName,
                            category: .spot,
                            latitude: action.latitude,
                            longitude: action.longitude
                        )
                        // Note: newly created trip has at least 1 day
                        await MainActor.run {
                            tm.trips.append(newTrip)
                            if let d = newTrip.days {
                                tm.days[newTrip.id] = d
                            }
                            tm.addSpot(to: newTrip.id, dayIndex: 0, spot: spot)
                        }
                    } catch {
                        print("Failed to sync new trip from share extension: \(error)")
                    }
                }
            }
        }
        
        if didModify {
            try? context.save()
        }
        
        if remainingActions.isEmpty {
            userDefaults.removeObject(forKey: "pending_place_actions")
        } else {
            if let encoded = try? JSONEncoder().encode(remainingActions) {
                userDefaults.set(encoded, forKey: "pending_place_actions")
            }
        }
        
        // After processing, update the trip summaries again
        syncTripsToAppGroup()
    }
}
