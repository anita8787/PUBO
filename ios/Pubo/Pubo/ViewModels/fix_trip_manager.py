import re

file_path = "TripManager.swift"
with open(file_path, "r") as f:
    content = f.read()

# 1. Replace fetchTrips
fetch_trips_pattern = re.compile(r"    func fetchTrips\(\) async \{.*?\n    \}", re.DOTALL)
fetch_trips_replacement = """    func fetchTrips() async {
        self.errorMessage = nil
        isLoading = true
        // 舊版 API 已經移除，現在只從 SwiftData 載入，雲端同步由 TripSyncManager 處理
        loadFromSwiftData()
        isLoading = false
    }"""
content = fetch_trips_pattern.sub(fetch_trips_replacement, content, count=1)

# 2. Replace addTrip
add_trip_pattern = re.compile(r"    func addTrip\(title: String, destination: String, startDate: Date, endDate: Date\) \{.*?isLoading = false\n        \}\n    \}", re.DOTALL)
add_trip_replacement = """    func addTrip(title: String, destination: String, startDate: Date, endDate: Date) {
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
    }"""
content = add_trip_pattern.sub(add_trip_replacement, content, count=1)

# 3. Replace moveSpot reorder API call
reorder_pattern_1 = re.compile(r"        let dayId = dayList\[dayIndex\]\.id\n        let sortedSpotIds = dayList\[dayIndex\]\.spots\.map \{ \$0\.id \}\n        \n        Task \{\n            do \{\n                try await DataService\.shared\.reorderSpots\(dayId: dayId, spotIds: sortedSpotIds\)\n            \} catch \{\n                print\(\"Reorder Error: \\\(error\)\"\)\n                // Revert\? For now just log.\n            \}\n        \}\n        \n        self\.triggerCollaborationSync\(tripId: tripId\)", re.DOTALL)
content = reorder_pattern_1.sub("        self.triggerCollaborationSync(tripId: tripId)", content, count=1)

# 4. Replace moveRegularSpot reorder API call
reorder_pattern_2 = re.compile(r"        let dayId = dayList\[dayIndex\]\.id\n        let sortedSpotIds = dayList\[dayIndex\]\.spots\.map \{ \$0\.id \}\n        \n        Task \{\n            do \{\n                try await DataService\.shared\.reorderSpots\(dayId: dayId, spotIds: sortedSpotIds\)\n            \} catch \{\n                print\(\"Reorder Regular Spots Error: \\\(error\)\"\)\n            \}\n        \}", re.DOTALL)
content = reorder_pattern_2.sub("        // Reorder locally, sync triggered elsewhere or we can trigger it.", content, count=1)

# 5. Replace moveDay API call
move_day_pattern = re.compile(r"            // Real API call:.*?\} catch \{\n               print\(\"Move Day Error: \\\(error\)\"\)\n            \}", re.DOTALL)
move_day_replacement = """            // Just trigger sync
            self.triggerCollaborationSync(tripId: tripId)"""
content = move_day_pattern.sub(move_day_replacement, content, count=1)

# 6. Replace updateTripSettings
update_settings_pattern = re.compile(r"    func updateTripSettings\(tripId: String, title: String, destination: String, transportMode: String\) \{.*?isLoading = false\n        \}\n    \}", re.DOTALL)
update_settings_replacement = """    func updateTripSettings(tripId: String, title: String, destination: String, transportMode: String) {
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
    }"""
content = update_settings_pattern.sub(update_settings_replacement, content, count=1)

# 7. Replace updateTripDates
update_dates_pattern = re.compile(r"    func updateTripDates\(tripId: String, newStartDate: Date, newEndDate: Date\) \{.*?self\.triggerCollaborationSync\(tripId: tripId\)\n    \}", re.DOTALL)
update_dates_replacement = """    func updateTripDates(tripId: String, newStartDate: Date, newEndDate: Date) {
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].startDate = newStartDate
            trips[index].endDate = newEndDate
            
            let updatedTrip = trips[index]
            Task {
                await syncToSwiftData([updatedTrip])
                self.triggerCollaborationSync(tripId: tripId)
            }
        }
    }"""
content = update_dates_pattern.sub(update_dates_replacement, content, count=1)

# 8. Replace smartSort API call
smart_sort_pattern = re.compile(r"        let dayDbId = currentDays\[dayIndex\]\.id\n        let sortedSpotIds = optimized\.map \{ \$0\.id \}\n        \n        do \{\n            try await DataService\.shared\.reorderSpots\(dayId: dayDbId, spotIds: sortedSpotIds\)\n        \} catch \{\n            print\(\"Smart Sort API Error: \\\(error\)\"\)\n        \}", re.DOTALL)
content = smart_sort_pattern.sub("        self.triggerCollaborationSync(tripId: tripId)", content, count=1)

# 9. Replace restoreOriginalOrder API call
restore_pattern = re.compile(r"            // Update Backend\n            let dayDbId = currentDays\[dayIndex\]\.id\n            let sortedSpotIds = original\.map \{ \$0\.id \}\n            \n            do \{\n                try await DataService\.shared\.reorderSpots\(dayId: dayDbId, spotIds: sortedSpotIds\)\n            \} catch \{\n                print\(\"Restore API Error: \\\(error\)\"\)\n            \}", re.DOTALL)
content = restore_pattern.sub("            self.triggerCollaborationSync(tripId: tripId)", content, count=1)

with open(file_path, "w") as f:
    f.write(content)

print("Patch applied to TripManager.swift")
