import SwiftData
import Foundation

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
                
                if let existingPlace = try context.fetch(placeDescriptor).first {
                    sdPlace = existingPlace
                } else {
                    sdPlace = SDPlace(
                        id: place.placeId,
                        name: place.name,
                        address: place.address,
                        latitude: place.latitude,
                        longitude: place.longitude,
                        category: place.category,
                        confidenceScore: info.confidenceScore
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
}
