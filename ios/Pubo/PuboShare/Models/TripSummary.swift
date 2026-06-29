import Foundation

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
