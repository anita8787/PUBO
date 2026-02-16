import Foundation
import MapKit

struct ItineraryItem: Identifiable, Codable {
    var id: UUID = UUID()
    let place: Place
    var note: String?
}

class ItineraryService {
    
    /// 計算一系列地點之間的交通時間
    /// - Parameters:
    ///   - items: 行程中的地點列表
    ///   - transportType: 交通方式 (預設為大眾運輸)
    /// - Returns: 一組由地點與到下一站所需時間組成的列表
    func calculateTotalTransitTimes(items: [ItineraryItem], transportType: MKDirectionsTransportType = .transit) async -> [TimeInterval] {
        var transitTimes: [TimeInterval] = []
        
        // 需有至少兩個地點才能計算區間時間
        guard items.count >= 2 else { return [] }
        
        for i in 0..<(items.count - 1) {
            let start = items[i].place
            let end = items[i+1].place
            
            let time = await fetchTravelTime(from: start, to: end, transportType: transportType)
            transitTimes.append(time)
        }
        
        return transitTimes
    }
    
    private func fetchTravelTime(from start: Place, to end: Place, transportType: MKDirectionsTransportType) async -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.coordinate))
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime ?? 0
        } catch {
            print("交通時間計算失敗: \(error)")
            return 0
        }
    }
}
