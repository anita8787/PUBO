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
    var confidenceScore: Double
    var createdAt: Date
    
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
        confidenceScore: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.confidenceScore = confidenceScore
        self.createdAt = createdAt
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
        self.createdAt = createdAt
    }
}
