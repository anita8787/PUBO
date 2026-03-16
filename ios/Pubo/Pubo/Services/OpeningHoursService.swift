import Foundation

struct OpeningPeriod: Codable {
    let day: Int
    let open: String  // 格式: "0900"
    let close: String // 格式: "2100"
}

// Result Validation Struct
struct BusinessStatusResult {
    let isOpen: Bool
    let statusText: String
    let nextChange: Date? // Optional: When the status will change
}

class OpeningHoursService {
    static let shared = OpeningHoursService()
    
    private init() {}
    
    /// 檢查營業狀態
    /// - Parameters:
    ///   - periods: 營業時段陣列
    ///   - targetDate: 目標日期時間
    /// - Returns: BusinessStatusResult
    func checkBusinessStatus(periods: [OpeningPeriod], targetDate: Date) -> BusinessStatusResult {
        let calendar = Calendar.current
        
        // 獲取星期幾的 index (0=Sun, 1=Mon... 6=Sat)
        let dayOfWeek = calendar.component(.weekday, from: targetDate) - 1
        
        // 獲取當前小時與分鐘並轉成 HHmm 格式 (Int)
        let hour = calendar.component(.hour, from: targetDate)
        let minute = calendar.component(.minute, from: targetDate)
        let currentTime = hour * 100 + minute // 例如 14:30 變成 1430
        
        // 1. 優先檢查昨天的跨夜時段是否延伸到今天 (例如昨天 2200-0200，現在是今天 0100)
        let prevDayIndex = (dayOfWeek - 1 + 7) % 7
        let prevDayPeriods = periods.filter { $0.day == prevDayIndex }
        for p in prevDayPeriods {
            guard let open = Int(p.open), let close = Int(p.close) else { continue }
            if close < open { // 跨夜
                if currentTime < close {
                    return BusinessStatusResult(isOpen: true, statusText: "營業中 (至 \(formatTime(p.close)))", nextChange: nil)
                }
            }
        }
        
        // 2. 檢查今天的時段
        let todaysPeriods = periods.filter { $0.day == dayOfWeek }
        if todaysPeriods.isEmpty {
            return BusinessStatusResult(isOpen: false, statusText: "本日公休", nextChange: nil)
        }
        
        for p in todaysPeriods {
            guard let open = Int(p.open), let close = Int(p.close) else { continue }
            
            if close > open {
                // 一般時段: 例如 0900 ~ 2100
                if currentTime >= open && currentTime < close {
                    let timeRange = "\(formatTime(p.open)) - \(formatTime(p.close))"
                    return BusinessStatusResult(isOpen: true, statusText: "營業中・\(timeRange)", nextChange: nil)
                }
            } else {
                // 今天的跨夜時段 (例如今天 2200-0200，現在是今天 2300)
                if currentTime >= open {
                    let timeRange = "\(formatTime(p.open)) - \(formatTime(p.close)) (隔日)"
                    return BusinessStatusResult(isOpen: true, statusText: "營業中・\(timeRange)", nextChange: nil)
                }
            }
        }
        
        // 3. 如果都不符合，則為打烊狀態
        // 找今天的下一個時段
        let upcomingPeriods = todaysPeriods.filter { (Int($0.open) ?? 0) > currentTime }.sorted { $0.open < $1.open }
        if let nextPeriod = upcomingPeriods.first {
             let timeRange = "\(formatTime(nextPeriod.open)) - \(formatTime(nextPeriod.close))"
             return BusinessStatusResult(isOpen: false, statusText: "尚未營業・\(timeRange)", nextChange: nil)
        } else if let firstPeriod = todaysPeriods.first {
             // 今天的所有時段都過了 (或者是跨夜時段但現在時間也在跨夜之後)
             let timeRange = "\(formatTime(firstPeriod.open)) - \(formatTime(firstPeriod.close))"
             return BusinessStatusResult(isOpen: false, statusText: "已打烊・\(timeRange)", nextChange: nil)
        }
        
        return BusinessStatusResult(isOpen: false, statusText: "本日公休", nextChange: nil)
    }
    
    private func formatTime(_ hhmm: String) -> String {
        // Simple formatter 2100 -> 21:00
        guard hhmm.count == 4 else { return hhmm }
        let index = hhmm.index(hhmm.startIndex, offsetBy: 2)
        return "\(hhmm.prefix(upTo: index)):\(hhmm.suffix(from: index))"
    }
}
