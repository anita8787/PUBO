import Foundation
import Combine

class OTMService {
    static let shared = OTMService()
    
    private let apiKey = "5ae2e3f221c38a28845f05b6fe130293b70962fb10aa6903c9474f3b"
    private let baseURL = "https://api.opentripmap.com/0.1/en/places"
    
    struct OTMInfo {
        let imageUrl: String?
        let name: String?
    }
    
    // Simple in-memory cache: "lat,lon" -> OTMInfo
    private var cache: [String: OTMInfo] = [:]
    
    private init() {}
    
    /// Fetches place info (Photo + Localized Name) for a location.
    func fetchPlaceInfo(for latitude: Double, longitude: Double) async throws -> OTMInfo? {
        print("OTMService: Fetching info for \(latitude), \(longitude)")
        let cacheKey = "\(latitude),\(longitude)"
        if let cached = cache[cacheKey] {
            print("OTMService: Cache hit for \(cacheKey)")
            return cached
        }
        
        // Step 1: Radius Search to get XID
        guard let xid = try await fetchXID(lat: latitude, lon: longitude) else {
            print("OTMService: No XID found for \(latitude), \(longitude)")
            return nil
        }
        print("OTMService: Found XID: \(xid)")
        
        // Step 2: Details Search to get Info
        if let info = try await fetchDetailFromXID(xid) {
            print("OTMService: Found Info: \(info.name ?? "No Name"), Img: \(info.imageUrl != nil)")
            cache[cacheKey] = info
            return info
        }
        print("OTMService: No info found for XID: \(xid)")
        return nil
    }
    
    private func fetchXID(lat: Double, lon: Double) async throws -> String? {
        // Radius=500m (Reduced to avoid dragging far objects), limit=5, rate=2 (Popular)
        let urlString = "\(baseURL)/radius?radius=500&lon=\(lon)&lat=\(lat)&apikey=\(apiKey)&format=json&limit=5&rate=2"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("OTMService: Raw Response: \(jsonString)")
            }
            let places = try JSONDecoder().decode([OTMPlaceCheck].self, from: data)
            
            print("OTMService: Found \(places.count) candidates:")
            for p in places {
                print(" - \(p.name ?? "Unknown") (dist: \(p.dist ?? -1), rate: \(p.rate ?? -1))")
            }
            
            // Heuristic: Pick the one with the highest rate? Or just first?
            // For now, return the first one (OTM usually sorts by distance/rate mixture)
            // But let's try sorting by rate if available
            let bestPlace = places.sorted(by: { ($0.rate ?? 0) > ($1.rate ?? 0) }).first
            print("OTMService: Selected Best Candidate: \(bestPlace?.name ?? "None")")
            return bestPlace?.xid
        } catch {
            print("OTMService: Radius search error: \(error)")
            return nil
        }
    }
    
    private func fetchDetailFromXID(_ xid: String) async throws -> OTMInfo? {
        guard let url = URL(string: "\(baseURL)/xid/\(xid)?apikey=\(apiKey)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let placeDetail = try JSONDecoder().decode(OTMPlaceDetail.self, from: data)
            return OTMInfo(imageUrl: placeDetail.preview?.source, name: placeDetail.name)
        } catch {
            print("OTMService: Detail search error: \(error)")
            return nil
        }
    }
}

// MARK: - Decodable Models

struct OTMPlaceCheck: Codable {
    let xid: String
    let name: String?
    let dist: Double?
    let rate: Int?
    let kinds: String?
}

struct OTMPlaceDetail: Codable {
    let xid: String
    let name: String?
    let preview: OTMPreview?
    // Other fields like wikipedia, extract etc. available but not needed yet
}

struct OTMPreview: Codable {
    let source: String? // URL to the image
    let height: Int?
    let width: Int?
}
