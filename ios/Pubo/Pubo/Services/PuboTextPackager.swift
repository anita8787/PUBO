import Foundation
import UIKit
import UniformTypeIdentifiers

struct PuboTextPackager {
    
    static func copyNotesToPasteboard(trip: Trip, allDays: [ItineraryDay]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        // 1. 產生普通純文字 (作為 Fallback)
        var plainText = "📍 | \(trip.title)\n\n"
        
        // 2. 產生 HTML 富文本
        var htmlString = """
        <div style="font-family: -apple-system, sans-serif; font-size: 16px;">
        <p><b>📍 | \(trip.title)</b></p>
        """
        
        let startDate = trip.startDate ?? Date()
        
        for (index, day) in allDays.enumerated() {
            let currentDayDate = Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
            let dateStr = dateFormatter.string(from: currentDayDate)
            
            plainText += "第\(index + 1)天 (\(dateStr))\n"
            htmlString += "<p><b>第\(index + 1)天 (\(dateStr))</b><br>"
            
            let spots = day.spots.filter { $0.category != .accommodation }
            if spots.isEmpty {
                plainText += "當天沒有行程\n"
                htmlString += "當天沒有行程<br>"
            } else {
                for spot in spots {
                    let emoji: String
                    switch spot.category {
                    case .food: emoji = "🍽️ "
                    case .shopping: emoji = "🛍️ "
                    case .accommodation: emoji = "🏨 "
                    case .transport: emoji = "🚌 "
                    case .attraction: emoji = "📸 "
                    default: emoji = ""
                    }
                    
                    let cleanSpotName = spot.name.replacingOccurrences(of: "+", with: " ")
                    let spotName = "\(emoji)\(cleanSpotName)"
                    let timeStr = spot.time
                    let stayStr = spot.stayDuration ?? "01時00分"
                    
                    let encodedName = cleanSpotName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let placeId = spot.googlePlaceId ?? ""
                    let mapUrl = "https://www.google.com/maps/search/?api=1&query=\(encodedName)&query_place_id=\(placeId)"
                    
                    plainText += "\(timeStr) \(spotName) (停留 \(stayStr))\n\(mapUrl)\n"
                    htmlString += "\(timeStr) <a href=\"\(mapUrl)\">\(spotName)</a> (停留 \(stayStr))<br>"
                }
            }
            
            plainText += "\n"
            htmlString += "</p>"
        }
        
        // 3. 嘗試轉成 RTF data 以便精確寫入剪貼簿
        var items: [String: Any] = [
            "public.utf8-plain-text": plainText,
            "public.html": htmlString.data(using: .utf8) ?? Data()
        ]
        
        if let data = htmlString.data(using: .utf8) {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            if let attributedString = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil),
               let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                items["public.rtf"] = rtfData
            }
        }
        
        // 寫入剪貼簿
        UIPasteboard.general.setItems([items], options: [:])
    }
}
