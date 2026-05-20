import Foundation
import CoreLocation
import Combine

// CLLocationCoordinate2D Equatable conformance is handled in PuboModels.swift

// MARK: - Enums

enum TripColor: String, Codable {
    case yellow
    case orange
    case red
    case blue
}

enum SpotCategory: String, Codable {
    case spot
    case food
    case transport
    case accommodation
    case shopping
    case attraction
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        
        if let category = SpotCategory(rawValue: rawString.lowercased()) {
            self = category
        } else {
            // Fallback for unknown categories
            print("Warning: Unknown SpotCategory '\(rawString)', defaulting to .spot")
            self = .spot
        }
    }
}

enum SavedItemCategory: String, Codable {
    case food
    case spot
    case stay
}

enum TransportType: String, Codable {
    case walk
    case train
    case car
    case bus
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        self = TransportType(rawValue: rawString.lowercased()) ?? .train
    }
}

enum Platform: String, Codable {
    case instagram
    case youtube
    case threads
}

// MARK: - Models

struct Trip: Identifiable, Codable {
    let id: String
    var title: String
    var destination: String?
    var startDate: Date?
    var endDate: Date?
    var coverImageUrl: String?
    var transportMode: String?
    var updatedAt: Date?
    var inviteCode: String?
    var days: [ItineraryDay]?
    
    // UI Helpers / Computed Properties
    var coverImage: String { coverImageUrl ?? "" }
    
    // Format date range (mocking existing property)
    var date: String {
        // Fallback to days if startDate/endDate are missing
        let start = startDate ?? (days?.compactMap { $0.date }.first)
        let end = endDate ?? (days?.compactMap { $0.date }.last)
        
        guard let s = start, let e = end else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let startStr = formatter.string(from: s)
        formatter.dateFormat = "MM/dd"
        let endStr = formatter.string(from: e)
        return "\(startStr)-\(endStr)"
    }
    
    var spots: Int {
        days?.reduce(0) { $0 + $1.spots.count } ?? 0
    }
    
    // Mock color for now (can be computed from ID or index)
    var color: TripColor { .yellow } 
    
    // Members not yet in DB
    var members: [Member]? = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, destination
        case startDate = "start_date"
        case endDate = "end_date"
        case coverImageUrl = "cover_image_url"
        case transportMode = "transport_mode"
        case inviteCode = "invite_code"
        case days
    }
}

struct Member: Identifiable, Codable {
    var id: String
    var name: String
    var avatar: String
    var isOwner: Bool = false
}

struct TravelInfo: Codable {
    var time: String
    var distance: String
    var type: TransportType
}

// MARK: - Opening Hours Models
struct TimePoint: Codable, Sendable {
    let day: Int
    let hour: Int
    let minute: Int
}

struct GooglePeriod: Codable, Sendable {
    let open: TimePoint
    let close: TimePoint?
}

struct OpenHours: Codable, Sendable {
    let openNow: Bool?
    let periods: [GooglePeriod]?
    let weekdayDescriptions: [String]?
    
    enum CodingKeys: String, CodingKey {
        case periods
        case openNow = "openNow"
        case weekdayDescriptions = "weekdayDescriptions"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.openNow = try container.decodeIfPresent(Bool.self, forKey: .openNow)
        self.periods = try container.decodeIfPresent([GooglePeriod].self, forKey: .periods)
        self.weekdayDescriptions = try container.decodeIfPresent([String].self, forKey: .weekdayDescriptions)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(openNow, forKey: .openNow)
        try container.encodeIfPresent(periods, forKey: .periods)
        try container.encodeIfPresent(weekdayDescriptions, forKey: .weekdayDescriptions)
    }
}

struct PlaceInfo: Codable {
    var name: String?
    var placeId: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var category: String?
    let rating: Double?
    let userRatingsTotal: Int?
    let openingHours: OpenHours?
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name, address, latitude, longitude, category, rating
        case placeId = "place_id"
        case userRatingsTotal = "user_ratings_total"
        case openingHours = "opening_hours"
        case imageUrl = "image_url"
    }
}

struct ItinerarySpot: Identifiable, Codable {
    var id: String
    var dayId: Int?
    var name: String
    var category: SpotCategory?
    var startTime: String?
    var stayDuration: String?
    var notes: [String]?
    var imageUrl: String?
    var placeId: Int?
    var googlePlaceId: String? // Added for backend linking
    var latitude: Double?
    var longitude: Double?
    var sortOrder: Int?
    var travelMode: TransportType?
    var travelTime: String?
    var travelDistance: String?
    
    // Computed properties for UI compatibility
    var time: String { 
        get { startTime ?? "10:00" }
        set { startTime = newValue }
    }
    var duration: String { stayDuration ?? "60分鐘" }
    var image: String { imageUrl ?? "" }
    var subLabel: String? { stayDuration }
    
    // Travel to next (now computed from stored info)
    var travelToNext: TravelInfo? {
        // If we have a mode, we should show it even if time/dist are pending
        if let mode = travelMode {
            return TravelInfo(time: travelTime ?? "--", distance: travelDistance ?? "--", type: mode)
        }
        // Fallback to train if nothing is set but it's not the last spot (usually handled by UI)
        return nil
    }
    
    var coordinate: Coordinate? {
        if let lat = latitude, let long = longitude {
            // Filter out 0.0, 0.0 as invalid
            if lat == 0.0 && long == 0.0 { return nil }
            return Coordinate(lat: lat, long: long)
        }
        return nil
    }
    
    // Nested Place Info from Backend
    var place: PlaceInfo?
    
    // Helper to convert Google Periods to Service Periods
    var openingPeriods: [OpeningPeriod] {
        guard let gPeriods = place?.openingHours?.periods else { return [] }
        return gPeriods.compactMap { gp in
            guard let close = gp.close else { return nil }
            return OpeningPeriod(
                day: gp.open.day,
                open: String(format: "%02d%02d", gp.open.hour, gp.open.minute),
                close: String(format: "%02d%02d", close.hour, close.minute)
            )
        }
    }
    
    // Improved business status helper
    func businessStatusText(for date: Date?) -> BusinessStatusResult? {
        guard let targetDate = date else { return nil }
        let periods = self.openingPeriods
        
        if !periods.isEmpty {
            return OpeningHoursService.shared.checkBusinessStatus(periods: periods, targetDate: targetDate)
        }
        return nil
    }
    
    var simplifiedStatusText: String {
        // Try to find the opening hour from weekday text or periods
        if let periods = place?.openingHours?.periods, !periods.isEmpty {
             // Find next opening or today's opening
             let calendar = Calendar.current
             let today = calendar.component(.weekday, from: Date()) - 1 // Sunday = 1, Monday = 2, ..., Saturday = 7. Google's day is 0-6 (Sunday=0). So subtract 1.
             
             // Try to find today's period first
             if let todayPeriod = periods.first(where: { $0.open.day == today }) {
                 return String(format: "%02d:%02d 開始營業", todayPeriod.open.hour, todayPeriod.open.minute)
             }
             
             // If not today, find the next available opening day
             // Sort periods by day to find the next one chronologically
             let sortedPeriods = periods.sorted { $0.open.day < $1.open.day }
             if let nextPeriod = sortedPeriods.first(where: { $0.open.day > today }) {
                 return String(format: "%02d:%02d 開始營業", nextPeriod.open.hour, nextPeriod.open.minute)
             }
             
             // If no future periods, wrap around to the first period of the week
             if let firstPeriod = sortedPeriods.first {
                 return String(format: "%02d:%02d 開始營業", firstPeriod.open.hour, firstPeriod.open.minute)
             }
        }
        
        if let weekdayText = place?.openingHours?.weekdayDescriptions?.first {
            // "Monday: 9:00 AM – 5:00 PM" -> extract 9:00 AM
            let parts = weekdayText.components(separatedBy: ": ")
            if parts.count > 1 {
                let times = parts[1].components(separatedBy: " – ")
                if !times.isEmpty {
                    return "\(times[0]) 開始營業"
                }
            }
        }
        
        return "營業時間未知"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, notes, place
        case startTime = "start_time"
        case stayDuration = "stay_duration"
        case imageUrl = "image_url"
        case sortOrder = "sort_order"
        case latitude, longitude
        case dayId = "day_id"
        case placeId = "place_id"
        case googlePlaceId = "google_place_id"
        case travelMode = "travel_mode"
        case travelTime = "travel_time"
        case travelDistance = "travel_distance"
    }
    
    static func empty() -> ItinerarySpot {
        ItinerarySpot(
            id: UUID().uuidString,
            dayId: 0,
            name: "",
            category: .spot,
            startTime: "10:00",
            stayDuration: "1小時",
            notes: [],
            imageUrl: "",
            placeId: nil,
            googlePlaceId: nil, // Added init
            latitude: nil,
            longitude: nil,
            sortOrder: 0,
            travelMode: .train,
            travelTime: nil,
            travelDistance: nil,
            place: nil
        )
    }
}

struct Coordinate: Codable, Hashable {
    let lat: Double
    let long: Double
}

struct ItineraryDay: Identifiable, Codable {
    let id: Int
    var dayOrder: Int?
    var date: Date?
    var weekday: String?
    var title: String?
    var spots: [ItinerarySpot] = []
    
    // UI Helpers
    var dayLabel: String { "Day \(dayOrder ?? 0)" }
    var dateString: String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: d)
    }
    
    var mapTabDateString: String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        let dStr = formatter.string(from: d)
        return "\(dStr) \(weekday ?? "")"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case dayOrder = "day_order"
        case date, weekday, title, spots
    }
}

struct Recommendation: Identifiable, Codable {
    let id: String
    let category: String
    let name: String
    let rating: Double
    let image: String
}

struct Post: Identifiable, Codable {
    let id: String
    var author: String
    var avatar: String
    var content: String
    var image: String
    var platform: Platform
    var tags: [String]
}

struct SavedItem: Identifiable, Codable {
    let id: String
    var title: String
    var location: String
    var category: SavedItemCategory
    var imageUrl: String
    var originalLink: String?
    var platform: Platform?
}

// MARK: - Search Models

enum SearchSource: String, Codable {
    case google
    case apple
}

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let latitude: Double?
    let longitude: Double?
    let source: SearchSource
    let placeId: String // Google Place ID or Local Search Identifier
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(placeId)
        hasher.combine(source)
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.placeId == rhs.placeId && lhs.source == rhs.source
    }
}

// MARK: - Map Models

struct MapPlace: Identifiable {
    let id: String
    let name: String
    let rating: Double
    let category: String
    let time: String
    let address: String
    let image: String
    let coordinate: CLLocationCoordinate2D
    var description: String? = nil
    var sourceImageUrl: String? = nil
    var sourceAuthor: String? = nil
    var googlePlaceId: String? = nil
    
    init(id: String, name: String, rating: Double, category: String, time: String, address: String, image: String, coordinate: CLLocationCoordinate2D, description: String? = nil, sourceImageUrl: String? = nil, sourceAuthor: String? = nil, googlePlaceId: String? = nil) {
        self.id = id
        self.name = name
        self.rating = rating
        self.category = category
        self.time = time
        self.address = address
        self.image = image
        self.coordinate = coordinate
        self.description = description
        self.sourceImageUrl = sourceImageUrl
        self.sourceAuthor = sourceAuthor
        self.googlePlaceId = googlePlaceId
    }
}

struct CuratedPost: Identifiable, Codable {
    let id: String
    let title: String
    let coverImageUrl: String?
    let author: String?
    let sourceUrl: String?
    let spots: [PlaceInfo]?
    let spotCount: Int?
    let country: String?
    let createdAt: Date? // Made optional to fix keyNotFound decoding error
    
    enum CodingKeys: String, CodingKey {
        case id, title, author, spots, country
        case coverImageUrl = "cover_image"
        case sourceUrl = "source_url"
        case spotCount = "spot_count"
        case createdAt = "created_at"
    }
}


// MARK: - SDPlace Extension for UI
extension SDPlace {
    var decodedOpeningHours: OpenHours? {
        guard let data = openingHours?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(OpenHours.self, from: data)
    }
    
    var simplifiedStatusText: String {
        guard let hours = decodedOpeningHours, let periods = hours.periods, !periods.isEmpty else {
            return ""
        }
        
        let calendar = Calendar.current
        var today = calendar.component(.weekday, from: Date()) - 1 // Sunday = 0 in Google, 1 in Calendar
        if today < 0 { today = 6 }
        
        if let todayPeriod = periods.first(where: { $0.open.day == today }) {
            let openTime = String(format: "%02d:%02d", todayPeriod.open.hour, todayPeriod.open.minute)
            if let close = todayPeriod.close {
                let closeTime = String(format: "%02d:%02d", close.hour, close.minute)
                return "\(openTime) - \(closeTime)"
            }
            return "\(openTime) 開始營業"
        }
        
        return ""
    }
}
