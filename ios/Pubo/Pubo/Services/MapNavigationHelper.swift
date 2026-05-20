import SwiftUI
import MapKit

/// 提供單點/整體行程導航跳轉功能的輔助工具
/// 支援 Google Maps、Naver Map（韓國）、Apple Maps
enum MapNavigationHelper {

    // MARK: - 單一景點導航（點對點）

    /// 從現在位置導航到單一景點
    /// - Parameters:
    ///   - name: 景點名稱（用於 Apple Maps 顯示）
    ///   - lat: 緯度
    ///   - lng: 經度
    ///   - googlePlaceId: Google Place ID（若有，則 Google Maps 跳轉更精確）
    static func navigateToSpot(name: String, lat: Double, lng: Double, googlePlaceId: String? = nil) {
        // 優先嘗試 Google Maps（若安裝）
        if isGoogleMapsInstalled() {
            openGoogleMapsToSpot(name: name, lat: lat, lng: lng, placeId: googlePlaceId)
        } else {
            // 未安裝 Google Maps 時，強制 fallback 到 Google Maps 網頁版，以保證精確度
            openGoogleMapsWeb(name: name, lat: lat, lng: lng, placeId: googlePlaceId)
        }
    }

    /// 顯示選擇地圖 App 的 ActionSheet 資料
    static func navigationOptions(
        name: String,
        lat: Double,
        lng: Double,
        googlePlaceId: String? = nil,
        isKorea: Bool = false
    ) -> [(title: String, action: () -> Void)] {
        var options: [(title: String, action: () -> Void)] = []

        // 永遠提供 Google Maps 選項：若無安裝，則導航至網頁版
        options.append((
            title: "Google Maps 導航",
            action: { navigateToSpot(name: name, lat: lat, lng: lng, googlePlaceId: googlePlaceId) }
        ))

        if isKorea && isNaverMapInstalled() {
            options.append((
                title: "Naver Map 導航",
                action: { openNaverMapToSpot(name: name, lat: lat, lng: lng) }
            ))
        }

        options.append((
            title: "Apple Maps 導航",
            action: { openAppleMapsToSpot(name: name, lat: lat, lng: lng) }
        ))

        return options
    }

    // MARK: - 內部實作

    static func isGoogleMapsInstalled() -> Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func isNaverMapInstalled() -> Bool {
        guard let url = URL(string: "nmap://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// 跳轉 Google Maps，有 Place ID 時 fallback web 版用 query_place_id 精確定位
    private static func openGoogleMapsToSpot(name: String, lat: Double, lng: Double, placeId: String?) {
        // App 版 (comgooglemaps://) 不支援 place_id 參數，只能用座標 + 名稱搜尋
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlStr = "comgooglemaps://?q=\(encodedName)&center=\(lat),\(lng)&zoom=15"

        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    // 跳轉失敗時 fallback 到網頁版（支援 query_place_id 精確定位）
                    openGoogleMapsWeb(name: name, lat: lat, lng: lng, placeId: placeId)
                }
            }
        }
    }

    /// 網頁版 Google Maps fallback（在 Safari 開啟）
    private static func openGoogleMapsWeb(name: String, lat: Double, lng: Double, placeId: String?) {
        var urlStr: String
        if let pid = placeId, !pid.isEmpty {
            // 用 place_id 讓 Google Maps 精確鎖定該地點
            urlStr = "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)&query_place_id=\(pid)"
        } else {
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlStr = "https://www.google.com/maps/search/?api=1&query=\(encodedName)&center=\(lat),\(lng)"
        }

        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }

    /// 跳轉 Apple Maps
    static func openAppleMapsToSpot(name: String, lat: Double, lng: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    /// 跳轉 Naver Map（韓國）— 使用 navigation schema 直接開啟導航
    private static func openNaverMapToSpot(name: String, lat: Double, lng: Double) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        // nmap://navigation? 才是真正的導航模式；place? 只是在地圖上放標記
        // appname 必填，使用 Bundle ID
        let urlStr = "nmap://navigation?dlat=\(lat)&dlng=\(lng)&dname=\(encodedName)&appname=com.anita.Pubo"

        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    if let storeUrl = URL(string: "https://apps.apple.com/app/id311867728") {
                        UIApplication.shared.open(storeUrl)
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI 導航按鈕元件

/// 小巧的導航圓形按鈕，可嵌入任何景點卡片
struct SpotNavigateButton: View {
    let spot: ItinerarySpot
    @State private var showPicker = false

    private var isKorea: Bool {
        guard let lat = spot.latitude, let lon = spot.longitude else { return false }
        return lat > 33.0 && lat < 38.6 && lon > 124.5 && lon < 132.0
    }

    var body: some View {
        Button(action: {
            MapNavigationHelper.navigateToSpot(name: spot.name, lat: spot.latitude ?? 0, lng: spot.longitude ?? 0, googlePlaceId: spot.googlePlaceId)
        }) {
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Color.blue.opacity(0.8))
        }
    }
}

/// 用於 MapPlace 的導航按鈕（適用 PlaceDetailCard）
struct MapPlaceNavigateButton: View {
    let place: MapPlace
    @State private var showPicker = false

    private var isKorea: Bool {
        let lat = place.coordinate.latitude
        let lon = place.coordinate.longitude
        return lat > 33.0 && lat < 38.6 && lon > 124.5 && lon < 132.0
    }

    // 判斷此 MapPlace 是否有有效座標
    private var hasValidCoordinate: Bool {
        place.coordinate.latitude != 0.0 || place.coordinate.longitude != 0.0
    }

    var body: some View {
        Button(action: { triggerNavigation() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 16))
                Text("導航前往")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "34C759")) // System Green
            .cornerRadius(14)
        }
    }

    private func triggerNavigation() {
        // 永遠直接跳轉至 Google Maps
        MapNavigationHelper.navigateToSpot(
            name: place.name,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            googlePlaceId: place.googlePlaceId
        )
    }
}
