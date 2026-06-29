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
    @Published var selectedTripId: String? = nil
    
    // SwiftData Context (External injection)
    var modelContext: ModelContext? {
        didSet {
            if modelContext != nil {
                loadFromSwiftData()
            }
        }
    }
    
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
            print("🌐 [TripManager] Fetching trips...")
            
            // 新增：從個人專屬雲端下載新建立的備份行程
            let uid = AuthManager.shared.currentUID
            if let backupFSTrips = try? await FirestoreService.shared.fetchUserCloudBackups(ownerUID: uid), let context = self.modelContext {
                for fsTrip in backupFSTrips {
                    let fetchDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == fsTrip.id })
                    if let localTrip = try? context.fetch(fetchDescriptor).first {
                        // 如果雲端備份比較新，覆蓋本地
                        if Date(timeIntervalSince1970: fsTrip.lastUpdated) > localTrip.lastUpdated {
                            // 在這裡可以直接覆蓋屬性，但簡單起見，我們利用 toSDTrip
                            let tempSDTrip = fsTrip.toSDTrip(inviteCode: fsTrip.id)
                            localTrip.title = tempSDTrip.title
                            localTrip.destination = tempSDTrip.destination
                            localTrip.startDate = tempSDTrip.startDate
                            localTrip.endDate = tempSDTrip.endDate
                            localTrip.coverImageUrl = tempSDTrip.coverImageUrl
                            localTrip.lastUpdated = tempSDTrip.lastUpdated
                            // Days & Spots 會比較複雜，簡化處理：先不深度同步，因為使用者通常只在一個設備編輯
                        }
                    } else {
                        // 本地沒有，直接寫入
                        let newSDTrip = fsTrip.toSDTrip(inviteCode: fsTrip.id)
                        // 強制把 inviteCode 設為 nil (如果它本來沒有共用)
                        if fsTrip.collaborators.count <= 1 {
                            newSDTrip.inviteCode = nil
                        }
                        context.insert(newSDTrip)
                    }
                }
                try? context.save()
            }
            
            // 從 SwiftData 重新載入至記憶體
            loadFromSwiftData()
            print("✅ [TripManager] Successfully fetched and synced trips.")
        } catch {
            print("❌ [TripManager] fetchTrips error: \(error)")
            // 如果發生錯誤，仍嘗試載入本地快取
            loadFromSwiftData()
        }
        
        isLoading = false
    }
    
    // Phase 17: Load from Local Storage
    private func loadFromSwiftData() {
        guard let context = modelContext else { return }
        
        print("💾 [SwiftData] Loading cached trips...")
        let descriptor = FetchDescriptor<SDTrip>()
        if var cachedTrips = try? context.fetch(descriptor) {
            // Sort using ordered_trip_ids
            if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo"),
               let orderedIds = userDefaults.stringArray(forKey: "ordered_trip_ids") {
                cachedTrips.sort { (t1, t2) -> Bool in
                    let index1 = orderedIds.firstIndex(of: t1.id) ?? Int.max
                    let index2 = orderedIds.firstIndex(of: t2.id) ?? Int.max
                    return index1 < index2
                }
            }
            
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
                    days: sdTrip.days.sorted(by: { ($0.dayOrder ?? 0) < ($1.dayOrder ?? 0) }).map { sdDay in
                        ItineraryDay(
                            id: sdDay.id,
                            dayOrder: sdDay.dayOrder,
                            date: sdDay.date,
                            weekday: sdDay.weekday,
                            title: sdDay.title,
                            spots: sdDay.spots.sorted(by: { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }).map { sdSpot in
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
                                    travelMode: (sdSpot.travelMode != nil && !sdSpot.travelMode!.isEmpty) ? TransportType(rawValue: sdSpot.travelMode!.lowercased()) : nil,
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
            
            Task { @MainActor in
                DataService.shared.syncPendingPlaceActions(tripManager: self)
            }
        }
    }
    
    func saveTripOrder() {
        let ids = self.trips.map { $0.id }
        if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo") {
            userDefaults.set(ids, forKey: "ordered_trip_ids")
        }
        // Sync trips summary to App Group to update share extension list order immediately
        DataService.shared.syncTripsToAppGroup()
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
            // 已棄用 Python API，改為純本地建立 + Firestore 同步
            let newTripId = UUID().uuidString
            let newTrip = Trip(
                id: newTripId,
                title: title.isEmpty ? destination : title,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                coverImageUrl: nil,
                transportMode: "大眾運輸",
                days: []
            )
            
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: endDate)
            let components = calendar.dateComponents([.day], from: start, to: end)
            let numberOfDays = max(1, (components.day ?? 0) + 1)
            
            var generatedDays: [ItineraryDay] = []
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_Hant_TW")
            dateFormatter.dateFormat = "EEEE"
            
            for i in 0..<numberOfDays {
                if let dayDate = calendar.date(byAdding: .day, value: i, to: start) {
                    let weekdayStr = dateFormatter.string(from: dayDate)
                    let day = ItineraryDay(
                        id: Int.random(in: 100000...999999),
                        dayOrder: i + 1,
                        date: dayDate,
                        weekday: weekdayStr,
                        title: "第 \(i + 1) 天",
                        spots: []
                    )
                    generatedDays.append(day)
                }
            }
            
            var tripWithDays = newTrip
            tripWithDays.days = generatedDays
            
            await MainActor.run {
                self.trips.append(tripWithDays)
                self.days[newTripId] = generatedDays
            }
            
            await syncToSwiftData([tripWithDays])
            self.triggerCollaborationSync(tripId: newTripId)
            
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
        
        var newSpot = spot
        newSpot.dayId = dayId
        
        // Update Local State
        await MainActor.run {
            if var currentDays = self.days[tripId] {
                if newSpot.category == .accommodation {
                    currentDays[dayIndex].spots.insert(newSpot, at: 0)
                } else {
                    currentDays[dayIndex].spots.append(newSpot)
                }
                
                // 重新校正所有的 sortOrder
                for (index, _) in currentDays[dayIndex].spots.enumerated() {
                    currentDays[dayIndex].spots[index].sortOrder = index
                }
                
                self.days[tripId] = currentDays
                
                if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                    trips[idx].days = currentDays
                }
            }
        }
        
        // If this was an accommodation, trigger travel time calculation to the first regular spot
        if newSpot.category == .accommodation {
            if let updatedDays = self.days[tripId],
               dayIndex < updatedDays.count {
                let firstRegularSpot = updatedDays[dayIndex].spots.first(where: { $0.category != .accommodation })
                if let firstSpot = firstRegularSpot,
                   let fromCoord = newSpot.coordinate,
                   let toCoord = firstSpot.coordinate {
                    calculateTravel(from: fromCoord, to: toCoord, mode: .train) { time, dist in
                        if var finalDays = self.days[tripId],
                           dayIndex < finalDays.count,
                           let hotelIdx = finalDays[dayIndex].spots.firstIndex(where: { $0.id == newSpot.id }) {
                            finalDays[dayIndex].spots[hotelIdx].travelTime = time
                            finalDays[dayIndex].spots[hotelIdx].travelDistance = dist
                            self.days[tripId] = finalDays
                            if let tIdx = self.trips.firstIndex(where: { $0.id == tripId }) {
                                self.trips[tIdx].days = finalDays
                            }
                        }
                    }
                }
            }
        }
        
        self.triggerCollaborationSync(tripId: tripId)
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
            // Determine dayId from existing data
            var newSpot = spot
            newSpot.dayId = dayId
            
            // Update Local State
            await MainActor.run {
                if var currentDays = self.days[tripId] {
                    if spot.category == .accommodation {
                        // Accommodation always goes to the top
                        currentDays[dayIndex].spots.insert(newSpot, at: 0)
                    } else {
                        currentDays[dayIndex].spots.append(newSpot)
                    }
                    
                    self.cascadeTimes(in: &currentDays, dayIndex: dayIndex, startIndex: 0)
                    
                    // 重新校正所有的 sortOrder，避免重啟後順序大亂
                    for (index, _) in currentDays[dayIndex].spots.enumerated() {
                        currentDays[dayIndex].spots[index].sortOrder = index
                    }
                    
                    self.days[tripId] = currentDays
                    
                    // Trigger travel calculation if there's a next spot
                    let spots = currentDays[dayIndex].spots
                    if let newSpotIdx = spots.firstIndex(where: { $0.id == newSpot.id }),
                       newSpotIdx < spots.count - 1 {
                       self.updateSpotTransport(tripId: tripId, dayIndex: dayIndex, spotId: newSpot.id, transportType: newSpot.travelMode)
                    }
                    
                    if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                        trips[idx].days = currentDays
                    }
                }
            }
            // Auto-repair if coordinates are 0,0
            self.resolveInvalidCoordinates(in: tripId)
            self.triggerCollaborationSync(tripId: tripId)
        }
    }
    
    func updateSpot(tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        // 1. Optimistic Local Update
        self.updateSpotLocal(tripId: tripId, dayIndex: dayIndex, spot: spot)
        
        // 2. Auto-repair check and Firestore Sync
        Task {
            self.triggerCollaborationSync(tripId: tripId)
        }
    }
    
    // MARK: - Time Calculation Helpers
    func calculateEndTime(start: String, duration: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        var totalMinutes = 60 // default 1 hour
        let cleaned = duration.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "小", with: "")
        
        var hours = 0
        var minutes = 0
        
        if let hourRange = cleaned.range(of: #"(\d+)時"#, options: .regularExpression) {
            let match = String(cleaned[hourRange])
            if let h = Int(match.replacingOccurrences(of: "時", with: "")) { hours = h }
        }
        if let minRange = cleaned.range(of: #"(\d+)分"#, options: .regularExpression) {
            let match = String(cleaned[minRange])
            if let m = Int(match.replacingOccurrences(of: "分鐘", with: "").replacingOccurrences(of: "分", with: "")) { minutes = m }
        }
        
        if hours > 0 || minutes > 0 {
            totalMinutes = hours * 60 + minutes
        } else if let val = Int(duration) {
            totalMinutes = val
        }
        
        if let date = formatter.date(from: start) {
            let endDate = date.addingTimeInterval(TimeInterval(totalMinutes * 60))
            return formatter.string(from: endDate)
        }
        return start
    }
    
    func addMinutes(to timeString: String, minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: timeString) {
            let newDate = date.addingTimeInterval(TimeInterval(minutes * 60))
            return formatter.string(from: newDate)
        }
        return timeString
    }
    
    private func cascadeTimes(in dayList: inout [ItineraryDay], dayIndex: Int, startIndex: Int) {
        guard dayIndex < dayList.count else { return }
        var spots = dayList[dayIndex].spots
        guard spots.count > 1 && startIndex >= 0 && startIndex < spots.count - 1 else { return }
        
        var didUpdate = false
        for i in (startIndex + 1)..<spots.count {
            let prevSpot = spots[i - 1]
            var currSpot = spots[i]
            
            // End time of previous spot
            var nextStartTime = self.calculateEndTime(start: prevSpot.time, duration: prevSpot.duration)
            
            // Add transit time if available
            if let travelInfo = prevSpot.travelToNext {
                let travelTimeStr = travelInfo.time
                let cleaned = travelTimeStr.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "小", with: "")
                var h = 0, m = 0
                if let hourRange = cleaned.range(of: #"(\d+)時"#, options: .regularExpression) {
                    let match = String(cleaned[hourRange])
                    if let val = Int(match.replacingOccurrences(of: "時", with: "")) { h = val }
                }
                if let minRange = cleaned.range(of: #"(\d+)分"#, options: .regularExpression) {
                    let match = String(cleaned[minRange])
                    if let val = Int(match.replacingOccurrences(of: "分鐘", with: "").replacingOccurrences(of: "分", with: "")) { m = val }
                }
                let transitMins = h * 60 + m
                if transitMins > 0 {
                    nextStartTime = self.addMinutes(to: nextStartTime, minutes: transitMins)
                }
            }
            
            if currSpot.time != nextStartTime {
                currSpot.time = nextStartTime
                spots[i] = currSpot
                didUpdate = true
            }
        }
        
        if didUpdate {
            dayList[dayIndex].spots = spots
        }
    }
    
    // Help for local only persistence (Optimistic UI)
    private func updateSpotLocal(tripId: String, dayIndex: Int, spot: ItinerarySpot) {
        DispatchQueue.main.async {
            if var currentDays = self.days[tripId], dayIndex < currentDays.count {
                if let idx = currentDays[dayIndex].spots.firstIndex(where: { $0.id == spot.id }) {
                    let oldSpot = currentDays[dayIndex].spots[idx]
                    currentDays[dayIndex].spots[idx] = spot
                    
                    if oldSpot.time != spot.time || oldSpot.duration != spot.duration {
                        self.cascadeTimes(in: &currentDays, dayIndex: dayIndex, startIndex: idx)
                    }
                    
                    self.objectWillChange.send() // Force SwiftUI to re-render immediately
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
        
        // Local Update
        if var currentDays = self.days[tripId], dayIndex < currentDays.count {
            print("🚀 [TripManager] Optimistically deleting from local state")
            
            // Delete image from Firebase Storage if present
            if let spot = currentDays[dayIndex].spots.first(where: { $0.id == spotId }),
               let imageUrl = spot.imageUrl, imageUrl.contains("user_image") {
                Task {
                    await DataService.shared.deleteImage(url: imageUrl)
                }
            }
            
            currentDays[dayIndex].spots.removeAll { $0.id == spotId }
            self.cascadeTimes(in: &currentDays, dayIndex: dayIndex, startIndex: 0)
            
            // 重新校正所有的 sortOrder，避免重啟後順序大亂
            for (index, _) in currentDays[dayIndex].spots.enumerated() {
                currentDays[dayIndex].spots[index].sortOrder = index
            }
            
            self.days[tripId] = currentDays
            
            if let idx = trips.firstIndex(where: { $0.id == tripId }) {
                trips[idx].days = currentDays
            }
        }
        
        // Sync to Firestore
        self.triggerCollaborationSync(tripId: tripId)
    }
    
    // Transport update wrapper
    func updateSpotTransport(tripId: String, dayIndex: Int, spotId: String, transportType: TransportType?) {
        print("🚀 updateSpotTransport: spotId=\(spotId), newType=\(transportType?.rawValue ?? "nil")")
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
                calculateTravel(from: start, to: end, mode: transportType ?? .train) { time, dist in
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
        let startPlacemark = MKPlacemark(coordinate: startCoord)
        let endPlacemark = MKPlacemark(coordinate: endCoord)
        
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        
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
                case .train, .bus: speed = 4.16 // 15km/h (accounts for walking/waiting)
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
        
        // Ensure standard time cascade logic after move
        self.cascadeTimes(in: &dayList, dayIndex: dayIndex, startIndex: 0)
        
        for (index, _) in dayList[dayIndex].spots.enumerated() {
            dayList[dayIndex].spots[index].sortOrder = index
        }
        self.days[tripId] = dayList
        if let idx = self.trips.firstIndex(where: { $0.id == tripId }) {
            self.trips[idx].days = dayList
        }
        
        // Update SwiftData immediately
        if let context = self.modelContext {
            let dayDbId = dayList[dayIndex].id
            let descriptor = FetchDescriptor<SDItineraryDay>(predicate: #Predicate { $0.id == dayDbId })
            if let sdDay = try? context.fetch(descriptor).first {
                for (index, spot) in dayList[dayIndex].spots.enumerated() {
                    if let sdSpot = sdDay.spots.first(where: { $0.id == spot.id }) {
                        sdSpot.sortOrder = index
                    }
                }
                try? context.save()
            }
        }
        
        self.triggerCollaborationSync(tripId: tripId)
    }
    
    // Reorder (Move) regular spots only, preserving accommodations in their current positions
    func moveRegularSpot(tripId: String, dayIndex: Int, from source: IndexSet, to destination: Int) {
        guard var dayList = days[tripId], dayIndex < dayList.count else { return }
        
        let allSpots = dayList[dayIndex].spots
        var regularSpots = allSpots.filter { $0.category != .accommodation }
        
        // Move within regular spots array
        regularSpots.move(fromOffsets: source, toOffset: destination)
        
        // Reconstruct the full spots list preserving accommodations at their original indices
        var reconstructedSpots: [ItinerarySpot] = []
        var regularIndex = 0
        for spot in allSpots {
            if spot.category == .accommodation {
                reconstructedSpots.append(spot)
            } else {
                if regularIndex < regularSpots.count {
                    reconstructedSpots.append(regularSpots[regularIndex])
                    regularIndex += 1
                }
            }
        }
        
        // Update sortOrder for all spots based on their new index
        for (index, _) in reconstructedSpots.enumerated() {
            reconstructedSpots[index].sortOrder = index
        }
        
        dayList[dayIndex].spots = reconstructedSpots
        
        // Ensure standard time cascade logic after move
        self.cascadeTimes(in: &dayList, dayIndex: dayIndex, startIndex: 0)
        
        self.days[tripId] = dayList
        if let idx = self.trips.firstIndex(where: { $0.id == tripId }) {
            self.trips[idx].days = dayList
        }
        
        // Update SwiftData immediately
        if let context = self.modelContext {
            let dayDbId = dayList[dayIndex].id
            let descriptor = FetchDescriptor<SDItineraryDay>(predicate: #Predicate { $0.id == dayDbId })
            if let sdDay = try? context.fetch(descriptor).first {
                for (index, spot) in reconstructedSpots.enumerated() {
                    if let sdSpot = sdDay.spots.first(where: { $0.id == spot.id }) {
                        sdSpot.sortOrder = index
                    }
                }
                try? context.save()
            }
        }
        
        // Reorder locally, sync triggered elsewhere or we can trigger it.
        
        self.triggerCollaborationSync(tripId: tripId)
    }
    
    // Move to different day
    func moveSpotToDay(tripId: String, fromDayIndex: Int, spotId: String, toDayIndex: Int) {
         guard let dayList = self.days[tripId],
               fromDayIndex < dayList.count,
               toDayIndex < dayList.count,
               dayList[fromDayIndex].spots.contains(where: { $0.id == spotId }) else { return }
        
        // Optimistic update:
        if var days = self.days[tripId],
           fromDayIndex < days.count,
           toDayIndex < days.count,
           let idx = days[fromDayIndex].spots.firstIndex(where: {$0.id == spotId}) {
            
            var movedSpot = days[fromDayIndex].spots.remove(at: idx)
            // Update dayId to match destination
            movedSpot.dayId = days[toDayIndex].id
            days[toDayIndex].spots.append(movedSpot)
            
            // Re-cascade times after removal and insertion
            self.cascadeTimes(in: &days, dayIndex: fromDayIndex, startIndex: 0)
            self.cascadeTimes(in: &days, dayIndex: toDayIndex, startIndex: 0)
            
            // Save local state
            self.days[tripId] = days
            if let tIdx = self.trips.firstIndex(where: { $0.id == tripId }) {
                self.trips[tIdx].days = days
            }
        }
        
        // Trigger sync to cloud
        self.triggerCollaborationSync(tripId: tripId)
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
        // Defer this to ensure updateSpotLocal has already written the new spot to the state
        DispatchQueue.main.async {
            self.updateSpotTransport(tripId: tripId, dayIndex: dayIndex, spotId: replaced.id, transportType: replaced.travelMode)
        }
    }
    
    func deleteTrip(id: String) {
        // Save to trash before deleting
        if let trip = trips.first(where: { $0.id == id }) {
            TripTrashManager.shared.addToTrash(trip)
            DataService.shared.removeFromCache(title: trip.title)
        }
        
        // 立即從 SwiftData 本地快取刪除，防止重啟後重新出現
        if let context = modelContext {
            let fetchDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
            if let sdTrip = try? context.fetch(fetchDescriptor).first {
                context.delete(sdTrip)
                try? context.save()
                print("🗑️ [SwiftData] Deleted local trip: \(id)")
            }
        }
        
        Task {
            // 已棄用舊版 Python REST API，直接更新本機狀態即可 (雲端由 SwiftData + Firestore 接管)
            self.trips.removeAll { $0.id == id }
            self.days.removeValue(forKey: id)
            
            // 同步從雲端備份刪除
            if AuthManager.shared.isSignedIn {
                try? await FirestoreService.shared.deleteTripBackup(tripId: id, ownerUID: AuthManager.shared.currentUID)
            }
        }
    }
    
    // MARK: - Legacy / Stubbed methods (to prevent UI crash if used)
    func updateTripSettings(tripId: String, title: String, destination: String, transportMode: String) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].title = title
            trips[index].destination = destination
            trips[index].transportMode = transportMode
            
            let updatedTrip = trips[index]
            Task {
                await syncToSwiftData([updatedTrip])
                self.triggerCollaborationSync(tripId: tripId)
            }
        }
    }
    
    func updateTripDates(tripId: String, newStartDate: Date, newEndDate: Date) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].startDate = newStartDate
            trips[index].endDate = newEndDate
            
            let updatedTrip = trips[index]
            Task {
                await syncToSwiftData([updatedTrip])
                self.triggerCollaborationSync(tripId: tripId)
            }
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
        withAnimation {
            currentDays[dayIndex].spots = optimized
            self.cascadeTimes(in: &currentDays, dayIndex: dayIndex, startIndex: 0)
            self.days[tripId] = currentDays
        }
        
        self.triggerCollaborationSync(tripId: tripId)
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
            // Restore context locally first
            withAnimation {
                currentDays[dayIndex].spots = original
                self.days[tripId] = currentDays
            }
            
            // Clear backup immediately so UI un-sticks
            originalSpotsOrder[tripId]?.removeValue(forKey: dayId)
            
            self.triggerCollaborationSync(tripId: tripId)
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
                    if spot.latitude == 0.0 || spot.latitude == nil || (spot.googlePlaceId ?? "").isEmpty {
                        print("🛠 Repairing coordinates and Place ID for: \(spot.name)")
                        
                        var updatedSpot = spot
                        
                        // 1. Clean the query
                        var cleanQuery = spot.name
                        do {
                            let plusCodeRegex = try NSRegularExpression(pattern: "[A-Z0-9]{2,4}\\+[A-Z0-9]{2,4}.*$", options: [])
                            cleanQuery = plusCodeRegex.stringByReplacingMatches(in: cleanQuery, options: [], range: NSRange(location: 0, length: cleanQuery.utf16.count), withTemplate: "")
                            let chomeRegex = try NSRegularExpression(pattern: "\\s*\\d+\\s*[Cc]home.*$", options: [])
                            cleanQuery = chomeRegex.stringByReplacingMatches(in: cleanQuery, options: [], range: NSRange(location: 0, length: cleanQuery.utf16.count), withTemplate: "")
                            let floorRegex = try NSRegularExpression(pattern: "\\s*\\d+[Ff]\\b.*$", options: [])
                            cleanQuery = floorRegex.stringByReplacingMatches(in: cleanQuery, options: [], range: NSRange(location: 0, length: cleanQuery.utf16.count), withTemplate: "")
                            let basementRegex = try NSRegularExpression(pattern: "\\s*[Bb]\\d+\\b.*$", options: [])
                            cleanQuery = basementRegex.stringByReplacingMatches(in: cleanQuery, options: [], range: NSRange(location: 0, length: cleanQuery.utf16.count), withTemplate: "")
                        } catch {}
                        
                        cleanQuery = cleanQuery.replacingOccurrences(of: "+", with: " ")
                        
                        if let range = cleanQuery.range(of: " (") { cleanQuery = String(cleanQuery[..<range.lowerBound]) }
                        else if let range = cleanQuery.range(of: "(") { cleanQuery = String(cleanQuery[..<range.lowerBound]) }
                        if let range = cleanQuery.range(of: " · ") { cleanQuery = String(cleanQuery[..<range.lowerBound]) }
                        if let range = cleanQuery.range(of: " • ") { cleanQuery = String(cleanQuery[..<range.lowerBound]) }
                        
                        cleanQuery = cleanQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 2. Try Google Places API First
                        // Use alphanumericset to properly escape '&' and other characters in the query parameter
                        var allowedCharacters = CharacterSet.urlQueryAllowed
                        allowedCharacters.remove("&")
                        allowedCharacters.remove("+")
                        
                        // If the query is just a placeholder, don't try to search for it by text!
                        if cleanQuery == "未命名地點" {
                            print("⚠️ [TripManager] Skipping text search for placeholder name: 未命名地點")
                            // We still want to update the spot if we can, but we rely entirely on its coordinates
                            self.updateSpot(tripId: tripId, dayIndex: dayIdx, spot: updatedSpot)
                            continue
                        }
                        
                        if let encodedQuery = cleanQuery.addingPercentEncoding(withAllowedCharacters: allowedCharacters) {
                            let lat = spot.latitude ?? 0.0
                            let lng = spot.longitude ?? 0.0
                            var urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&language=zh-TW&key=\(Secrets.googleAPIKey)"
                            if lat != 0.0 && lng != 0.0 {
                                urlString += "&location=\(lat),\(lng)&radius=1000"
                            }
                            
                            if let url = URL(string: urlString) {
                                do {
                                    let (data, response) = try await URLSession.shared.data(from: url)
                                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                                        print("❌ [TripManager] Google API HTTP Error: \(httpResponse.statusCode)")
                                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                        if let status = json["status"] as? String, status != "OK" {
                                            print("❌ [TripManager] Google API Status Error: \(status), Message: \(json["error_message"] as? String ?? "")")
                                        } else if let results = json["results"] as? [[String: Any]], let firstRes = results.first {
                                            
                                            if let pId = firstRes["place_id"] as? String {
                                                updatedSpot.googlePlaceId = pId
                                            }
                                            // 保留原本的景點名稱，不要被 Google 的預設名稱覆寫
                                            // if let localName = firstRes["name"] as? String {
                                            //     updatedSpot.name = localName
                                            // }
                                            if let geometry = firstRes["geometry"] as? [String: Any],
                                               let location = geometry["location"] as? [String: Double],
                                               let resLat = location["lat"], let resLng = location["lng"] {
                                                updatedSpot.latitude = resLat
                                                updatedSpot.longitude = resLng
                                            }
                                            
                                            print("✅ [TripManager] Enriched \(spot.name) via Google -> \(updatedSpot.name), \(updatedSpot.googlePlaceId ?? "")")
                                            self.updateSpot(tripId: tripId, dayIndex: dayIdx, spot: updatedSpot)
                                            try? await Task.sleep(nanoseconds: 200_000_000) // Sleep 0.2s to prevent UI thread lag
                                            continue // Success! Move to next spot
                                        } else {
                                            print("⚠️ [TripManager] Google API returned no results for query: \(cleanQuery)")
                                        }
                                    }
                                } catch {
                                    print("❌ [TripManager] Google API Network Error: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                        // 3. Fallback to MapKit
                        do {
                            let destination = trips.first(where: { $0.id == tripId })?.destination ?? ""
                            print("🌍 [TripManager] Resolving coords for \(spot.name) via MapKit. Trip destination: '\(destination)'")
                            
                            let targetRegion = region(for: destination)
                            let results = try await resolver.resolvePOI(query: cleanQuery, region: targetRegion, countryName: destination)
                            
                            if let firstMatch = results.first {
                                updatedSpot.latitude = firstMatch.latitude
                                updatedSpot.longitude = firstMatch.longitude
                                self.updateSpot(tripId: tripId, dayIndex: dayIdx, spot: updatedSpot)
                                print("✅ [TripManager] Repaired \(spot.name) via MapKit -> \(firstMatch.latitude), \(firstMatch.longitude)")
                            } else {
                                print("⚠️ Could not find any MapKit results for: \(cleanQuery)")
                            }
                        } catch {
                            print("❌ Error repairing coordinates for \(spot.name): \(error)")
                        }
                        
                        // Prevent MKLocalSearch throttling
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
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
        
        // Phase 17.5: Pruning - Remove local trips that no longer exist on server
        let fetchedIds = Set(fetchedTrips.map { $0.id })
        let allLocalDescriptor = FetchDescriptor<SDTrip>()
        if let allLocal = try? context.fetch(allLocalDescriptor) {
            for local in allLocal {
                if !fetchedIds.contains(local.id) {
                    if local.inviteCode != nil {
                        // Skip pruning collaborated trips
                        continue
                    }
                    print("🗑️ [SwiftData] Pruning local zombie trip: \(local.id) (\(local.title))")
                    context.delete(local)
                }
            }
        }

        for trip in fetchedTrips {
            // Upsert Trip
            let tripId = trip.id
            let fetchDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripId })
            
            let existingTrip = try? context.fetch(fetchDescriptor).first
            let sdTrip: SDTrip
            
            if let existing = existingTrip {
                // LWW (Last Write Wins) Conflict Resolution
                if let serverUpdated = trip.updatedAt, existing.updatedAt > serverUpdated {
                    print("🛡️ [LWW] Local trip \(trip.id) is newer. Skipping sync from server.")
                    continue
                }
                
                // Update basic fields
                existing.title = trip.title
                existing.destination = trip.destination
                existing.startDate = trip.startDate
                existing.endDate = trip.endDate
                existing.coverImageUrl = trip.coverImageUrl
                existing.transportMode = trip.transportMode
                if let serverUpdated = trip.updatedAt {
                    existing.updatedAt = serverUpdated
                }
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
    
    /// Triggers collaboration sync for a specific trip after local changes are made
    func triggerCollaborationSync(tripId: String) {
        Task {
            // Ensure local memory state is synced to SwiftData first
            await self.syncToSwiftData(self.trips)
            
            // Fetch the updated SDTrip and push to Firestore if it has an invite code
            guard let context = self.modelContext else { return }
            let fetchDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripId })
            if let sdTrip = try? context.fetch(fetchDescriptor).first {
                let uid = AuthManager.shared.currentUID
                sdTrip.lastUpdated = Date()
                try? context.save()
                
                // 1. 強制備份到個人專屬雲端（無論是否共用）
                try? await FirestoreService.shared.backupTripToUserCloud(sdTrip, ownerUID: uid)
                
                // 2. 如果有開啟協作，再同步到共用資料庫
                if sdTrip.inviteCode != nil {
                    await TripSyncManager.shared.pushLocalChanges(trip: sdTrip, ownerUID: uid)
                }
            }
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
    
    func importCuratedPostToLibrary(_ post: CuratedPost, selectedSpots: [PlaceInfo]) {
        // 現在與 importCuratedPost 邏輯一致，未來若兩者有別可分開實作
        importCuratedPost(post, selectedSpots: selectedSpots)
    }
    
    func importCuratedPost(_ post: CuratedPost, selectedSpots: [PlaceInfo]) {
        guard let context = modelContext else { 
            print("❌ [TripManager] Import failed: modelContext is nil")
            return 
        }
        
        // ⚡️ 加強防守：即使按鈕沒擋住，底層也要擋住重複插入
        if let url = post.sourceUrl, DataService.shared.isPostCollected(url: url, title: post.title) {
            print("⚠️ [TripManager] Post already in library, skipping creation.")
            return
        }
        
        // 1. Create SDContent
        let newContent = SDContent(
            id: UUID().uuidString,
            sourceType: "instagram",
            sourceUrl: post.sourceUrl,
            title: post.title,
            text: post.title,
            authorName: post.author,
            authorAvatarUrl: nil,
            previewThumbnailUrl: post.coverImageUrl,
            publishedAt: nil,
            unresolvedQueries: [],
            userCategory: nil,
            userNote: nil,
            createdAt: Date()
        )
        
        // 2. Create SDPlaces and link them
        for spot in selectedSpots {
            let sdPlace = SDPlace(
                id: spot.placeId ?? UUID().uuidString,
                name: spot.name ?? "未知地點",
                address: spot.address,
                latitude: spot.latitude ?? 0.0,
                longitude: spot.longitude ?? 0.0,
                category: spot.category,
                rating: spot.rating,
                userRatingCount: spot.userRatingsTotal,
                openNow: nil,
                confidenceScore: 1.0,
                createdAt: Date(),
                openingHours: nil
            )
            // Use relationship to link
            sdPlace.imageUrl = post.coverImageUrl // 確保景點本身也直接持有貼文圖片
            sdPlace.contents.append(newContent)
            newContent.places.append(sdPlace)
            context.insert(sdPlace)
        }
        
        context.insert(newContent)
        
        // ⚡️ 核心修復：立即通知 DataService 更新快取，確保 UI 愛心同步
        if let url = post.sourceUrl {
            DataService.shared.addToCache(url: url, title: post.title)
        }
        
        do {
            try context.save()
            print("✅ [TripManager] Successfully imported curated post (\(selectedSpots.count) spots) to library")
            self.objectWillChange.send()
            
            // 3. Sync to Cloud
            if let url = post.sourceUrl {
                let pIds = selectedSpots.compactMap { $0.placeId }
                Task {
                    await DataService.shared.syncCollectionWithPlaces(url: url, placeIds: pIds)
                }
            }
        } catch {
            print("❌ [TripManager] SwiftData save error: \(error)")
        }
    }
}

// MARK: - SDTrip to Trip Extension
extension SDTrip {
    func toTrip() -> Trip {
        Trip(
            id: self.id,
            title: self.title,
            destination: self.destination,
            startDate: self.startDate,
            endDate: self.endDate,
            coverImageUrl: self.coverImageUrl,
            transportMode: self.transportMode,
            updatedAt: self.lastUpdated,
            inviteCode: self.inviteCode,
            days: self.days.map { sdDay in
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
                            travelMode: (sdSpot.travelMode != nil && !sdSpot.travelMode!.isEmpty) ? TransportType(rawValue: sdSpot.travelMode!.lowercased()) : nil,
                            travelTime: sdSpot.travelTime,
                            travelDistance: sdSpot.travelDistance
                        )
                    }.sorted(by: { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) })
                )
            }.sorted(by: { ($0.dayOrder ?? 0) < ($1.dayOrder ?? 0) })
        )
    }
}
