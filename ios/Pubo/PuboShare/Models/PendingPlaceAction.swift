import Foundation

enum PlaceDestination: String, Codable {
    case library
    case itinerary
    case newTrip
}

struct PendingPlaceAction: Codable {
    var id: String = UUID().uuidString
    let placeName: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let googleMapsUrl: String
    let destination: PlaceDestination
    let tripId: String?
    let dayIndex: Int?
    let newTripName: String?
    let createdAt: Date
}
