import Foundation

/// AI 地點介紹的 Session 級快取
/// 以地點名稱為 key，避免同一場景被重複 Gemini 分析
final class PlaceDescriptionCache {
    static let shared = PlaceDescriptionCache()
    private init() {}

    struct DescriptionResult {
        let description: String?
        let proReview: String?
        let conReview: String?
    }

    private var cache: [String: (result: DescriptionResult, timestamp: Date)] = [:]
    private let ttl: TimeInterval = 600 // 10 分鐘有效

    /// 查詢快取；若不存在或已過期則回傳 nil
    func cached(for name: String) -> DescriptionResult? {
        guard let entry = cache[name],
              Date().timeIntervalSince(entry.timestamp) < ttl else { return nil }
        print("⚡️ [PlaceDescCache] Cache hit for: \(name)")
        return entry.result
    }

    /// 儲存結果到快取
    func store(_ result: DescriptionResult, for name: String) {
        cache[name] = (result: result, timestamp: Date())
        print("✅ [PlaceDescCache] Cached description for: \(name)")
    }

    /// 清除所有快取（供測試或記憶體警告用）
    func clearAll() {
        cache.removeAll()
        print("🧹 [PlaceDescCache] Cleared all entries.")
    }
}
