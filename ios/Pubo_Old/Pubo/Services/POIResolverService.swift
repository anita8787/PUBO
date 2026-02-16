import Foundation
import MapKit

class POIResolverService {
    
    /// 將地點名稱候選人轉換為真正的 MapKit POI
    /// - Parameters:
    ///   - query: 地點名稱 (例如：鼎泰豐)
    ///   - region: 搜尋區域 (選填，可針對使用者目前位置)
    /// - Returns: 異步回傳符合的地點列表
    func resolvePOI(query: String, region: MKCoordinateRegion? = nil) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = region {
            request.region = region
        }
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.map { item in
            Place(
                id: nil,
                placeId: item.identifier ?? UUID().uuidString, // MapKit 提供的唯一標記
                name: item.name ?? "未知地點",
                address: item.placemark.title,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude,
                category: item.pointOfInterestCategory?.rawValue ?? "其他"
            )
        }
    }
}
