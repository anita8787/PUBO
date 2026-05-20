import Foundation
import MapKit
import Combine

protocol SearchProvider {
    func autocomplete(query: String, regionCode: String?, sessionToken: String) async throws -> [SearchResult]
    func fetchDetails(placeId: String) async throws -> (lat: Double, lng: Double, address: String?)
}

// MARK: - Places Search Cache (In-Memory, Process Lifetime)
final class PlacesSearchCache {
    static let shared = PlacesSearchCache()
    private init() {}

    // Autocomplete cache: query → results
    private var autocompleteCache: [String: (results: [SearchResult], timestamp: Date)] = [:]
    // Details cache: placeId → details
    private var detailsCache: [String: (lat: Double, lng: Double, address: String?, timestamp: Date)] = [:]

    private let ttl: TimeInterval = 300 // 5 分鐘有效

    func cachedSuggestions(for key: String) -> [SearchResult]? {
        guard let entry = autocompleteCache[key],
              Date().timeIntervalSince(entry.timestamp) < ttl else { return nil }
        return entry.results
    }

    func cacheSuggestions(_ results: [SearchResult], for key: String) {
        autocompleteCache[key] = (results: results, timestamp: Date())
    }

    func cachedDetails(for placeId: String) -> (lat: Double, lng: Double, address: String?)? {
        guard let entry = detailsCache[placeId],
              Date().timeIntervalSince(entry.timestamp) < ttl else { return nil }
        return (lat: entry.lat, lng: entry.lng, address: entry.address)
    }

    func cacheDetails(lat: Double, lng: Double, address: String?, for placeId: String) {
        detailsCache[placeId] = (lat: lat, lng: lng, address: address, timestamp: Date())
    }

    func clearAll() {
        autocompleteCache.removeAll()
        detailsCache.removeAll()
        print("🧹 [PlacesCache] Cleared all cache entries.")
    }
}

class SearchService: ObservableObject {
    @Published var suggestions: [SearchResult] = []
    @Published var isSearching = false
    
    private let googleProvider: GooglePlacesProvider
    private let mkProvider: MapKitProvider
    private var sessionToken = UUID().uuidString
    private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()
    
    var regionCode: String? = nil // 當前行程的國家碼 (e.g. KR, JP)
    
    init(apiKey: String) {
        self.googleProvider = GooglePlacesProvider(apiKey: apiKey)
        self.mkProvider = MapKitProvider()
        setupDebounce()
    }
    
    private func setupDebounce() {
        searchSubject
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard !query.isEmpty else {
                    self?.suggestions = []
                    return
                }
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    func updateQuery(_ query: String) {
        searchSubject.send(query)
    }
    
    func resetSession() {
        sessionToken = UUID().uuidString
    }
    
    @MainActor
    private func performSearch(query: String) async {
        // 先查快取
        let cacheKey = "\(query)|\(regionCode ?? "")"
        if let cached = PlacesSearchCache.shared.cachedSuggestions(for: cacheKey) {
            print("⚡️ [PlacesCache] Cache hit for query: \(query)")
            self.suggestions = cached
            return
        }

        isSearching = true
        defer { isSearching = false }
        
        do {
            // Priority 1: Google
            let results = try await googleProvider.autocomplete(query: query, regionCode: regionCode, sessionToken: sessionToken)
            self.suggestions = results
            PlacesSearchCache.shared.cacheSuggestions(results, for: cacheKey)
            print("✅ [PlacesCache] Cached \(results.count) results for: \(query)")
        } catch {
            print("⚠️ Google Search Failed: \(error). Falling back to MapKit.")
            do {
                // Priority 2: MapKit Fallback
                let results = try await mkProvider.autocomplete(query: query, regionCode: regionCode, sessionToken: sessionToken)
                self.suggestions = results
                PlacesSearchCache.shared.cacheSuggestions(results, for: cacheKey)
            } catch {
                print("❌ MapKit Search also failed: \(error)")
                suggestions = []
            }
        }
    }
    
    func getDetails(for result: SearchResult) async throws -> (lat: Double, lng: Double, address: String?) {
        // 先查快取
        if let cached = PlacesSearchCache.shared.cachedDetails(for: result.placeId) {
            print("⚡️ [PlacesCache] Details cache hit for placeId: \(result.placeId)")
            return cached
        }

        let details: (lat: Double, lng: Double, address: String?)
        switch result.source {
        case .google:
            details = try await googleProvider.fetchDetails(placeId: result.placeId)
        case .apple:
            details = try await mkProvider.fetchDetails(placeId: result.placeId)
        }

        PlacesSearchCache.shared.cacheDetails(lat: details.lat, lng: details.lng, address: details.address, for: result.placeId)
        print("✅ [PlacesCache] Cached details for placeId: \(result.placeId)")
        return details
    }
}

// MARK: - Providers

class GooglePlacesProvider: SearchProvider {
    let apiKey: String
    private let sessionToken: String = UUID().uuidString // Placeholder - real one comes from SearchService
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func autocomplete(query: String, regionCode: String?, sessionToken: String) async throws -> [SearchResult] {
        var urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&sessiontoken=\(sessionToken)&key=\(apiKey)&language=zh-TW"
        
        if let region = regionCode {
            urlString += "&components=country:\(region.lowercased())"
        }
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GoogleAutocompleteResponse.self, from: data)
        
        if response.status == "OVER_QUERY_LIMIT" || response.status == "REQUEST_DENIED" {
            throw NSError(domain: "GooglePlaces", code: 429, userInfo: [NSLocalizedDescriptionKey: response.status])
        }
        
        return response.predictions.map { pred in
            SearchResult(
                title: pred.structured_formatting.main_text,
                subtitle: pred.structured_formatting.secondary_text ?? "",
                latitude: nil,
                longitude: nil,
                source: .google,
                placeId: pred.place_id
            )
        }
    }
    
    func fetchDetails(placeId: String) async throws -> (lat: Double, lng: Double, address: String?) {
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeId)&fields=geometry,formatted_address&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GoogleDetailsResponse.self, from: data)
        
        guard let location = response.result?.geometry.location else {
            throw NSError(domain: "GooglePlaces", code: 404, userInfo: [NSLocalizedDescriptionKey: "No Geometry Found"])
        }
        
        return (lat: location.lat, lng: location.lng, address: response.result?.formatted_address)
    }
}

class MapKitProvider: NSObject, SearchProvider, MKLocalSearchCompleterDelegate {
    private var completer: MKLocalSearchCompleter?
    private var continuation: CheckedContinuation<[SearchResult], Error>?
    
    override init() {
        super.init()
        completer = MKLocalSearchCompleter()
        completer?.delegate = self
        completer?.resultTypes = .pointOfInterest
    }
    
    func autocomplete(query: String, regionCode: String?, sessionToken: String) async throws -> [SearchResult] {
        completer?.queryFragment = query
        // MapKit region highlighting isn't as strict as Google components, but we could set a region here if needed.
        // For now, focusing on Google as primary.
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func fetchDetails(placeId: String) async throws -> (lat: Double, lng: Double, address: String?) {
        // MapKit uses name/title for search
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = placeId // In case of Apple, 'placeId' is the title
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        guard let item = response.mapItems.first else { throw URLError(.fileDoesNotExist) }
        return (lat: item.placemark.coordinate.latitude, lng: item.placemark.coordinate.longitude, address: item.name)
    }
    
    // MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map { res in
            SearchResult(
                title: res.title,
                subtitle: res.subtitle,
                latitude: nil,
                longitude: nil,
                source: .apple,
                placeId: res.title // Use title as ID for lookup
            )
        }
        continuation?.resume(returning: results)
        continuation = nil
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - JSON Helpers

struct GoogleAutocompleteResponse: Codable {
    let predictions: [GooglePrediction]
    let status: String
}

struct GooglePrediction: Codable {
    let description: String
    let place_id: String
    let structured_formatting: StructuredFormatting
}

struct StructuredFormatting: Codable {
    let main_text: String
    let secondary_text: String?
}

struct GoogleDetailsResponse: Codable {
    let result: GoogleDetailsResult?
    let status: String
}

struct GoogleDetailsResult: Codable {
    let geometry: GoogleGeometry
    let formatted_address: String?
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}
