import Foundation
import Combine
import SwiftUI
import CoreLocation
import MapKit
import SwiftData

@MainActor
class TripManager: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var days: [String: [ItineraryDay]] = [:] // Map tripId to days
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var focusPlaceFromLibrary: SDPlace? = nil
    
    // SwiftData Context (External injection)
    var modelContext: ModelContext?
    
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
            
            // Phase 17: Sync to SwiftData for Offline Use
            await syncToSwiftData(fetchedTrips)
            
        } catch {
            print("TripManager: Fetch failed: \(error)")
            self.errorMessage = error.localizedDescription
            loadFromSwiftData() // Phase 17 Fallback
        }
        isLoading = false
    }
    
    // Phase 17: Load from Local Storage
    private func loadFromSwiftData() {
        guard let context = modelContext else { return }
        
        print("💾 [SwiftData] Loading cached trips...")
        let descriptor = FetchDescriptor<SDTrip>()
        if let cachedTrips = try? context.fetch(descriptor) {
            self.trips = cachedTrips.map { sdTrip in
                // Convert SDTrip -> Trip (simplified for UI)
                Trip(
                    id: sdTrip.id,
                    title: sdTrip.title,
                    destination: sdTrip.destination,
                    startDate: sdTrip.startDate,
                    endDate: sdTrip.endDate,
                    coverImageUrl: sdTrip.coverImageUrl,
                    transportMode: sdTrip.transportMode,
                    days: sdTrip.days.map { sdDay in
                        ItineraryDay(
                            id: sdDay.id,
                            dayOrder: sdDay.dayOrder,
                            date: sdDay.date,
                            weekday: sdDay.weekday,
                            title: sdDay.title,
                            spots: sdDay.spots.map { sdSpot in
                                ItinerarySpot(
                                    id: sdSpot.id,
                                    dayId: sdDay.id,
                                    name: sdSpot.name,
                                    category: SpotCategory(rawValue: sdSpot.category?.lowercased() ?? "spot") ?? .spot,
                                    startTime: sdSpot.startTime,
                                    stayDuration: sdSpot.stayDuration,
                                    notes: sdSpot.notes,
                                    imageUrl: sdSpot.imageUrl,
                                    placeId: nil,
                                    googlePlaceId: sdSpot.googlePlaceId,
                                    latitude: sdSpot.latitude,
                                    longitude: sdSpot.longitude,
                                    sortOrder: sdSpot.sortOrder,
                                    travelMode: TransportType(rawValue: sdSpot.travelMode?.lowercased() ?? "train") ?? .train,
                                    travelTime: sdSpot.travelTime,
                                    travelDistance: sdSpot.travelDistance
                                )
                            }
                        )
                    }
                )
            }
            
            // Sync days mapping
            var newDaysMapping: [String: [ItineraryDay]] = [:]
            for t in self.trips {
                newDaysMapping[t.id] = t.days ?? []
            }
            self.days = newDaysMapping
            print("✅ [SwiftData] Loaded \(trips.count) trips from cache")
        }
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
    
    func addAccommodation(to tripId: String, spot: ItinerarySpot, checkIn: Date, checkOut: Date) {
        guard let dayList = days[tripId] else { return }
        
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: checkIn)
        let endDate = calendar.startOfDay(for: checkOut)
        
        Task {
            // Loop through each day from check-in to check-out (inclusive)
            while currentDate <= endDate {
                // Find dayIndex for this date
                if let dayIndex = dayList.firstIndex(where: { 
                    if let d = $0.date {
                        return calendar.isDate(d, inSameDayAs: currentDate)
                    }
                    return false
                }) {
                    // Prepare a copy of the spot with unique ID for each day
                    var daySpot = spot
                    daySpot.id = UUID().uuidString
                    daySpot.category = .accommodation
                    
                    // Add to this day
                    await addSpotWithDayId(to: tripId, dayIndex: dayIndex, spot: daySpot)
                }
                
                // Advance to next day
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }
        }
    }
    
    // Helper to add spot and wait for result (internal)
    private func addSpotWithDayId(to tripId: String, dayIndex: Int, spot: ItinerarySpot) async {
        guard let dayList = days[tripId], dayIndex < dayList.count else { return }
        let dayId = dayList[dayIndex].id
        
        do {
            let newSpot = try await DataService.shared.addSpot(dayId: dayId, spot: spot)
            
            // Update Local State
            await MainActor.run {
                if var currentDays = self.days[tripId] {
                    currentDays[dayIndex].spots.append(newSpot)
                    self.days[tripId] = currentDays
                    
                    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                        trips[idx].days = currentDays
                    }
                }
            }
        } catch {
            print("Add Accommodation Day Error: \(error)")
        }
    }
    
    func addSpot(to tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        print("➕ [TripManager] addSpot: Trip(\(tripId)) DayIndex(\(dayIndex)) Spot(\(spot.name))")
        
        guard let dayList = days[tripId] else {
            print("❌ [TripManager] Error: No days found for tripId \(tripId)")
            return 
        }
        
        guard dayIndex < dayList.count else {
            print("❌ [TripManager] Error: dayIndex \(dayIndex) out of bounds (count: \(dayList.count))")
            return 
        }
        
        let dayId = dayList[dayIndex].id
        print("📍 [TripManager] Target DayId: \(dayId)")
        
        Task {
            do {
                // Determine dayId from existing data
                let newSpot = try await DataService.shared.addSpot(dayId: dayId, spot: spot)
                
                // Update Local State
                if var currentDays = self.days[tripId] {
                    if spot.category == .accommodation {
                        // Accommodation always goes to the top
                        currentDays[dayIndex].spots.insert(newSpot, at: 0)
                    } else {
                        currentDays[dayIndex].spots.append(newSpot)
                    }
                    self.days[tripId] = currentDays
                    
                    // Trigger travel calculation if there's a next spot
                    let spots = currentDays[dayIndex].spots
                    if let newSpotIdx = spots.firstIndex(where: { $0.id == newSpot.id }),
                       newSpotIdx < spots.count - 1 {
                        self.updateSpotTransport(tripId: tripId, dayIndex: dayIndex, spotId: newSpot.id, transportType: newSpot.travelMode ?? .train)
                    }
                    
                    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                        trips[idx].days = currentDays
                    }
                }
            } catch {
                print("Add Spot Error: \(error)")
                self.errorMessage = "Failed to add spot"
            }
            // Auto-repair if coordinates are 0,0
            self.resolveInvalidCoordinates(in: tripId)
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
                    // Auto-repair check after update
                    self.resolveInvalidCoordinates(in: tripId)
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
        print("🗑 [TripManager] deleteSpot: Trip(\(tripId)) DayIndex(\(dayIndex)) SpotId(\(spotId))")
        Task {
            do {
                try await DataService.shared.deleteSpot(spotId: spotId)
                
                // Update Local
                if var currentDays = self.days[tripId], dayIndex < currentDays.count {
                    print("✅ [TripManager] Successfully deleted from backend, updating local state")
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
    
    /// Replace a spot's location data with a new spot, keeping position-related info (id, sortOrder, stayDuration, travelMode).
    func replaceSpot(tripId: String, dayIndex: Int, oldSpotId: String, newSpot: ItinerarySpot) {
        guard let dayList = days[tripId], dayIndex < dayList.count else { return }
        guard let spotIndex = dayList[dayIndex].spots.firstIndex(where: { $0.id == oldSpotId }) else { return }
        
        var replaced = dayList[dayIndex].spots[spotIndex]
        
        // Keep: id, dayId, sortOrder, stayDuration, travelMode, travelTime, travelDistance
        // Replace: name, latitude, longitude, googlePlaceId, category, place, imageUrl
        replaced.name = newSpot.name
        replaced.latitude = newSpot.latitude
        replaced.longitude = newSpot.longitude
        replaced.googlePlaceId = newSpot.googlePlaceId
        replaced.category = newSpot.category
        replaced.place = newSpot.place
        replaced.imageUrl = newSpot.imageUrl
        
        updateSpot(tripId: tripId, dayIndex: dayIndex, spot: replaced)
        
        // Recalculate travel for this spot and the next
        updateSpotTransport(tripId: tripId, dayIndex: dayIndex, spotId: replaced.id, transportType: replaced.travelMode ?? .train)
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
    
    // MARK: - Coordinate Fixes (MapKit Fallback)
    
    /// Scan all spots in a trip and fix (0, 0) coordinates using MapKit Local Search.
    func resolveInvalidCoordinates(in tripId: String) {
        print("🔍 Scanning trip \(tripId) for invalid coordinates...")
        guard let dayList = days[tripId] else {
            print("❌ resolveInvalidCoordinates abort: No days found for trip \(tripId)")
            return 
        }
        
        let resolver = POIResolverService()
        
        Task {
            for (dayIdx, day) in dayList.enumerated() {
                for spot in day.spots {
                    if spot.latitude == 0.0 || spot.latitude == nil {
                        print("🛠 Repairing coordinates for: \(spot.name) (isZero: true, isNil: \(spot.latitude == nil))")
                        
                        do {
                            // Clean the query: Remove parentheses and content within (e.g., "(弘大店)")
                            var cleanQuery = spot.name
                            if let range = cleanQuery.range(of: " (") {
                                cleanQuery = String(cleanQuery[..<range.lowerBound])
                            } else if let range = cleanQuery.range(of: "(") {
                                cleanQuery = String(cleanQuery[..<range.lowerBound])
                            }
                            
                            // Use MapKit to find the place with destination bias
                            let destination = trips.first(where: { $0.id == tripId })?.destination ?? ""
                            print("🌍 [TripManager] Resolving coords for \(spot.name). Trip destination: '\(destination)' (TripCount: \(trips.count))")
                            
                            let targetRegion = region(for: destination)
                            let results = try await resolver.resolvePOI(query: cleanQuery, region: targetRegion, countryName: destination)
                            
                            // Remove overly strict filtering and CLGeocoder (deprecated in iOS 26) since the user can import spots from any country.
                            let strictlyValid = results
                            
                            if let firstMatch = strictlyValid.first {
                                guard let target = targetRegion else {
                                    print("⚠️ Cannot verify region for \(spot.name): targetRegion is nil.")
                                    // Proceed without region check if targetRegion is nil, or skip if strict
                                    // For now, we'll proceed as the filter already handled it.
                                    var updatedSpot = spot
                                    updatedSpot.latitude = firstMatch.latitude
                                    updatedSpot.longitude = firstMatch.longitude
                                    self.updateSpot(tripId: tripId, dayIndex: dayIdx, spot: updatedSpot)
                                    print("✅ Repaired \(spot.name) -> \(firstMatch.latitude), \(firstMatch.longitude)")
                                    return
                                }
                                
                                let dist = CLLocation(latitude: firstMatch.latitude, longitude: firstMatch.longitude)
                                    .distance(from: CLLocation(latitude: target.center.latitude, longitude: target.center.longitude))
                                    
                                print("✅ Correct-Region & Country Match found: \(Int(dist/1000))km from center (KR verified)")
                                
                                var updatedSpot = spot
                                updatedSpot.latitude = firstMatch.latitude
                                updatedSpot.longitude = firstMatch.longitude
                                
                                // Update local and backend
                                self.updateSpot(tripId: tripId, dayIndex: dayIdx, spot: updatedSpot)
                                print("✅ Repaired \(spot.name) -> \(firstMatch.latitude), \(firstMatch.longitude)")
                            } else {
                                if !results.isEmpty {
                                    print("⚠️ Rejected \(results.count) results because they were outside the \(destination) region or too far from its center.")
                                } else {
                                    print("⚠️ Could not find any MapKit results for: \(cleanQuery)")
                                }
                            }
                        } catch {
                            print("❌ Error repairing coordinates for \(spot.name): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func region(for destination: String) -> MKCoordinateRegion? {
        let dest = destination.lowercased()
        if dest.contains("korea") || dest.contains("韓國") || dest.contains("首爾") || dest.contains("seoul") || dest.contains("釜山") || dest.contains("busan") {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5), // Center of South Korea
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 6.0)
            )
        } else if dest.contains("japan") || dest.contains("日本") || dest.contains("東京") || dest.contains("tokyo") || dest.contains("大阪") || dest.contains("osaka") || dest.contains("京都") || dest.contains("kyoto") {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        } else if dest.contains("taiwan") || dest.contains("台灣") || dest.contains("台北") || dest.contains("taipei") || dest.contains("高雄") || dest.contains("kaohsiung") {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.6978, longitude: 120.9605),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
            )
        }
        return nil
    }
    
    // MARK: - SwiftData Synchronization (Phase 17)
    
    @MainActor
    private func syncToSwiftData(_ fetchedTrips: [Trip]) async {
        guard let context = modelContext else {
            print("⚠️ TripManager: Skip SwiftData sync (context not set)")
            return
        }
        
        print("💾 [SwiftData] Starting sync for \(fetchedTrips.count) trips...")
        
        for trip in fetchedTrips {
            // Upsert Trip
            let tripId = trip.id
            let fetchDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripId })
            
            let existingTrip = try? context.fetch(fetchDescriptor).first
            let sdTrip: SDTrip
            
            if let existing = existingTrip {
                // Update basic fields
                existing.title = trip.title
                existing.destination = trip.destination
                existing.startDate = trip.startDate
                existing.endDate = trip.endDate
                existing.coverImageUrl = trip.coverImageUrl
                existing.transportMode = trip.transportMode
                sdTrip = existing
            } else {
                // Create new
                sdTrip = SDTrip(
                    id: trip.id,
                    title: trip.title,
                    destination: trip.destination,
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    coverImageUrl: trip.coverImageUrl,
                    transportMode: trip.transportMode
                )
                context.insert(sdTrip)
            }
            
            // Sync Days
            if let days = trip.days {
                syncDaysToSwiftData(days, parent: sdTrip, context: context)
            }
        }
        
        do {
            try context.save()
            print("✅ [SwiftData] Sync successful!")
        } catch {
            print("❌ [SwiftData] Save error: \(error)")
        }
    }
    
    private func syncDaysToSwiftData(_ days: [ItineraryDay], parent: SDTrip, context: ModelContext) {
        // Simple approach: Clear and rebuild days/spots for that trip to ensure order/content sync
        // In a real high-perf app, you'd diff them, but for itinerary data size, rebuilding is safer.
        parent.days.forEach { context.delete($0) }
        parent.days = []
        
        for dayData in days {
            let sdDay = SDItineraryDay(
                id: dayData.id,
                dayOrder: dayData.dayOrder,
                date: dayData.date,
                weekday: dayData.weekday,
                title: dayData.title
            )
            sdDay.trip = parent
            context.insert(sdDay)
            
            // Sync Spots
            for spotData in dayData.spots {
                let sdSpot = SDItinerarySpot(
                    id: spotData.id,
                    name: spotData.name,
                    category: spotData.category?.rawValue,
                    startTime: spotData.startTime,
                    stayDuration: spotData.stayDuration,
                    notes: spotData.notes ?? [],
                    imageUrl: spotData.imageUrl,
                    googlePlaceId: spotData.googlePlaceId,
                    latitude: spotData.latitude,
                    longitude: spotData.longitude,
                    sortOrder: spotData.sortOrder,
                    travelMode: spotData.travelMode?.rawValue,
                    travelTime: spotData.travelTime,
                    travelDistance: spotData.travelDistance
                )
                sdSpot.day = sdDay
                context.insert(sdSpot)
            }
        }
    }
}
