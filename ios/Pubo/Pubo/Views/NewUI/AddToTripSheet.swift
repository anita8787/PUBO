import SwiftUI
import CoreLocation

struct AddToTripSheet: View {
    let place: MapPlace
    var onClose: () -> Void
    
    @EnvironmentObject var tripManager: TripManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTripId: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if tripManager.isLoading {
                    ProgressView("Loading Trips...")
                } else if tripManager.trips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No trips available.\nCreate a new trip first.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        if selectedTripId == nil {
                            Section(header: Text("Select a Trip")) {
                                ForEach(tripManager.trips) { trip in
                                    Button(action: {
                                        withAnimation {
                                            selectedTripId = trip.id
                                        }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(trip.title)
                                                    .font(.headline)
                                                if let dateStr = trip.dateString {
                                                    Text(dateStr)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        } else {
                            // Show Days for selected trip
                            if let trip = tripManager.trips.first(where: { $0.id == selectedTripId }),
                               let days = tripManager.days[trip.id] {
                                
                                Button(action: {
                                    withAnimation { selectedTripId = nil }
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("Back to Trips")
                                    }
                                }
                                .listRowSeparator(.hidden)
                                
                                Section(header: Text("Select a Day for '\(trip.title)'")) {
                                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                                        Button(action: {
                                            addPlaceToDay(tripId: trip.id, dayIndex: index)
                                        }) {
                                            HStack {
                                                Text(day.dayLabel)
                                                    .font(.headline)
                                                    .frame(width: 60, alignment: .leading)
                                                
                                                VStack(alignment: .leading) {
                                                    if !day.dateString.isEmpty {
                                                        Text(day.dateString)
                                                            .font(.subheadline)
                                                    }
                                                    Text("\(day.spots.count) spots")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(PuboColors.navy)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Add to Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
        .onAppear {
            if tripManager.trips.isEmpty {
                tripManager.refreshTrips()
            }
        }
    }
    
    private func addPlaceToDay(tripId: String, dayIndex: Int) {
        // Convert MapPlace to ItinerarySpot
        let newSpot = ItinerarySpot(
            id: UUID().uuidString, // Temporary ID, backend generates real one
            dayId: 0, // Ignored by create API usually, or we can look it up
            name: place.name,
            category: mapCategoryToSpotCategory(place.category),
            startTime: "10:00", // Default
            stayDuration: "60分鐘",
            notes: ["Added from Map"],
            imageUrl: place.image,
            placeId: nil, // We don't have place_id from map mock data
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            sortOrder: 0,
            travelMode: .train
        )
        
        tripManager.addSpot(to: tripId, dayIndex: dayIndex, spot: newSpot)
        onClose()
    }
    
    private func mapCategoryToSpotCategory(_ cat: String) -> SpotCategory {
        switch cat {
        case "美食": return .food
        case "景點": return .spot
        default: return .spot
        }
    }
}

// Helper extension for Trip date string if not present
extension Trip {
    var dateString: String? {
        // Computed property "date" exists in Model
        return date.isEmpty ? nil : date
    }
}
