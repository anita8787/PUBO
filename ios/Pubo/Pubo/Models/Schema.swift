import SwiftData
import Foundation

@Model
final class SDPlace {
    @Attribute(.unique) var id: String
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var category: String?
    var rating: Double?
    var userRatingCount: Int?
    var openNow: Bool?
    var confidenceScore: Double
    var createdAt: Date
    var openingHours: String? // JSON String of OpenHours
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \SDContent.places)
    var contents: [SDContent] = []
    
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        category: String? = nil,
        rating: Double? = nil,
        userRatingCount: Int? = nil,
        openNow: Bool? = nil,
        confidenceScore: Double = 0.0,
        createdAt: Date = Date(),
        openingHours: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.rating = rating
        self.userRatingCount = userRatingCount
        self.openNow = openNow
        self.confidenceScore = confidenceScore
        self.createdAt = createdAt
        self.openingHours = openingHours
    }
}

@Model
final class SDContent {
    @Attribute(.unique) var id: String
    var sourceType: String // "instagram", "threads"
    var sourceUrl: String
    var title: String?
    var text: String?
    var authorName: String?
    var authorAvatarUrl: String?
    var previewThumbnailUrl: String?
    var publishedAt: Date?
    var createdAt: Date
    
    // 儲存無法自動對齊的地點名稱 (供手動修正用)
    var unresolvedQueries: [String] = []
    
    // 使用者自定義分類 (Optional)
    var userCategory: String?
    
    // 使用者備註 (Memo)
    var userNote: String?
    
    // Relationships
    var places: [SDPlace] = []
    
    init(
        id: String = UUID().uuidString,
        sourceType: String,
        sourceUrl: String,
        title: String? = nil,
        text: String? = nil,
        authorName: String? = nil,
        authorAvatarUrl: String? = nil,
        previewThumbnailUrl: String? = nil,
        publishedAt: Date? = nil,
        unresolvedQueries: [String] = [],
        userCategory: String? = nil,
        userNote: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceUrl = sourceUrl
        self.title = title
        self.text = text
        self.authorName = authorName
        self.authorAvatarUrl = authorAvatarUrl
        self.previewThumbnailUrl = previewThumbnailUrl
        self.publishedAt = publishedAt
        self.unresolvedQueries = unresolvedQueries
        self.userCategory = userCategory
        self.userNote = userNote
        self.createdAt = createdAt
    }
}

@Model
final class SDTrip {
    @Attribute(.unique) var id: String
    var title: String
    var destination: String?
    var startDate: Date?
    var endDate: Date?
    var coverImageUrl: String?
    var transportMode: String?
    
    @Relationship(deleteRule: .cascade, inverse: \SDItineraryDay.trip)
    var days: [SDItineraryDay] = []
    
    var createdAt: Date = Date()
    
    init(id: String, title: String, destination: String? = nil, startDate: Date? = nil, endDate: Date? = nil, coverImageUrl: String? = nil, transportMode: String? = nil) {
        self.id = id
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.coverImageUrl = coverImageUrl
        self.transportMode = transportMode
    }
}

@Model
final class SDItineraryDay {
    @Attribute(.unique) var id: Int // Backend uses Int for Day ID
    var dayOrder: Int?
    var date: Date?
    var weekday: String?
    var title: String?
    
    var trip: SDTrip?
    
    @Relationship(deleteRule: .cascade, inverse: \SDItinerarySpot.day)
    var spots: [SDItinerarySpot] = []
    
    init(id: Int, dayOrder: Int? = nil, date: Date? = nil, weekday: String? = nil, title: String? = nil) {
        self.id = id
        self.dayOrder = dayOrder
        self.date = date
        self.weekday = weekday
        self.title = title
    }
}

@Model
final class SDItinerarySpot {
    @Attribute(.unique) var id: String
    var name: String
    var category: String? // Store raw value
    var startTime: String?
    var stayDuration: String?
    var notes: [String] = []
    var imageUrl: String?
    var googlePlaceId: String?
    var latitude: Double?
    var longitude: Double?
    var sortOrder: Int?
    var travelMode: String? // Store raw value
    var travelTime: String?
    var travelDistance: String?
    
    var day: SDItineraryDay?
    
    init(id: String, name: String, category: String? = nil, startTime: String? = nil, stayDuration: String? = nil, notes: [String] = [], imageUrl: String? = nil, googlePlaceId: String? = nil, latitude: Double? = nil, longitude: Double? = nil, sortOrder: Int? = nil, travelMode: String? = nil, travelTime: String? = nil, travelDistance: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.startTime = startTime
        self.stayDuration = stayDuration
        self.notes = notes
        self.imageUrl = imageUrl
        self.googlePlaceId = googlePlaceId
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
        self.travelMode = travelMode
        self.travelTime = travelTime
        self.travelDistance = travelDistance
    }
}
