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
    /// - Returns: (isOpen, statusText)
    func checkBusinessStatus(periods: [OpeningPeriod], targetDate: Date) -> BusinessStatusResult {
        let calendar = Calendar.current
        
        // 獲取星期幾的 index (User provided logic: 1=Sun... need 0-6 or 0=Sun?)
        // Google Places API (RegularOpeningHours): day is 0 for Sunday, 1 for Monday... 6 for Saturday.
        // Swift Calendar: 1=Sunday, 2=Monday..., 7=Saturday.
        // periods array from backend usually follows Google's 0-6 (Sun-Sat).
        // Let's assume periods uses 0=Sunday.
        // Swift weekday - 1 = 0..6 (Sun..Sat).
        let dayOfWeek = calendar.component(.weekday, from: targetDate) - 1
        
        // 獲取當前小時與分鐘並轉成 HHmm 格式 (Int)
        let hour = calendar.component(.hour, from: targetDate)
        let minute = calendar.component(.minute, from: targetDate)
        let currentTime = hour * 100 + minute // 例如 14:30 變成 1430
        
        // 篩選出當天的時段
        let todaysPeriods = periods.filter { $0.day == dayOfWeek }
        
        // 若當天無任何時段 -> 公休
        if todaysPeriods.isEmpty {
            return BusinessStatusResult(isOpen: false, statusText: "本日公休", nextChange: nil)
        }
        
        
        var isOpen = false
        for period in todaysPeriods {
            guard let openTime = Int(period.open), let closeTime = Int(period.close) else { continue }
            
            if closeTime > openTime {
                // 一般時段: 例如 0900 ~ 2100
                if currentTime >= openTime && currentTime < closeTime {
                    isOpen = true
                    // Closing at closeTime
                    // Closing at closeTime
                    break // Found a matching open period
                }
            } else {
                // 跨夜時段: 例如 2200 ~ 0200
                // 此時有兩種情況符合與 overnight 相關:
                // 1. 22:00 ~ 23:59 (Current >= Open)
                // 2. 00:00 ~ 02:00 (Current < Close)
                
                // 但是!! User logic says: "如果 close < open, 代表跨隔日凌晨, 確保 01:00 屬於該時段".
                // Problem: If targetDate is 01:00 Tuesday, dayOfWeek is Tuesday.
                // If the shop opened on Monday 22:00 and closes Tuesday 02:00...
                // The period object for MONDAY (day=1) will have open=2200, close=0200.
                // The period object for TUESDAY (day=2) might NOT exist or be different.
                
                // Correct Logic handling for Google Places:
                // We need to check:
                // 1. TODAY's periods (Check normal and late-night start)
                // 2. YESTERDAY's periods (Check if it spills over to today)
                
                // But the User's logic snippet was simpler:
                // "在 periods 陣列中找尋所有 day 與目標日期相符的時段"
                // "if close < open... if current >= open OR current <= close"
                // THIS USER LOGIC IS FLAWED for checking "Today at 01:00".
                // If today is Tuesday 01:00. dayOfWeek=2.
                // We find periods where day=2.
                // If the shop is open Mon 22:00 - Tue 02:00... that period belongs to Mon (day=1).
                // So looking at day=2 list will NOT find it.
                // UNLESS Google/Backend normalizes it (splits it).
                
                // However, I must follow User's instruction/logic requested, OR improve it?
                // User said: "如果在 periods 陣列中找尋... day 與目標相符"
                // And: "如果 close < open... 代表跨隔日... 確保 01:00 屬於該時段"
                
                // My interpretation: The User EXPECTS the period object for TODAY to cover the overnight case?
                // OR The User might be mistaken about how the data is structured.
                // If the data comes from Google, a period starting Mon 22:00 belongs to Monday.
                
                // I will implement ROBUST logic that checks both:
                // A. Current Day's Openings
                // B. Previous Day's potential spill-over.
                
                // Let's refine the logic to be robust.
                
                // Check Previous Day Spillover first
                // Previous Day index
                let prevDayIndex = (dayOfWeek - 1 + 7) % 7
                let prevDayPeriods = periods.filter { $0.day == prevDayIndex }
                for p in prevDayPeriods {
                     guard let open = Int(p.open), let close = Int(p.close) else { continue }
                     if close < open {
                         // Prev day was overnight (e.g. 2200 to 0200)
                         // If current time is < close (e.g. 0100 < 0200), we are still open from yesterday!
                         if currentTime < close {
                             return BusinessStatusResult(isOpen: true, statusText: "營業中 (至 \(formatTime(p.close)))", nextChange: nil)
                         }
                     }
                }
                
                // Check Today
                // User provided logic:
                if closeTime > openTime {
                     if currentTime >= openTime && currentTime < closeTime {
                         let timeRange = "\(formatTime(period.open)) - \(formatTime(period.close))"
                         return BusinessStatusResult(isOpen: true, statusText: "營業中・\(timeRange)", nextChange: nil)
                     }
                } else {
                     // Overnight starting TODAY (e.g. 2200 to 0200 next day)
                     if currentTime >= openTime {
                         let timeRange = "\(formatTime(period.open)) - \(formatTime(period.close)) (隔日)"
                         return BusinessStatusResult(isOpen: true, statusText: "營業中・\(timeRange)", nextChange: nil)
                     }
                }
            }
        }
        
        // If we are here, it means we are CLOSED.
        // We need to find the "Next Open" or just show Today's hours but marked as Closed?
        // User wants to see "The hours".
        // Let's find the period that *would* be relevant for today (e.g. upcoming or just passed).
        
        if let firstPeriod = todaysPeriods.first {
             let timeRange = "\(formatTime(firstPeriod.open)) - \(formatTime(firstPeriod.close))"
             // Determine if "Before Open" or "After Close"
             // But for simplicity, just show "Closed" + Hours
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
