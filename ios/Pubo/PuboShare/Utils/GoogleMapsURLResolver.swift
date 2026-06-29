import Foundation

struct ResolvedMapPlace {
    let name: String
    let latitude: Double?
    let longitude: Double?
    let originalURL: String
    let finalURL: String?
    let address: String?
    
    init(name: String, latitude: Double?, longitude: Double?, originalURL: String, finalURL: String?, address: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.originalURL = originalURL
        self.finalURL = finalURL
        self.address = address
    }
}

private class NavigationDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        var request = newRequest
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        completionHandler(request)
    }
}

class GoogleMapsURLResolver {
    
    static let shared = GoogleMapsURLResolver()
    
    private init() {}
    
    /// Cleans up Google Maps place names to remove address suffixes
    static func sanitizePlaceName(_ rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove patterns like " +1-13+Saiwaicho" or " 1 5 -7 Saiwaicho" or " 1-5-13"
        let patterns = [
            "([\\s\\+]+[0-9１-９]+[\\s\\-\\+\\uFF0D]*[0-9１-９\\s]*[A-Za-z]+.*)$",
            "([\\s\\+]+[0-9１-９]+[\\s\\-\\+\\uFF0D]+[0-9１-９]+[\\s\\-\\+\\uFF0D]*[0-9１-９]*)$"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: name.utf16.count)
                if let match = regex.firstMatch(in: name, options: [], range: range) {
                    let matchRange = match.range(at: 1)
                    if let swiftRange = Range(matchRange, in: name) {
                        name = name.replacingCharacters(in: swiftRange, with: "")
                    }
                }
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func isAddress(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Postal code symbols
        if cleaned.contains("〒") || cleaned.contains("〶") {
            return true
        }
        
        // 2. Japanese zip code pattern (e.g. 150-0001)
        let zipPattern = "\\b\\d{3}-\\d{4}\\b"
        if let regex = try? NSRegularExpression(pattern: zipPattern, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                return true
            }
        }
        
        // 3. Japanese administrative suffixes after "日本" prefix
        if cleaned.hasPrefix("日本") && (cleaned.contains("市") || cleaned.contains("區") || cleaned.contains("区") || cleaned.contains("町") || cleaned.contains("目") || cleaned.contains("県") || cleaned.contains("府") || cleaned.contains("都") || cleaned.contains("村") || cleaned.contains("郡")) {
            return true
        }
        
        // 4. Starts with a number followed by address-like patterns (e.g. "1-5-13", "2丁目")
        let startsWithNumberPattern = "^\\d+[-丁番号].*"
        if let regex = try? NSRegularExpression(pattern: startsWithNumberPattern, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                return true
            }
        }
        
        // 5. Contains Japanese address components (丁目, 番地, 号)
        if cleaned.contains("丁目") || cleaned.contains("番地") || cleaned.contains("番号") {
            return true
        }
        
        // 6. Plus Code pattern (e.g. "EF56+78")
        let plusCodePattern = "^[A-Z0-9]{2,8}\\+[A-Z0-9]{2,8}$"
        if let regex = try? NSRegularExpression(pattern: plusCodePattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                return true
            }
        }
        
        // 7. Generic romanized address keywords (works for any Japanese city)
        let lower = cleaned.lowercased()
        let addressKeywords = ["chome", "chōme", "prefecture", "-ku ", "-shi ", "-cho ", "-machi ", "-mura ", "-gun ", "ward ", "city ", "district "]
        for keyword in addressKeywords {
            if lower.contains(keyword) {
                return true
            }
        }
        
        // 8. Pattern: contains prefecture/city name in Japanese + number (likely an address)
        let japaneseCitySuffixPattern = "[都道府県市区區町村郡].*\\d"
        if let regex = try? NSRegularExpression(pattern: japaneseCitySuffixPattern, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Resolves a Google Maps URL (especially short ones) to extract place information.
    /// Completion will receive nil if resolution failed and no fallback is possible.
    func resolve(url: URL, preExtractedName: String? = nil, retryCount: Int = 0, completion: @escaping (ResolvedMapPlace?) -> Void) {
        let isShortURL = url.host?.contains("goo.gl") == true
        
        if isShortURL {
            // Perform a GET request to follow redirects and get the final URL reliably, with timeout
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5.0
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            
            let delegate = NavigationDelegate()
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.dataTask(with: request) { data, response, error in
                var isDynamicLinkError = false
                if let data = data, let html = String(data: data, encoding: .utf8) {
                    if html.contains("Dynamic Link Not Found") {
                        isDynamicLinkError = true
                    }
                }
                
                if isDynamicLinkError && retryCount < 2 {
                    print("⚠️ [URLResolver] Dynamic Link Not Found detected, retrying in 0.5s (attempt \(retryCount + 1))...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        self.resolve(url: url, preExtractedName: preExtractedName, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   let finalURL = httpResponse.url {
                    self.parseFinalURL(finalURL, originalURL: url.absoluteString, preExtractedName: preExtractedName, htmlData: isDynamicLinkError ? nil : data, response: httpResponse, completion: completion)
                } else {
                    // Fallback if network fails
                    self.fallbackResolution(url: url, preExtractedName: preExtractedName, completion: completion)
                }
            }.resume()
        } else {
            // Already a full URL
            parseFinalURL(url, originalURL: url.absoluteString, preExtractedName: preExtractedName, htmlData: nil, response: nil, completion: completion)
        }
    }
    
    private func parseFinalURL(_ url: URL, originalURL: String, preExtractedName: String?, htmlData: Data?, response: URLResponse?, completion: @escaping (ResolvedMapPlace?) -> Void) {
        let urlString = url.absoluteString
        
        // Use pre-extracted name if valid
        var placeName: String? = nil
        if let rawPre = preExtractedName {
            let firstLine = rawPre.components(separatedBy: .newlines).first ?? ""
            let cleaned = GoogleMapsURLResolver.sanitizePlaceName(firstLine)
            if !cleaned.isEmpty {
                placeName = cleaned
            }
        }
        
        // Extract Coordinates from path: /@lat,lng, query param: q=lat,lng, or search path: /search/lat,lng
        var latitude: Double?
        var longitude: Double?
        
        // 1. Try to extract from "/@"
        if let atRange = urlString.range(of: "/@") {
            let substring = urlString[atRange.upperBound...]
            let components = substring.split(separator: ",")
            if components.count >= 2 {
                latitude = Double(components[0])
                longitude = Double(components[1])
            }
        }
        
        // 2. Try to extract from query parameter q=lat,lng
        if latitude == nil || longitude == nil {
            if let urlComponents = URLComponents(string: urlString),
               let queryItems = urlComponents.queryItems,
               let qValue = queryItems.first(where: { $0.name == "q" })?.value {
                let components = qValue.split(separator: ",")
                if components.count >= 2 {
                    latitude = Double(components[0])
                    longitude = Double(components[1])
                }
            }
        }
        
        // 3. Try to extract from /search/lat,lng or /maps/search/lat,lng
        if latitude == nil || longitude == nil {
            let searchPatterns = ["/search/", "/maps/search/"]
            for pattern in searchPatterns {
                if let searchRange = urlString.range(of: pattern) {
                    let substring = urlString[searchRange.upperBound...]
                    let segment = substring.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? String(substring)
                    let components = segment.split(separator: ",")
                    if components.count >= 2 {
                        latitude = Double(components[0])
                        longitude = Double(components[1])
                        break
                    }
                }
            }
        }
        
        // If we already have a good place name from the share text, and we got coordinates, return immediately
        let isInvalidApp: (String) -> Bool = { name in
            let cleaned = name.replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: "\u{00A0}", with: "")
                              .lowercased()
            return cleaned == "google地圖" || cleaned == "googlemaps" || cleaned == "maps" || cleaned == "地圖" || cleaned == "applemaps" || cleaned == "google地图"
        }
        
        if let validName = placeName,
           validName != "未命名地點",
           !validName.contains("150-0001"),
           !isInvalidApp(validName),
           latitude != nil, longitude != nil {
            let resolved = ResolvedMapPlace(
                name: validName,
                latitude: latitude,
                longitude: longitude,
                originalURL: originalURL,
                finalURL: urlString,
                address: nil
            )
            DispatchQueue.main.async {
                completion(resolved)
            }
            return
        }
        
        // Helper to process HTML and finish the resolution
        let processHTML: (Data?, URLResponse?) -> Void = { data, response in
            var htmlExtractedName: String? = nil
            var urlPathName: String? = nil
            
            if let placeRange = urlString.range(of: "/place/") {
                let substring = urlString[placeRange.upperBound...]
                let segment = substring.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? String(substring)
                let decoded = (segment.removingPercentEncoding ?? segment).replacingOccurrences(of: "+", with: " ")
                let isCoordinate = decoded.range(of: "^[\\d\\.,\\-\\s]+$", options: .regularExpression) != nil
                if !decoded.isEmpty && !isCoordinate {
                    let sanitized = GoogleMapsURLResolver.sanitizePlaceName(decoded)
                    if !sanitized.isEmpty && sanitized != "未命名地點" {
                        urlPathName = sanitized
                    }
                }
            }
            
            if let data = data, let html = String(data: data, encoding: .utf8) {
                // 1. Try to find /maps/place/ in the HTML content
                if let regex = try? NSRegularExpression(pattern: "/maps/place/([^/@?\"']+)", options: []) {
                    let range = NSRange(location: 0, length: html.utf16.count)
                    let matches = regex.matches(in: html, options: [], range: range)
                    for match in matches {
                        if match.numberOfRanges > 1 {
                            let matchRange = match.range(at: 1)
                            if let swiftRange = Range(matchRange, in: html) {
                                let segment = String(html[swiftRange])
                                if let decoded = segment.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
                                    var finalDecoded = decoded
                                    if finalDecoded.contains("%") {
                                        finalDecoded = finalDecoded.removingPercentEncoding ?? finalDecoded
                                    }
                                    finalDecoded = finalDecoded.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let isCoordinate = finalDecoded.range(of: "^[\\d\\.,\\-\\s]+$", options: .regularExpression) != nil
                                    if !finalDecoded.isEmpty && !isCoordinate {
                                        let sanitized = GoogleMapsURLResolver.sanitizePlaceName(finalDecoded)
                                        if !sanitized.isEmpty && sanitized != "未命名地點" {
                                            htmlExtractedName = sanitized
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Try og:title if HTML path regex didn't work
                if htmlExtractedName == nil {
                    if let range = html.range(of: "<meta property=\"og:title\" content=\"([^\"]+)\"", options: .regularExpression) {
                        let match = String(html[range])
                        if let contentRange = match.range(of: "content=\"") {
                            var title = String(match[contentRange.upperBound...])
                            title.removeLast() // remove trailing quote
                            if !title.isEmpty {
                                if let dotIndex = title.firstIndex(of: "·") {
                                    let candidate = String(title[..<dotIndex]).trimmingCharacters(in: .whitespaces)
                                    if !candidate.isEmpty { htmlExtractedName = candidate }
                                } else if let dashIndex = title.firstIndex(of: "-") {
                                    let candidate = String(title[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                                    if !candidate.isEmpty { htmlExtractedName = candidate }
                                } else {
                                    htmlExtractedName = title
                                }
                            }
                        }
                    } else if let range = html.range(of: "<title>([^<]+)</title>", options: .regularExpression) {
                        let match = String(html[range])
                        let title = match.replacingOccurrences(of: "<title>", with: "").replacingOccurrences(of: "</title>", with: "")
                        if !title.isEmpty && !title.lowercased().contains("google maps") {
                            if let dashIndex = title.firstIndex(of: "-") {
                                let candidate = String(title[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                                if !candidate.isEmpty { htmlExtractedName = candidate }
                            } else {
                                htmlExtractedName = title
                            }
                        }
                    }
                }
            }
            
            if let extracted = htmlExtractedName, isInvalidApp(extracted) {
                htmlExtractedName = nil
            }
            if let pathExtracted = urlPathName, isInvalidApp(pathExtracted) {
                urlPathName = nil
            }
            
            let finalName = htmlExtractedName ?? urlPathName ?? "未命名地點"
            
            var finalLat = latitude
            var finalLng = longitude
            var actualFinalURL = urlString
            var finalRedirectName: String? = nil
            
            let responseToUse = response
            if let responseURL = responseToUse?.url?.absoluteString ?? (htmlData != nil ? urlString : nil) {
                actualFinalURL = responseURL
                
                if let placeRange = responseURL.range(of: "/place/") {
                    let substring = responseURL[placeRange.upperBound...]
                    let segment = substring.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? String(substring)
                    let decoded = (segment.removingPercentEncoding ?? segment).replacingOccurrences(of: "+", with: " ")
                    let isCoordinate = decoded.range(of: "^[\\d\\.,\\-\\s]+$", options: .regularExpression) != nil
                    if !decoded.isEmpty && !isCoordinate {
                        let sanitized = GoogleMapsURLResolver.sanitizePlaceName(decoded)
                        if !sanitized.isEmpty && sanitized != "未命名地點" && !isInvalidApp(sanitized) {
                            finalRedirectName = sanitized
                        }
                    }
                } else if let urlComponents = URLComponents(string: responseURL),
                          let queryItems = urlComponents.queryItems,
                          let qValue = queryItems.first(where: { $0.name == "q" })?.value {
                    let decoded = (qValue.removingPercentEncoding ?? qValue).replacingOccurrences(of: "+", with: " ")
                    let isCoordinate = decoded.range(of: "^[\\d\\.,\\-\\s]+$", options: .regularExpression) != nil
                    if !decoded.isEmpty && !isCoordinate {
                        let sanitized = GoogleMapsURLResolver.sanitizePlaceName(decoded)
                        if !sanitized.isEmpty && sanitized != "未命名地點" && !isInvalidApp(sanitized) {
                            finalRedirectName = sanitized
                        }
                    }
                }
                
                if let atRange = responseURL.range(of: "/@") {
                    let substring = responseURL[atRange.upperBound...]
                    let components = substring.split(separator: ",")
                    if components.count >= 2 {
                        finalLat = Double(components[0])
                        finalLng = Double(components[1])
                    }
                }
                
                if finalLat == nil || finalLng == nil {
                    if let urlComponents = URLComponents(string: responseURL),
                       let queryItems = urlComponents.queryItems,
                       let qValue = queryItems.first(where: { $0.name == "q" })?.value {
                        let components = qValue.split(separator: ",")
                        if components.count >= 2 {
                            finalLat = Double(components[0])
                            finalLng = Double(components[1])
                        }
                    }
                }
                
                if finalLat == nil || finalLng == nil {
                    let searchPatterns = ["/search/", "/maps/search/"]
                    for pattern in searchPatterns {
                        if let searchRange = responseURL.range(of: pattern) {
                            let substring = responseURL[searchRange.upperBound...]
                            let segment = substring.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? String(substring)
                            let components = segment.split(separator: ",")
                            if components.count >= 2 {
                                finalLat = Double(components[0])
                                finalLng = Double(components[1])
                                break
                            }
                        }
                    }
                }
            }
            
            let bestName = finalRedirectName ?? finalName
            
            // Apply Fallback logic if parsed name is invalid or is "Dynamic Link Not Found"
            var resolvedName = bestName
            let isAddressName = GoogleMapsURLResolver.isAddress(resolvedName)
            let isNameInvalid = resolvedName.isEmpty || resolvedName == "未命名地點" || resolvedName.lowercased().contains("dynamic link") || isAddressName
            
            if isNameInvalid {
                if let fallback = placeName, !fallback.isEmpty {
                    resolvedName = fallback
                    // Discard potentially incorrect/default coordinates from the address URL
                    finalLat = nil
                    finalLng = nil
                } else {
                    // Resolution failed completely and no preExtractedName fallback available
                    print("❌ [URLResolver] Resolution failed: invalid resolved name and no preExtractedName fallback.")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
            }
            
            let resolved = ResolvedMapPlace(
                name: resolvedName,
                latitude: finalLat,
                longitude: finalLng,
                originalURL: originalURL,
                finalURL: actualFinalURL,
                address: nil
            )
            DispatchQueue.main.async {
                completion(resolved)
            }
        }
        
        if let existingData = htmlData {
            processHTML(existingData, response)
        } else {
            // Fetch HTML to extract the real title
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 8.0
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            
            URLSession.shared.dataTask(with: request) { data, resp, _ in
                processHTML(data, resp)
            }.resume()
        }
    }
    
    private func fallbackResolution(url: URL, preExtractedName: String?, completion: @escaping (ResolvedMapPlace?) -> Void) {
        let firstLine = preExtractedName?.components(separatedBy: .newlines).first ?? ""
        let sanitizedName = GoogleMapsURLResolver.sanitizePlaceName(firstLine)
        if sanitizedName.isEmpty {
            // No valid fallback name, resolution failed completely
            print("❌ [URLResolver] Fallback resolution failed: no valid name in preExtractedName.")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let resolved = ResolvedMapPlace(
            name: sanitizedName,
            latitude: nil,
            longitude: nil,
            originalURL: url.absoluteString,
            finalURL: nil,
            address: nil
        )
        DispatchQueue.main.async {
            completion(resolved)
        }
    }
}
