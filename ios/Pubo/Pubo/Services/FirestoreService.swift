import Foundation
import FirebaseFirestore

// MARK: - Firestore 資料模型

struct FSTrip: Codable {
    var id: String           // 與本地 SDTrip.id 相同
    var title: String
    var destination: String?
    var startDate: TimeInterval? // Date → Double (timestamp)
    var endDate: TimeInterval?
    var coverImageUrl: String?
    var transportMode: String?
    var lastUpdated: TimeInterval // 同步比對基準
    var ownerUID: String
    var collaborators: [String]
    var days: [FSDay]
}

struct FSDay: Codable {
    var id: Int
    var dayOrder: Int?
    var date: TimeInterval?
    var weekday: String?
    var title: String?
    var spots: [FSSpot]
}

struct FSSpot: Codable {
    var id: String
    var name: String
    var category: String?
    var startTime: String?
    var stayDuration: String?
    var notes: [String]
    var imageUrl: String?
    var googlePlaceId: String?
    var latitude: Double?
    var longitude: Double?
    var sortOrder: Int?
    var travelMode: String?
    var travelTime: String?
    var travelDistance: String?
}

// MARK: - FirestoreService

final class FirestoreService {

    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let collection = "trips"

    private init() {}

    // MARK: - 生成唯一六位數邀請碼

    func generateUniqueInviteCode() async throws -> String {
        for _ in 0..<10 { // 最多嘗試 10 次
            let code = String(format: "%06d", Int.random(in: 0...999999))
            let doc = db.collection(collection).document(code)
            let snapshot = try await doc.getDocument()
            if !snapshot.exists { return code } // 碰撞就重試
        }
        throw FirestoreError.codeGenerationFailed
    }

    // MARK: - 上傳行程到 Firestore

    func pushTrip(_ sdTrip: SDTrip, ownerUID: String) async throws {
        guard let code = sdTrip.inviteCode else {
            throw FirestoreError.noInviteCode
        }
        let fsTrip = sdTrip.toFSTrip(ownerUID: ownerUID)
        let data = try Firestore.Encoder().encode(fsTrip)
        try await db.collection(collection).document(code).setData(data)
        print("☁️ [Firestore] Pushed trip \(sdTrip.title) with code \(code)")
    }

    // MARK: - 從 Firestore 抓取行程

    func fetchTrip(inviteCode: String) async throws -> FSTrip? {
        let doc = try await db.collection(collection).document(inviteCode).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return try Firestore.Decoder().decode(FSTrip.self, from: data)
    }

    // MARK: - 用邀請碼加入行程（好友端）

    func joinTrip(inviteCode: String) async throws -> FSTrip {
        guard let trip = try await fetchTrip(inviteCode: inviteCode) else {
            throw FirestoreError.tripNotFound
        }
        return trip
    }

    // MARK: - 更新 collaborators 列表

    func addCollaborator(inviteCode: String, uid: String) async throws {
        try await db.collection(collection).document(inviteCode).updateData([
            "collaborators": FieldValue.arrayUnion([uid])
        ])
    }
}

// MARK: - Errors

enum FirestoreError: LocalizedError {
    case noInviteCode
    case tripNotFound
    case codeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noInviteCode:        return "此行程尚未啟用協作功能"
        case .tripNotFound:        return "找不到該邀請碼對應的行程"
        case .codeGenerationFailed: return "邀請碼生成失敗，請再試一次"
        }
    }
}

// MARK: - SDTrip → FSTrip Converter

extension SDTrip {
    func toFSTrip(ownerUID: String) -> FSTrip {
        FSTrip(
            id: self.id,
            title: self.title,
            destination: self.destination,
            startDate: self.startDate?.timeIntervalSince1970,
            endDate: self.endDate?.timeIntervalSince1970,
            coverImageUrl: self.coverImageUrl,
            transportMode: self.transportMode,
            lastUpdated: self.lastUpdated.timeIntervalSince1970,
            ownerUID: ownerUID,
            collaborators: self.collaborators,
            days: self.days.sorted { ($0.dayOrder ?? 0) < ($1.dayOrder ?? 0) }.map { day in
                FSDay(
                    id: day.id,
                    dayOrder: day.dayOrder,
                    date: day.date?.timeIntervalSince1970,
                    weekday: day.weekday,
                    title: day.title,
                    spots: day.spots.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }.map { spot in
                        FSSpot(
                            id: spot.id,
                            name: spot.name,
                            category: spot.category,
                            startTime: spot.startTime,
                            stayDuration: spot.stayDuration,
                            notes: spot.notes,
                            imageUrl: spot.imageUrl,
                            googlePlaceId: spot.googlePlaceId,
                            latitude: spot.latitude,
                            longitude: spot.longitude,
                            sortOrder: spot.sortOrder,
                            travelMode: spot.travelMode,
                            travelTime: spot.travelTime,
                            travelDistance: spot.travelDistance
                        )
                    }
                )
            }
        )
    }
}

// MARK: - FSTrip → SDTrip Converter (for joining a trip)

extension FSTrip {
    func toSDTrip(inviteCode: String) -> SDTrip {
        let trip = SDTrip(
            id: self.id,
            title: self.title,
            destination: self.destination,
            startDate: startDate.map { Date(timeIntervalSince1970: $0) },
            endDate: endDate.map { Date(timeIntervalSince1970: $0) },
            coverImageUrl: self.coverImageUrl,
            transportMode: self.transportMode,
            lastUpdated: Date(timeIntervalSince1970: self.lastUpdated),
            inviteCode: inviteCode,
            collaborators: self.collaborators
        )

        var order = 0
        for fsDay in self.days {
            let day = SDItineraryDay(
                id: fsDay.id,
                dayOrder: fsDay.dayOrder ?? order,
                date: fsDay.date.map { Date(timeIntervalSince1970: $0) },
                weekday: fsDay.weekday,
                title: fsDay.title
            )
            day.trip = trip
            for fsSpot in fsDay.spots {
                let spot = SDItinerarySpot(
                    id: fsSpot.id,
                    name: fsSpot.name,
                    category: fsSpot.category,
                    startTime: fsSpot.startTime,
                    stayDuration: fsSpot.stayDuration,
                    notes: fsSpot.notes,
                    imageUrl: fsSpot.imageUrl,
                    googlePlaceId: fsSpot.googlePlaceId,
                    latitude: fsSpot.latitude,
                    longitude: fsSpot.longitude,
                    sortOrder: fsSpot.sortOrder,
                    travelMode: fsSpot.travelMode,
                    travelTime: fsSpot.travelTime,
                    travelDistance: fsSpot.travelDistance
                )
                spot.day = day
                day.spots.append(spot)
            }
            trip.days.append(day)
            order += 1
        }
        return trip
    }
}
