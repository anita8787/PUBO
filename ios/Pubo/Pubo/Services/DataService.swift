import SwiftData
import Foundation
import Combine
import SwiftUI

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    var modelContext: ModelContext?
    
    private init() {}
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// 儲存內容與地點
    /// - Parameters:
    ///   - content: 原始 Content Struct
    ///   - placeInfos: 關聯的地點資訊列表
    ///   - unresolvedQueries: 無法自動對齊的地點名稱
    func saveContent(_ content: Content, relatedPlaces: [ContentPlaceInfo], unresolvedQueries: [String] = []) {
        guard let context = modelContext else {
            print("DataService Error: Context not set")
            return
        }
        
        do {
            // 1. 建立或查找 SDContent
            // 由於 URL 應該是唯一的，我們先查是否已存在
            let contentId = content.sourceUrl
            var sdContent: SDContent!
            
            let contentDescriptor = FetchDescriptor<SDContent>(predicate: #Predicate { $0.sourceUrl == contentId })
            if let existingContent = try context.fetch(contentDescriptor).first {
                sdContent = existingContent
                // 更新未解決的查詢 (合併或是覆蓋? 這裡選擇覆蓋)
                sdContent.unresolvedQueries = unresolvedQueries
                print("DataService: Content updated")
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
            
            // 2. 處理地點關聯
            for info in relatedPlaces {
                let place = info.place
                
                // 檢查地點是否已存在 (根據 placeId 或 name+lat/lon)
                // 這裡簡化用 placeId (MapKit ID)
                let placeId = place.placeId
                var sdPlace: SDPlace!
                
                let placeDescriptor = FetchDescriptor<SDPlace>(predicate: #Predicate { $0.id == placeId }) // 注意: Schema 中 id 就是 placeId 嗎?
                // Schema 的 id 是 UUID string。我們應該加一個 sourceId 或 mapKitId 欄位來對應。
                // 為了簡單，我們假設 SDPlace.id 存的是 MapKit ID，或者我們改用 name 比對?
                // 更好的做法是在 Schema 增加 mapKitId。但現在 Schema 已定，我們用 id 存 mapKitId 也可以 (如果它夠唯一且不變)
                // MapKit Item Identifier 並不保證永久，但短期可用。
                
                // 修正：我們在 Schema 只有 id (String)。我們約定 id = place.placeId
                
                // Serialize openingHours
                var openingHoursJSON: String? = nil
                if let hours = place.openingHours {
                    if let data = try? JSONEncoder().encode(hours) {
                        openingHoursJSON = String(data: data, encoding: .utf8)
                    }
                }
                
                if let existingPlace = try context.fetch(placeDescriptor).first {
                     sdPlace = existingPlace
                     // Update existing if needed (optional but good practice)
                     if sdPlace.openingHours == nil {
                         sdPlace.openingHours = openingHoursJSON
                     }
                } else {
                    sdPlace = SDPlace(
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
                    context.insert(sdPlace)
                }
                
                // 建立關聯 (如果尚未關聯)
                if !sdPlace.contents.contains(where: { $0.id == sdContent.id }) {
                    sdPlace.contents.append(sdContent)
                }
            }
            
            try context.save()
            print("DataService: Saved content and places successfully.")
            
        } catch {
            print("DataService Save Error: \(error)")
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
    /// 從後端獲取任務結果並回傳供預覽 (Async/Await)
    /// 不再自動儲存，而是回傳資料讓 UI 決定
    func fetchTaskResult(taskId: String) async throws -> (Content, [ContentPlaceInfo])? {
        // 使用 Vercel Production URL
        let urlString = "https://pubo-pink.vercel.app/api/v1/task/\(taskId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        print("🔗 [AGENT_VERIFIED_DataService] Fetching: \(urlString)")
        
        var request = URLRequest(url: url)
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
            return nil
        }
        
        if httpResponse.statusCode == 500 {
            print("❌ [DataService] Server Error (500). Please check Vercel Logs.")
            throw NSError(domain: "PuboError", code: 500, userInfo: [NSLocalizedDescriptionKey: "伺服器發生錯誤 (500)，請檢查後端配置。"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let taskResponse = try decoder.decode(TaskResponse.self, from: data)
        
        if taskResponse.status == .completed, let result = taskResponse.result {
             return (result.content, result.suggestedPlaces)
        } else if taskResponse.status == .failed {
            throw NSError(domain: "PuboError", code: -1, userInfo: [NSLocalizedDescriptionKey: taskResponse.error ?? "Task failed"])
        } else {
            // Pending or Processing
            throw NSError(domain: "PuboError", code: -2, userInfo: [NSLocalizedDescriptionKey: "任務處理中..."])
        }
    }
    
    /// 輪詢任務直到完成或失敗 (適合處理 YouTube/Threads 等長任務)
    /// Default: 90 retries * 2s = 180s (3 minutes)
    func pollTaskResult(taskId: String, maxRetries: Int = 90) async -> (Content, [ContentPlaceInfo])? {
        print("🔄 [AGENT_VERIFIED_DataService] Start polling for task: \(taskId)")
        var attempts = 0
        
        while attempts < maxRetries {
            do {
                if let result = try await fetchTaskResult(taskId: taskId) {
                    print("✅ Task \(taskId) completed.")
                    return result
                }
            } catch {
                let nsError = error as NSError
                if nsError.code == -2 { // Processing...
                    print("⏳ Task \(taskId) is still processing... (Attempt \(attempts + 1)/\(maxRetries))")
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 等待 2 秒
                    attempts += 1
                } else {
                    print("❌ Fatal error polling task: \(error.localizedDescription)")
                    return nil // 其他錯誤，放棄
                }
            }
        }
        print("❌ Polling timeout for task: \(taskId)")
        return nil
    }
    
    // MARK: - Trip Planning API (Backend Phase 2)
    private let baseURL = "https://pubo-pink.vercel.app/api/v1"
    
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
}
