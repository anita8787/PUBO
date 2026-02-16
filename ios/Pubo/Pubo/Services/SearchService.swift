import Foundation
import MapKit
import Combine

protocol SearchProvider {
    func autocomplete(query: String, sessionToken: String) async throws -> [SearchResult]
    func fetchDetails(placeId: String) async throws -> (lat: Double, lng: Double, address: String?)
}

class SearchService: ObservableObject {
    @Published var suggestions: [SearchResult] = []
    @Published var isSearching = false
    
    private let googleProvider: GooglePlacesProvider
    private let mkProvider: MapKitProvider
    private var sessionToken = UUID().uuidString
    private var cancellables = Set<AnyCancellable>()
    private let searchSubject = PassthroughSubject<String, Never>()
    
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
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Priority 1: Google
            suggestions = try await googleProvider.autocomplete(query: query, sessionToken: sessionToken)
        } catch {
            print("⚠️ Google Search Failed: \(error). Falling back to MapKit.")
            do {
                // Priority 2: MapKit Fallback
                suggestions = try await mkProvider.autocomplete(query: query, sessionToken: sessionToken)
            } catch {
                print("❌ MapKit Search also failed: \(error)")
                suggestions = []
            }
        }
    }
    
    func getDetails(for result: SearchResult) async throws -> (lat: Double, lng: Double, address: String?) {
        switch result.source {
        case .google:
            return try await googleProvider.fetchDetails(placeId: result.placeId)
        case .apple:
            return try await mkProvider.fetchDetails(placeId: result.placeId)
        }
    }
}

// MARK: - Providers

class GooglePlacesProvider: SearchProvider {
    let apiKey: String
    private let sessionToken: String = UUID().uuidString // Placeholder - real one comes from SearchService
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func autocomplete(query: String, sessionToken: String) async throws -> [SearchResult] {
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&sessiontoken=\(sessionToken)&key=\(apiKey)&language=zh-TW"
        
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
    
    func autocomplete(query: String, sessionToken: String) async throws -> [SearchResult] {
        completer?.queryFragment = query
        
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
        return (lat: item.location.coordinate.latitude, lng: item.location.coordinate.longitude, address: item.name)
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
