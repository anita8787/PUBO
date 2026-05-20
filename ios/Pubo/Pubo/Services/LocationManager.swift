import Foundation
import CoreLocation
import Combine

/// 全域位置管理器：處理 GPS 權限、取得使用者位置、反向地理編碼取得城市/國家
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var currentCity: String = "台北市"
    @Published var currentCountry: String = "台灣"
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Weather
    @Published var temperature: String = "--°"
    @Published var temperatureHigh: String = "--°"
    @Published var temperatureLow: String = "--°"
    @Published var weatherEmoji: String = "☀️"
    @Published var weatherDescription: String = "載入中"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// 請求位置授權
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// 開始定位
    func startLocating() {
        // 使用 startUpdatingLocation 進行連續追蹤，確保能從舊金山預設值修正回真實位置
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 如果精確度不足（大於 100 公尺），我們繼續等待更好的更新，但不阻塞邏輯
        if location.horizontalAccuracy > 100 && currentCoordinate != nil {
            return 
        }
        
        // 只有當位置真的改變或還沒定位過時，才進行地理編碼（減少 API 呼叫）
        if let lastCoord = currentCoordinate,
           abs(lastCoord.latitude - location.coordinate.latitude) < 0.0001,
           abs(lastCoord.longitude - location.coordinate.longitude) < 0.0001 {
            return
        }

        currentCoordinate = location.coordinate
        
        // 如果位置精確度已經很好（< 50m），可以考慮停止更新以省電，
        // 但為了模擬器測試方便，我們先保持更新或至少解析一次
        
        // 反向地理編碼
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first else { return }
            
            DispatchQueue.main.async {
                self.currentCity = placemark.locality ?? placemark.administrativeArea ?? "未知城市"
                self.currentCountry = placemark.country ?? "未知國家"
                print("📍 [LocationManager] 定位成功：\(self.currentCountry) \(self.currentCity)")
                
                // 定位成功後自動拉取天氣
                self.fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [LocationManager] 定位失敗：\(error.localizedDescription)")
    }
    
    // MARK: - Open-Meteo 天氣 API（免費、無需 API Key）
    
    func fetchWeather(lat: Double, lon: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weathercode&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                print("❌ [Weather] 天氣取得失敗：\(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        // 即時溫度
                        if let current = json["current"] as? [String: Any],
                           let temp = current["temperature_2m"] as? Double,
                           let weatherCode = current["weathercode"] as? Int {
                            self.temperature = "\(Int(temp))°"
                            self.weatherEmoji = self.weatherCodeToEmoji(weatherCode)
                            self.weatherDescription = self.weatherCodeToDescription(weatherCode)
                        }
                        
                        // 最高最低溫
                        if let daily = json["daily"] as? [String: Any],
                           let maxTemps = daily["temperature_2m_max"] as? [Double],
                           let minTemps = daily["temperature_2m_min"] as? [Double],
                           let maxTemp = maxTemps.first,
                           let minTemp = minTemps.first {
                            self.temperatureHigh = "\(Int(maxTemp))°"
                            self.temperatureLow = "\(Int(minTemp))°"
                        }
                        
                        print("🌤 [Weather] \(self.weatherDescription) \(self.temperature) (\(self.temperatureLow) - \(self.temperatureHigh))")
                    }
                }
            } catch {
                print("❌ [Weather] JSON 解析失敗：\(error)")
            }
        }.resume()
    }
    
    // MARK: - 天氣代碼轉換（WMO Weather Codes）
    
    private func weatherCodeToEmoji(_ code: Int) -> String {
        switch code {
        case 0: return "☀️"          // Clear sky
        case 1, 2: return "🌤"       // Mainly clear, partly cloudy
        case 3: return "☁️"          // Overcast
        case 45, 48: return "🌫"     // Fog
        case 51, 53, 55: return "🌦"  // Drizzle
        case 61, 63, 65: return "🌧"  // Rain
        case 66, 67: return "🌧❄️"    // Freezing rain
        case 71, 73, 75: return "❄️"  // Snow
        case 77: return "🌨"          // Snow grains
        case 80, 81, 82: return "🌧"  // Showers
        case 85, 86: return "🌨"      // Snow showers
        case 95: return "⛈"          // Thunderstorm
        case 96, 99: return "⛈🌨"    // Thunderstorm with hail
        default: return "🌤"
        }
    }
    
    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1, 2: return "多雲時晴"
        case 3: return "陰"
        case 45, 48: return "霧"
        case 51, 53, 55: return "毛毛雨"
        case 61, 63, 65: return "雨"
        case 66, 67: return "凍雨"
        case 71, 73, 75: return "雪"
        case 77: return "霰"
        case 80, 81, 82: return "陣雨"
        case 85, 86: return "陣雪"
        case 95: return "雷雨"
        case 96, 99: return "雷雨夾雹"
        default: return "晴"
        }
    }
}
