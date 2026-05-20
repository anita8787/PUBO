import Foundation
import Combine
import SwiftData
import SwiftUI

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle        // 尚未開始同步（無協作）
    case syncing     // 同步中
    case synced      // 已是最新
    case failed(String) // 失敗，附帶錯誤訊息
    case offline     // 無網路

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.synced, .synced), (.offline, .offline):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - TripSyncManager

@MainActor
class TripSyncManager: ObservableObject {

    static let shared = TripSyncManager()

    @Published var syncStatus: SyncStatus = .idle

    private let firestore = FirestoreService.shared
    private let network = NetworkMonitor.shared

    private init() {}

    // MARK: - 進入行程時觸發同步

    /// 在 TripDetailView.onAppear 呼叫
    func syncOnAppear(trip: SDTrip, context: ModelContext) async {
        guard let code = trip.inviteCode, !code.isEmpty else {
            syncStatus = .idle  // 沒有協作邀請碼，不同步
            return
        }
        await sync(trip: trip, inviteCode: code, context: context)
    }

    // MARK: - 手動下拉重新整理

    func syncManually(trip: SDTrip, context: ModelContext) async {
        guard let code = trip.inviteCode, !code.isEmpty else { return }
        await sync(trip: trip, inviteCode: code, context: context)
    }

    // MARK: - 本地修改後上傳

    /// 每次使用者修改景點後呼叫（TripManager 中觸發）
    func pushLocalChanges(trip: SDTrip, ownerUID: String) async {
        guard let _ = trip.inviteCode else { return }
        guard network.isConnected else {
            syncStatus = .offline
            return
        }
        syncStatus = .syncing
        do {
            try await firestore.pushTrip(trip, ownerUID: ownerUID)
            syncStatus = .synced
        } catch {
            syncStatus = .failed(error.localizedDescription)
            print("☁️ [TripSyncManager] Push failed: \(error)")
        }
    }

    // MARK: - 核心同步邏輯（Last-Writer-Wins）

    private func sync(trip: SDTrip, inviteCode: String, context: ModelContext) async {
        guard network.isConnected else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        do {
            guard let cloudTrip = try await firestore.fetchTrip(inviteCode: inviteCode) else {
                // Firestore 上沒有資料 → 上傳本地版本
                let uid = AuthManager.shared.currentUID
                try await firestore.pushTrip(trip, ownerUID: uid)
                syncStatus = .synced
                return
            }

            let cloudLastUpdated = Date(timeIntervalSince1970: cloudTrip.lastUpdated)
            let localLastUpdated = trip.lastUpdated

            if cloudLastUpdated > localLastUpdated {
                // 雲端較新 → 更新本地
                print("☁️ [TripSyncManager] Cloud is newer, pulling...")
                applyCloudToLocal(cloudTrip: cloudTrip, localTrip: trip, context: context)
                syncStatus = .synced

            } else if localLastUpdated > cloudLastUpdated {
                // 本地較新 → 上傳
                print("☁️ [TripSyncManager] Local is newer, pushing...")
                let uid = AuthManager.shared.currentUID
                try await firestore.pushTrip(trip, ownerUID: uid)
                syncStatus = .synced

            } else {
                // 已同步，無需動作
                syncStatus = .synced
            }

        } catch {
            syncStatus = .failed(error.localizedDescription)
            print("☁️ [TripSyncManager] Sync failed: \(error)")
        }
    }

    // MARK: - 雲端 → 本地 SwiftData 更新

    private func applyCloudToLocal(cloudTrip: FSTrip, localTrip: SDTrip, context: ModelContext) {
        // 更新 Trip 基本資訊
        localTrip.title        = cloudTrip.title
        localTrip.destination  = cloudTrip.destination
        localTrip.coverImageUrl = cloudTrip.coverImageUrl
        localTrip.transportMode = cloudTrip.transportMode
        localTrip.lastUpdated  = Date(timeIntervalSince1970: cloudTrip.lastUpdated)
        if let s = cloudTrip.startDate { localTrip.startDate = Date(timeIntervalSince1970: s) }
        if let e = cloudTrip.endDate   { localTrip.endDate   = Date(timeIntervalSince1970: e) }
        localTrip.collaborators = cloudTrip.collaborators

        // 刪除舊的 Days（cascade 會刪除 Spots）
        for day in localTrip.days {
            context.delete(day)
        }
        localTrip.days.removeAll()

        // 重建 Days + Spots
        for fsDay in cloudTrip.days.sorted(by: { ($0.dayOrder ?? 0) < ($1.dayOrder ?? 0) }) {
            let day = SDItineraryDay(
                id: fsDay.id,
                dayOrder: fsDay.dayOrder,
                date: fsDay.date.map { Date(timeIntervalSince1970: $0) },
                weekday: fsDay.weekday,
                title: fsDay.title
            )
            day.trip = localTrip
            for fsSpot in fsDay.spots.sorted(by: { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }) {
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
            localTrip.days.append(day)
        }

        try? context.save()
        print("☁️ [TripSyncManager] Local SwiftData updated from cloud")
    }
}
