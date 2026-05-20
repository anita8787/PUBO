import Foundation
import UIKit
import UniformTypeIdentifiers

struct PuboTextPackager {
    
    /// 將行程資料轉為帶有 HTML 超連結的字串，並直接存入系統剪貼簿 (支援富文本)
    static func copyNotesToPasteboard(tripTitle: String, spots: [ItinerarySpot]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let dateString = dateFormatter.string(from: Date())
        
        let emojis = ["☕", "🏺", "📸", "🍜", "🌲", "🏛️", "🍡"]
        
        // 1. 產生普通純文字 (作為 Fallback)
        var plainText = "📍 Pubo ｜ \(tripTitle)\n────────────────────\n\n"
        
        // 2. 產生 HTML 富文本
        var htmlString = """
        <div style="font-family: -apple-system, sans-serif; font-size: 16px;">
        <p>📍 <b>Pubo ｜ \(tripTitle)</b><br>
        ────────────────────</p>
        """
        
        for (index, spot) in spots.enumerated() {
            let emoji = emojis[index % emojis.count]
            let spotNum = String(format: "%02d", index + 1)
            let spotName = spot.name
            
            let desc = spot.notes?.first ?? (spot.category?.rawValue ?? "必訪景點")
            
            let encodedName = spotName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let placeId = spot.googlePlaceId ?? ""
            let mapUrl = "https://www.google.com/maps/search/?api=1&query=\(encodedName)&query_place_id=\(placeId)"
            
            // Plain Text
            plainText += "✨ \(spotNum) [ \(spotName) ] \(emoji)\n💡 備忘錄：\(desc)\n🗺️ 地圖導航：\(mapUrl)\n\n"
            
            // HTML
            htmlString += """
            <p>
            ✨ <b>\(spotNum) [ \(spotName) ]</b> \(emoji)<br>
            💡 備忘錄：\(desc)<br>
            🗺️ 地圖導航：<a href="\(mapUrl)">點我開啟 Google Maps</a>
            </p>
            """
        }
        
        let footerStr = "📅 產出日期：\(dateString) ｜ 由 Pubo App 幫你打包"
        plainText += footerStr
        htmlString += "<p>\(footerStr)</p></div>"
        
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
