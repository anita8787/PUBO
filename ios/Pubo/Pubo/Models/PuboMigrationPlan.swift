import SwiftData

// MARK: - Schema Versions

enum PuboSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SDContent.self, SDPlace.self, SDTrip.self,
         SDItineraryDay.self, SDItinerarySpot.self, SDOfflineTask.self]
    }
}

enum PuboSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SDContent.self, SDPlace.self, SDTrip.self,
         SDItineraryDay.self, SDItinerarySpot.self, SDOfflineTask.self]
    }
}

// MARK: - Migration Plan

/// Lightweight migration：新增 lastUpdated、inviteCode、collaborators 欄位
/// 因為這些欄位都有預設值，SwiftData 可以自動完成 migration，無需自定義轉換邏輯
enum PuboMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PuboSchemaV1.self, PuboSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 → V2：新增協作欄位（全部有預設值，不需要 willMigrate/didMigrate）
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: PuboSchemaV1.self,
        toVersion: PuboSchemaV2.self
    )
}
