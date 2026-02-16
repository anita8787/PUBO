import Foundation
import Combine
import SwiftUI
import CoreLocation
import MapKit

@MainActor
class TripManager: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var days: [String: [ItineraryDay]] = [:] // Map tripId to days
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Backup for restoration
    private var originalSpotsOrder: [String: [String: [ItinerarySpot]]] = [:] // tripId -> dayId -> [Spots]

    // Testing phase: load trips on launch
    init() {
        refreshTrips()
    }
    
    func refreshTrips() {
        Task {
            await fetchTrips()
        }
    }
    
    func fetchTrips() async {
        self.errorMessage = nil
        isLoading = true
        do {
            let fetchedTrips = try await DataService.shared.fetchTrips()
            self.trips = fetchedTrips
            
            // Populate days dictionary for UI compatibility
            var newDays: [String: [ItineraryDay]] = [:]
            for trip in fetchedTrips {
                if let tripDays = trip.days {
                    newDays[trip.id] = tripDays
                }
            }
            self.days = newDays
            print("TripManager: Fetched \(trips.count) trips")
        } catch {
            print("TripManager Error: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // Gradient color sequence for trip cards (Client-side visual only)
    static let gradientColors: [TripColor] = [.yellow, .orange, .red, .blue]
    
    static func colorForIndex(_ index: Int) -> TripColor {
        gradientColors[index % gradientColors.count]
    }
    
    // MARK: - API Operations
    
    func addTrip(title: String, destination: String, startDate: Date, endDate: Date) {
        self.errorMessage = nil
        isLoading = true
        Task {
            do {
                let newTrip = try await DataService.shared.createTrip(
                    title: title.isEmpty ? destination : title,
                    destination: destination,
                    startDate: startDate,
                    endDate: endDate,
                    transportMode: "大眾運輸"
                )
                self.trips.append(newTrip)
                if let d = newTrip.days {
                    self.days[newTrip.id] = d
                }
            } catch {
                print("Add Trip Error: \(error)")
                self.errorMessage = "Failed to create trip"
            }
            isLoading = false
        }
    }
    
    func addSpot(to tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        guard let dayList = days[tripId], dayIndex < dayList.count else { return }
        let dayId = dayList[dayIndex].id
        
        Task {
            do {
                // Determine dayId from existing data
                let newSpot = try await DataService.shared.addSpot(dayId: dayId, spot: spot)
                
                // Update Local State
                if var currentDays = self.days[tripId] {
                    currentDays[dayIndex].spots.append(newSpot)
                    // Sort by start time if needed, or rely on order
                    // currentDays[dayIndex].spots.sort { $0.time < $1.time } 
                    self.days[tripId] = currentDays
                    
                    // Update Trip List (optional, to reflect spot count)
                    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                        trips[idx].days = currentDays
                    }
                }
            } catch {
                print("Add Spot Error: \(error)")
                self.errorMessage = "Failed to add spot"
            }
        }
    }
    
    func updateSpot(tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        // 1. Optimistic Local Update
        self.updateSpotLocal(tripId: tripId, dayIndex: dayIndex, spot: spot)
        
        // 2. Backend Sync
        Task {
            do {
                let updatedSpot = try await DataService.shared.updateSpot(spot: spot)
                
                // Final Update: Sync with backend response
                await MainActor.run {
                    print("🏁 Final sync for \(spot.name)")
                    if var currentDays = self.days[tripId], dayIndex < currentDays.count {
                        if let idx = currentDays[dayIndex].spots.firstIndex(where: { $0.id == spot.id }) {
                            currentDays[dayIndex].spots[idx] = updatedSpot
                            
                            self.days[tripId] = currentDays
                            self.objectWillChange.send() 
                            
                            if let tIdx = trips.firstIndex(where: { $0.id == tripId }) {
                                trips[tIdx].days = currentDays
                            }
                            print("✅ Final state synced and published")
                        }
                    }
                }
            } catch {
                print("Update Spot Error: \(error)")
            }
        }
    }
    
    // Help for local only persistence (Optimistic UI)
    private func updateSpotLocal(tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        DispatchQueue.main.async {
            if var currentDays = self.days[tripId], dayIndex < currentDays.count {
                if let idx = currentDays[dayIndex].spots.firstIndex(where: { $0.id == spot.id }) {
                    currentDays[dayIndex].spots[idx] = spot
                    self.days[tripId] = currentDays
                    
                    if let tIdx = self.trips.firstIndex(where: { $0.id == tripId }) {
                        self.trips[tIdx].days = currentDays
                    }
                    print("🚀 Local/Optimistic update successful for: \(spot.name)")
                }
            }
        }
    }
    
    func deleteSpot(tripId: String, dayIndex: Int, spotId: String) {
        Task {
            do {
                try await DataService.shared.deleteSpot(spotId: spotId)
                
                // Update Local
                if var currentDays = self.days[tripId], dayIndex < currentDays.count {
                    currentDays[dayIndex].spots.removeAll { $0.id == spotId }
                    self.days[tripId] = currentDays
                    
                    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                        trips[idx].days = currentDays
                    }
                }
            } catch {
                print("Delete Spot Error: \(error)")
            }
        }
    }
    
    // Transport update wrapper
    func updateSpotTransport(tripId: String, dayIndex: Int, spotId: String, transportType: TransportType) {
        print("🚀 updateSpotTransport: spotId=\(spotId), newType=\(transportType)")
        guard let dayList = days[tripId],
              dayIndex < dayList.count,
              let spotIndex = dayList[dayIndex].spots.firstIndex(where: { $0.id == spotId }) else { 
            print("❌ updateSpotTransport: Could not find spot or day")
            return 
        }
        
        let spot = dayList[dayIndex].spots[spotIndex]
        var updatedSpot = spot
        updatedSpot.travelMode = transportType
        
        // 1. Update LOCAL only to reflect icon change immediately without triggering a premature backend sync
        self.updateSpotLocal(tripId: tripId, dayIndex: dayIndex, spot: updatedSpot)
        
        // 2. Calculate directions and only sync to backend when we have the final data (or if no calc needed)
        print("📡 Starting travel calculation for \(spot.name) -> next")
        if spotIndex < dayList[dayIndex].spots.count - 1 {
            let nextSpot = dayList[dayIndex].spots[spotIndex + 1]
            if let start = spot.coordinate, let end = nextSpot.coordinate {
                calculateTravel(from: start, to: end, mode: transportType) { time, dist in
                    print("✅ Travel calculated: \(time ?? "nil"), \(dist ?? "nil")")
                    
                    // Race Condition Check: Ensure the user hasn't switched modes AGAIN 
                    // before this calculation finished.
                    if let currentDayList = self.days[tripId],
                       spotIndex < currentDayList[dayIndex].spots.count,
                       currentDayList[dayIndex].spots[spotIndex].id == spotId,
                       currentDayList[dayIndex].spots[spotIndex].travelMode == transportType {
                        
                        var finalSpot = currentDayList[dayIndex].spots[spotIndex]
                        finalSpot.travelTime = time
                        finalSpot.travelDistance = dist
                        // NOW SYNC TO BACKEND with all data
                        self.updateSpot(tripId: tripId, dayIndex: dayIndex, spot: finalSpot)
                    } else {
                        print("🚫 Calculation ignored: Mode changed or spot moved")
                    }
                }
            } else {
                print("⚠️ Missing coordinates for travel calculation, syncing mode change anyway")
                self.updateSpot(tripId: tripId, dayIndex: dayIndex, spot: updatedSpot)
            }
        } else {
            print("ℹ️ Last spot, syncing mode change to backend")
            self.updateSpot(tripId: tripId, dayIndex: dayIndex, spot: updatedSpot)
        }
    }
    
    private func calculateTravel(from start: Coordinate, to end: Coordinate, mode: TransportType, completion: @escaping (String?, String?) -> Void) {
        let startCoord = CLLocationCoordinate2D(latitude: start.lat, longitude: start.long)
        let endCoord = CLLocationCoordinate2D(latitude: end.lat, longitude: end.long)
        
        let request = MKDirections.Request()
        let startLoc = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
        let endLoc = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
        
        request.source = MKMapItem(location: startLoc, address: nil)
        request.destination = MKMapItem(location: endLoc, address: nil)
        
        switch mode {
        case .walk: request.transportType = .walking
        case .train, .bus: request.transportType = .transit
        case .car: request.transportType = .automobile
        }
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                // Format time
                let timeMinutes = Int(route.expectedTravelTime / 60)
                let timeStr = timeMinutes >= 60 ? "\(timeMinutes / 60)小時\(timeMinutes % 60)分" : "\(timeMinutes)分鐘"
                
                // Format distance
                let distKm = route.distance / 1000.0
                let distStr = String(format: "%.1fkm", distKm)
                
                print("✅ Directions success: \(timeStr), \(distStr)")
                completion(timeStr, distStr)
            } else {
                if let error = error {
                    print("⚠️ Directions error (\(mode)): \(error.localizedDescription)")
                }
                
                // Fallback: Haversine distance
                let startLoc = CLLocation(latitude: start.lat, longitude: start.long)
                let endLoc = CLLocation(latitude: end.lat, longitude: end.long)
                let distance = startLoc.distance(from: endLoc) // Meters
                
                let distKm = distance / 1000.0
                let distStr = String(format: "%.1fkm", distKm)
                
                // Estimated time based on mode (fallback speed)
                let speed: Double // meters per second
                switch mode {
                case .walk: speed = 1.4 // 5km/h
                case .car: speed = 11.1 // 40km/h
                case .bus: speed = 8.3 // 30km/h
                case .train: speed = 16.7 // 60km/h
                }
                
                let estimatedSeconds = distance / speed
                let timeMinutes = Int(estimatedSeconds / 60)
                let timeStr = timeMinutes >= 60 ? "~ \(timeMinutes / 60)時\(timeMinutes % 60)分" : "~ \(timeMinutes)分"
                
                print("ℹ️ Fallback for \(mode): \(timeStr), \(distStr)")
                completion(timeStr, distStr)
            }
        }
    }
    
    // Reorder (Move) within same day
    func moveSpot(tripId: String, dayIndex: Int, from source: IndexSet, to destination: Int) {
        guard var dayList = days[tripId], dayIndex < dayList.count else { return }
        
        // Optimistic Update
        dayList[dayIndex].spots.move(fromOffsets: source, toOffset: destination)
        self.days[tripId] = dayList
        
        let dayId = dayList[dayIndex].id
        let sortedSpotIds = dayList[dayIndex].spots.map { $0.id }
        
        Task {
            do {
                try await DataService.shared.reorderSpots(dayId: dayId, spotIds: sortedSpotIds)
            } catch {
                print("Reorder Error: \(error)")
                // Revert? For now just log.
            }
        }
    }
    
    // Move to different day
    func moveSpotToDay(tripId: String, fromDayIndex: Int, spotId: String, toDayIndex: Int) {
         guard let dayList = self.days[tripId],
               fromDayIndex < dayList.count,
               toDayIndex < dayList.count,
               let spot = dayList[fromDayIndex].spots.first(where: { $0.id == spotId }) else { return }
        
        // Moving to another day involves: 
        // 1. Delete from old day? OR Update spot's day_id?
        // Our API verify: "addSpot" supports adding. "updateSpot" doesn't change day_id explicitly in Schema (SpotUpdate doesn't have day_id).
        // Check `SpotUpdate` schema in schemas.py: `SpotUpdate(BaseModel): ...`. No day_id.
        // So we might need to delete and re-add, OR update backend to support moving days.
        // Or if I add `day_id` to `SpotUpdate`, I can move it.
        // For now, I'll simulate move by Delete + Add (which generates new ID, might be bad for persistence if ID matters).
        // Ideally backend `PUT /spots/{id}` should accept `day_id`.
        // Let's check `database.py`. `ItinerarySpot` has `day_id`.
        // Let's check `trips.py`. `update_spot` uses `spot_update.dict()`. If `day_id` is in schema, it works.
        // `SpotUpdate` schema currently DOES NOT have `day_id`.
        
        // Workaround: Delete and Add
        Task {
            // 1. Delete from source
            self.deleteSpot(tripId: tripId, dayIndex: fromDayIndex, spotId: spotId)
            
            // 2. Add to destination
            // We need a slight delay or chain it.
            // Actually, `addSpot` generates a NEW spot.
            // If we want to keep the same metadata, we copy it.
            // Reset ID? `addSpot` ignores ID in payload usually
            // but we should pass it as a `ItinerarySpot`.
            
            // Wait, this is getting complicated for a "move".
            // I'll leave it as TODO or strict implementation.
            // Optimistic update first:
            await MainActor.run {
                if let idx = self.days[tripId]?[fromDayIndex].spots.firstIndex(where: {$0.id == spotId}) {
                   let movedSpot = self.days[tripId]![fromDayIndex].spots.remove(at: idx)
                   self.days[tripId]![toDayIndex].spots.append(movedSpot)
                }
            }
            
            // Real API call:
            // Since I can't update day_id, I'll delete and re-create.
            do {
               try await DataService.shared.deleteSpot(spotId: spotId)
               // The `newSpot` variable is capturing the old spot data.
               // We need new ID.
               let _ = try await DataService.shared.addSpot(dayId: dayList[toDayIndex].id, spot: spot)
               // Refetch to sync IDs
               await fetchTrips()
            } catch {
               print("Move Day Error: \(error)")
            }
        }
    }
    
    func updateSpotName(tripId: String, dayIndex: Int, spotIndex: Int, newName: String) {
        guard let dayList = days[tripId], dayIndex < dayList.count, spotIndex < dayList[dayIndex].spots.count else { return }
        var spot = dayList[dayIndex].spots[spotIndex]
        spot.name = newName
        updateSpot(tripId: tripId, dayIndex: dayIndex, spot: spot)
    }
    
    func deleteTrip(id: String) {
        Task {
            do {
                try await DataService.shared.deleteTrip(id: id)
                self.trips.removeAll { $0.id == id }
                self.days.removeValue(forKey: id)
            } catch {
                print("Delete Trip Error: \(error)")
                self.errorMessage = "Failed to delete trip"
            }
        }
    }
    
    // MARK: - Legacy / Stubbed methods (to prevent UI crash if used)
    func updateTripSettings(tripId: String, title: String, destination: String, transportMode: String) {
        isLoading = true
        Task {
            do {
                let updatedTrip = try await DataService.shared.updateTrip(
                    id: tripId,
                    title: title,
                    destination: destination,
                    transportMode: transportMode
                )
                
                if let index = trips.firstIndex(where: { $0.id == tripId }) {
                    trips[index] = updatedTrip
                }
            } catch {
                print("Update Settings Error: \(error)")
                self.errorMessage = "Failed to update settings"
            }
            isLoading = false
        }
    }
    
    func updateTripDates(tripId: String, newStartDate: Date, newEndDate: Date) {
        isLoading = true
        Task {
            do {
                let updatedTrip = try await DataService.shared.updateTrip(
                    id: tripId,
                    startDate: newStartDate,
                    endDate: newEndDate
                )
                
                if let index = trips.firstIndex(where: { $0.id == tripId }) {
                    trips[index] = updatedTrip
                }
            } catch {
                print("Update Dates Error: \(error)")
                self.errorMessage = "Failed to update dates"
            }
            isLoading = false
        }
    }
    
    // MARK: - Smart Sorting
    
    func smartSort(tripId: String, dayIndex: Int) async {
        guard var currentDays = self.days[tripId], 
              dayIndex < currentDays.count,
              currentDays[dayIndex].spots.count > 2 else { return }
        
        let dayId = String(currentDays[dayIndex].id)
        let spots = currentDays[dayIndex].spots
        
        // 1. Backup if not already backed up
        if originalSpotsOrder[tripId] == nil {
            originalSpotsOrder[tripId] = [:]
        }
        if originalSpotsOrder[tripId]?[dayId] == nil {
            originalSpotsOrder[tripId]?[dayId] = spots
        }
        
        // 2. Perform Nearest Neighbor Sort
        var unvisited = spots
        var optimized: [ItinerarySpot] = []
        
        // Start with the first spot
        if let first = unvisited.first {
            optimized.append(first)
            unvisited.removeFirst()
        }
        
        while !unvisited.isEmpty {
            let lastSpot = optimized.last!
            let lastCoord = CLLocation(latitude: lastSpot.latitude ?? 0, longitude: lastSpot.longitude ?? 0)
            
            var bestIdx = -1
            var minDistance = Double.greatestFiniteMagnitude
            
            for (idx, spot) in unvisited.enumerated() {
                let spotCoord = CLLocation(latitude: spot.latitude ?? 0, longitude: spot.longitude ?? 0)
                let distance = lastCoord.distance(from: spotCoord)
                
                // Basic business hours weight (simplified: if closed, add penalty distance)
                // In a real app, we'd calculate arrival time based on previous durations + travel
                var distanceWeight = distance
                if let businessStatus = spot.businessStatusText(for: currentDays[dayIndex].date), !businessStatus.isOpen {
                    distanceWeight += 50000 // 50km penalty for closed spots to push them later
                }
                
                if distanceWeight < minDistance {
                    minDistance = distanceWeight
                    bestIdx = idx
                }
            }
            
            if bestIdx != -1 {
                optimized.append(unvisited.remove(at: bestIdx))
            } else {
                break
            }
        }
        
        // 3. Update Local & Backend
        currentDays[dayIndex].spots = optimized
        self.days[tripId] = currentDays
        
        let dayDbId = currentDays[dayIndex].id
        let sortedSpotIds = optimized.map { $0.id }
        
        do {
            try await DataService.shared.reorderSpots(dayId: dayDbId, spotIds: sortedSpotIds)
        } catch {
            print("Smart Sort API Error: \(error)")
        }
    }
    
    func isAlreadySorted(tripId: String, dayIndex: Int) -> Bool {
        guard let dayList = days[tripId], dayIndex < dayList.count else { return false }
        let dayId = String(dayList[dayIndex].id)
        return originalSpotsOrder[tripId]?[dayId] != nil
    }
    
    func restoreOriginalOrder(tripId: String, dayIndex: Int) async {
        guard var currentDays = self.days[tripId], 
              dayIndex < currentDays.count else { return }
        
        let dayId = String(currentDays[dayIndex].id)
        
        if let original = originalSpotsOrder[tripId]?[dayId] {
            // Restore context
            currentDays[dayIndex].spots = original
            self.days[tripId] = currentDays
            
            // Update Backend
            let dayDbId = currentDays[dayIndex].id
            let sortedSpotIds = original.map { $0.id }
            
            do {
                try await DataService.shared.reorderSpots(dayId: dayDbId, spotIds: sortedSpotIds)
                // Clear backup after restore
                originalSpotsOrder[tripId]?.removeValue(forKey: dayId)
            } catch {
                print("Restore API Error: \(error)")
            }
        }
    }
}
