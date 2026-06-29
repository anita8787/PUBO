import Foundation

// Shared models for Share Extension and Main App
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

struct SpotCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct DaySummary: Codable {
    let dayLabel: String
    let dateString: String
    let spotCount: Int
    let spotCoordinates: [SpotCoordinate]
}

struct TripSummary: Codable {
    let id: String
    let title: String
    let startDate: String?
    let totalDays: Int
    let isCollaborative: Bool
    let days: [DaySummary]
}
