import Foundation
import MapKit

class AutoAlignmentService {
    private let poiResolver = POIResolverService()
    
    struct AlignedResult {
        let originalSuggestion: ContentPlaceInfo
        let resolvedPlace: Place?
        let isConfident: Bool
    }
    
    /// 對建議地點列表進行自動落地對齊
    /// - Parameter suggestions: 後端返回的建議地點
    /// - Returns: 對齊後的結果列表
    func alignPlaces(suggestions: [ContentPlaceInfo]) async -> [AlignedResult] {
        var results: [AlignedResult] = []
        
        for suggestion in suggestions {
            do {
                // 1. 執行 MapKit 搜尋
                let matchedPlaces = try await poiResolver.resolvePOI(query: suggestion.place.name)
                
                // 2. 判斷對齊信心值
                // 規則：如果搜尋結果只有一個且名稱高度匹配，則標記為高信心
                if let firstMatch = matchedPlaces.first {
                    let isConfident = matchedPlaces.count == 1 || 
                                     firstMatch.name.contains(suggestion.place.name)
                    
                    results.append(AlignedResult(
                        originalSuggestion: suggestion,
                        resolvedPlace: firstMatch,
                        isConfident: isConfident
                    ))
                } else {
                    results.append(AlignedResult(
                        originalSuggestion: suggestion,
                        resolvedPlace: nil,
                        isConfident: false
                    ))
                }
            } catch {
                print("Auto-alignment failed for \(suggestion.place.name): \(error)")
                results.append(AlignedResult(
                    originalSuggestion: suggestion,
                    resolvedPlace: nil,
                    isConfident: false
                ))
            }
        }
        
        return results
    }
}
