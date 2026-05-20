import Foundation
import Combine

/// 行程回收站 — 最多保留 20 天
class TripTrashManager: ObservableObject {
    static let shared = TripTrashManager()
    private let key = "pubo_trip_trash_v1"
    private let retentionDays = 20

    struct DeletedTripEntry: Codable, Identifiable {
        let id: String
        let title: String
        let destination: String?
        let startDate: Date?
        let endDate: Date?
        let coverImageUrl: String?
        let deletedAt: Date

        var daysRemaining: Int {
            let expiry = Calendar.current.date(byAdding: .day, value: 20, to: deletedAt) ?? deletedAt
            return max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0)
        }
    }

    @Published var entries: [DeletedTripEntry] = []

    init() { loadAndCleanup() }

    func addToTrash(_ trip: Trip) {
        let entry = DeletedTripEntry(
            id: trip.id,
            title: trip.title,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            coverImageUrl: trip.coverImageUrl,
            deletedAt: Date()
        )
        entries.insert(entry, at: 0)
        save()
    }

    func remove(_ entry: DeletedTripEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func loadAndCleanup() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DeletedTripEntry].self, from: data) else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        entries = decoded.filter { $0.deletedAt > cutoff }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
