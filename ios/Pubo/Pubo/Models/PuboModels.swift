import Foundation
import CoreLocation

enum SourceType: String, Codable {
    case instagram
    case threads
    case youtube
    case plainText = "plain_text"
    case image = "image"
    case screenshot = "screenshot"
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
    var places: [ContentPlaceInfo]? // Added for cloud sync
    
    enum CodingKeys: String, CodingKey {
        case id, title, text, places
        case sourceType = "source_type"
        case sourceUrl = "source_url"
        case authorName = "author_name"
        case authorAvatarUrl = "author_avatar_url"
        case previewThumbnailUrl = "preview_thumbnail_url"
        case publishedAt = "published_at"
        case userTags = "user_tags"
    }
}

struct Place: Identifiable, Codable {
    let id: Int?
    let placeId: String // MapKit POI ID
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    let rating: Double?
    let userRatingCount: Int?
    let openNow: Bool?
    var googlePlaceId: String? = nil
    var openingHours: OpenHours? = nil
    var imageUrl: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, category, rating
        case openNow = "open_now"
        case imageUrl = "image_url"
        case placeId = "place_id"
        case userRatingCount = "user_ratings_total"
        case googlePlaceId = "google_place_id"
        case openingHours = "opening_hours"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// 用於關聯 Content 與 Place 的資料結構 (UI 顯示用)
struct ContentPlaceRelation: Identifiable, Codable {
    var id: String { "\(contentId)_\(place.placeId)" }
    let contentId: Int
    let place: Place
    let evidenceText: String?
    let confidenceScore: Double
    
    enum CodingKeys: String, CodingKey {
        case place
        case contentId = "content_id"
        case evidenceText = "evidence_text"
        case confidenceScore = "confidence_score"
    }
}

struct ContentPlaceInfo: Codable {
    let place: Place
    let evidenceText: String?
    let confidenceScore: Double
    
    enum CodingKeys: String, CodingKey {
        case place
        case evidenceText = "evidence_text"
        case confidenceScore = "confidence_score"
    }
}

struct TaskResponse: Codable {
    let taskId: String
    let status: TaskStatus
    let progress: Double?
    let result: ExtractionResponse?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case status, progress, result, error
        case taskId = "task_id"
    }
}

struct PendingImport: Identifiable {
    let id = UUID()
    let content: Content
    let places: [ContentPlaceInfo]
}

struct ExtractionResponse: Codable {
    let content: Content
    let suggestedPlaces: [ContentPlaceInfo]
    
    enum CodingKeys: String, CodingKey {
        case content
        case suggestedPlaces = "suggested_places"
    }
}
