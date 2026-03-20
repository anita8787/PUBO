import Foundation
import MapKit

class POIResolverService {
    
    /// 將地點名稱候選人轉換為真正的 MapKit POI
    /// - Parameters:
    ///   - query: 地點名稱 (例如：鼎泰豐)
    ///   - region: 搜尋區域 (選填，可針對使用者目前位置)
    /// - Returns: 異步回傳符合的地點列表
    func resolvePOI(query: String, region: MKCoordinateRegion? = nil, countryName: String? = nil) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        
        var searchTerms = query
        if let country = countryName, !country.isEmpty {
            // Append country name separated by space rather than parenthesis for better Apple Maps compatibility
            searchTerms += " \(country)"
        }
        request.naturalLanguageQuery = searchTerms
        if let region = region {
            request.region = region
        }
        
        print("🔍 [POIResolver] Final Search Query: '\(searchTerms)'")
        if let r = region {
            print("📍 [POIResolver] Region Bias: Center(\(r.center.latitude), \(r.center.longitude)) Span(\(r.span.latitudeDelta))")
        }
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.map { item in
            Place(
                id: nil,
                placeId: UUID().uuidString, // item.identifier is not a String in iOS 16+
                name: item.name ?? "未知地點",
                address: item.name, // Avoid 'placemark.title' deprecation
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude,
                category: item.pointOfInterestCategory?.rawValue ?? "其他",
                rating: nil,
                userRatingCount: nil,
                openNow: nil,
                googlePlaceId: nil,
                openingHours: nil
            )
        }
    }
}
