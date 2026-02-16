import Foundation
import CoreLocation

enum SourceType: String, Codable {
    case instagram
    case threads
    case youtube
}

enum TaskStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

struct Content: Identifiable, Codable {
    let id: Int?
    let sourceType: SourceType
    let sourceUrl: String
    let title: String?
    let text: String?
    let authorName: String?
    let authorAvatarUrl: String?
    let previewThumbnailUrl: String?
    let publishedAt: Date?
    var userTags: [String]
}

struct Place: Identifiable, Codable {
    let id: Int?
    let placeId: String // MapKit POI ID
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// 用於關聯 Content 與 Place 的資料結構 (UI 顯示用)
struct ContentPlaceRelation: Identifiable, Codable {
    var id: String { "\(contentId)_\(place.placeId)" }
    let contentId: Int
    let place: Place
    let evidenceText: String?
    let confidenceScore: Double
}

struct ContentPlaceInfo: Codable {
    let place: Place
    let evidenceText: String?
    let confidenceScore: Double
}

struct TaskResponse: Codable {
    let taskId: String
    let status: TaskStatus
    let result: ExtractionResponse?
    let error: String?
}

struct ExtractionResponse: Codable {
    let content: Content
    let suggestedPlaces: [ContentPlaceInfo]
}
