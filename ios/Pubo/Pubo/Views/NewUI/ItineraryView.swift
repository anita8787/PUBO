import SwiftUI
import MapKit
import SwiftData

struct ItineraryView: View {
    @EnvironmentObject var tripManager: TripManager
    @Binding var isTabBarHidden: Bool
    @State private var selectedTripId: String? = nil
    @State private var selectedDayIndex: Int = 0
    var onBack: () -> Void 
    var onAddClick: () -> Void 
    
    var body: some View {
        ZStack {
            if let tripId = selectedTripId, let trip = tripManager.trips.first(where: { $0.id == tripId }) {
                // Single Trip Detail View
                TripDetailView(
                    trip: trip,
                    selectedDayIndex: $selectedDayIndex,
                    isTabBarHidden: $isTabBarHidden,
                    onBack: { selectedTripId = nil },
                    onAddClick: onAddClick
                )
            } else {
                // Trip List View
                TripListView(tripManager: tripManager, onBack: onBack, onSelectTrip: { trip in
                    selectedTripId = trip.id
                })
            }
        }
        .onChange(of: selectedTripId) { _, newValue in
            // Reset day selection when switching trips to avoid index out of bounds
            if newValue != nil {
                selectedDayIndex = 0
            }
        }
    }
}

// MARK: - Subviews

struct TripListView: View {
    @ObservedObject var tripManager: TripManager
    let onBack: () -> Void
    let onSelectTrip: (Trip) -> Void
    @State private var isSorting = false
    @State private var showNewTripModal = false
    
    var body: some View {
        ZStack {
            PuboColors.background.ignoresSafeArea()
            
            VStack(alignment: .leading) {
                // Header
                HStack {
                    Button(action: onBack) { // Navigation Back
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .retroShadow(color: .black.opacity(0.1))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Suitcase Button (New Trip)
                        Button(action: { withAnimation { showNewTripModal = true } }) {
                            Image(systemName: "briefcase")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(PuboColors.navy, lineWidth: 2)
                                )
                                .retroShadow(color: PuboColors.navy.opacity(0.1))
                        }
                        
                        // Sort Button
                        Button(action: { withAnimation { isSorting.toggle() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: isSorting ? "checkmark" : "line.3.horizontal")
                                Text(isSorting ? "完成" : "排序")
                            }
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(isSorting ? .white : PuboColors.navy)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(isSorting ? PuboColors.navy : Color.white)
                            .cornerRadius(22)
                            .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 2))
                            .retroShadow(color: PuboColors.navy.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Content
                if isSorting {
                    // Sortable List Mode
                    List {
                        ForEach(tripManager.trips) { trip in
                            TripCardView(title: trip.title, date: trip.date, spotsCount: trip.spots, color: trip.color.rawValue)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, 12)
                        }
                        .onMove { indices, newOffset in
                            tripManager.trips.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, .constant(.active)) // Enable move handles
                } else {
                    // Stacked Mode
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("我的行程")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(PuboColors.navy)
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            VStack(spacing: -45) { // Overlapping Cards — show title/date/spots
                                ForEach(Array(tripManager.trips.enumerated()), id: \.element.id) { index, trip in
                                    TripCardView(
                                        title: trip.title,
                                        date: trip.date,
                                        spotsCount: trip.spots,
                                        color: TripManager.colorForIndex(index).rawValue
                                    )
                                    .zIndex(Double(index))
                                    .onTapGesture {
                                        onSelectTrip(trip)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            tripManager.deleteTrip(id: trip.id)
                                        } label: {
                                            Label("刪除行程", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                
                // Debug / Error Info
                if let error = tripManager.errorMessage {
                    Text(verbatim: "Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .background(Color.white) // Ensure solid background to prevent overlap
            
            if showNewTripModal {
                NewTripModalView(
                    isPresented: $showNewTripModal,
                    onCreateTrip: { title, destination, start, end in
                        tripManager.addTrip(title: title, destination: destination, startDate: start, endDate: end)
                    }
                )
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
    }
}

struct TripDetailView: View {
    @EnvironmentObject var tripManager: TripManager
    let trip: Trip
    @Binding var selectedDayIndex: Int
    @Binding var isTabBarHidden: Bool
    let onBack: () -> Void
    let onAddClick: () -> Void
    
    @State private var isMapMode = false // Toggle between List and Map
    @State private var showShareModal = false
    @State private var showSettingsModal = false
    @State private var showRestoreSortAlert = false
    
    // Sort Button Label Helper
    private var sortButtonLabel: String {
        if isSorting { return "完成" }
        return tripManager.isAlreadySorted(tripId: trip.id, dayIndex: selectedDayIndex) ? "取消排序" : "一鍵排序"
    } // New State
    @State private var showCalendarModal = false
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    @State private var isAddingSpot = false
    @State private var isAddingMode = false // Toggle for Add Spot section
    @State private var showNavigationSheet = false
    @State private var navigationPart1URL: URL?
    @State private var navigationPart2URL: URL?
    @State private var isSorting = false
    @State private var showLongImagePreview = false

    @State private var isAddingSpotSheet = false // New Dashboard Sheet state

    // New Action States
    @State private var moveSpotItem: ItinerarySpot? = nil
    @State private var replaceSpotItem: ItinerarySpot? = nil
    @State private var newSpotName = ""
    var itineraryDays: [ItineraryDay] {
        tripManager.days[trip.id] ?? []
    }
    
    var currentDaySpots: [ItinerarySpot] {
        if itineraryDays.indices.contains(selectedDayIndex) {
            return itineraryDays[selectedDayIndex].spots
        }
        return []
    }
    
    var dates: [String] {
        itineraryDays.map { $0.dateString }
    }

    var days: [String] {
        itineraryDays.map { $0.dayLabel }
    }

    @State private var editingSpot: ItinerarySpot?

    var body: some View {
        ZStack {
                if isMapMode {
                TripMapPlanningView(
                    trip: trip,
                    position: $cameraPosition,
                    spots: currentDaySpots,
                    allDays: itineraryDays,
                    selectedDayIndex: selectedDayIndex,
                    onBack: { withAnimation { isMapMode = false } },
                    onDaySelected: { index in selectedDayIndex = index },
                    onEditSpot: { spot in editingSpot = spot },
                    onAddClick: { isAddingSpotSheet = true },
                    onShareClick: { withAnimation { showShareModal = true } }
                )
                    .transition(.opacity)
                    .onAppear { isTabBarHidden = true } // 確保進入地圖時隱藏
            } else {
                planningView // The List Planning View
            }
            
            // OVERLAY: Calendar Popup
            if showCalendarModal {
                CalendarView(
                    isPresented: $showCalendarModal,
                    initialStartDate: parseStartDate(),
                    initialEndDate: parseEndDate(),
                    onConfirm: { start, end in
                        tripManager.updateTripDates(tripId: trip.id, newStartDate: start, newEndDate: end)
                        withAnimation { showCalendarModal = false }
                    }
                )
                    .transition(.opacity)
            }
            
            // OVERLAY: Share Modal
            if showShareModal {
                ShareTripModal(
                    isPresented: $showShareModal,
                    onGenerateImage: {
                        withAnimation { showShareModal = false }
                        // Delay slightly to allow modal to close smoothly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showLongImagePreview = true
                        }
                    },
                    onCollaborate: {
                        withAnimation { showShareModal = false }
                        // TODO: Handle collaboration
                    }
                )
                    .zIndex(100)
            }

             // OVERLAY: Floating Dashboard (Add Spot Sheet)
             if isAddingSpotSheet {
                Color.black.opacity(0.3) // Dim background
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { isAddingSpotSheet = false }
                    }
                    .zIndex(199)
                
                VStack {
                    Spacer()
                    AddSpotSheet(onAddSpot: { newSpot, startDate, endDate in
                        // Perform Add
                        withAnimation {
                            if let start = startDate, let end = endDate {
                                tripManager.addAccommodation(to: trip.id, spot: newSpot, checkIn: start, checkOut: end)
                            } else {
                                tripManager.addSpot(to: trip.id, dayIndex: selectedDayIndex, spot: newSpot)
                            }
                            isAddingSpotSheet = false
                        }
                    })
                }
                .zIndex(200)
                .transition(.move(edge: .bottom))
            }
        }
        .fullScreenCover(isPresented: $showLongImagePreview) {
            LongImagePreviewView(trip: trip, allDays: itineraryDays)
        }
        .sheet(isPresented: $showSettingsModal) {
            TripSettingsView(tripId: trip.id)
        }
        .background(Color.white)
        .onAppear {
            isTabBarHidden = true // 進入此視圖一律隱藏 TabBar
            // 自動掃描並修復失效的座標 (0,0)
            tripManager.resolveInvalidCoordinates(in: trip.id)
        }
        .onDisappear {
            isTabBarHidden = false
        }
        .sheet(item: $editingSpot) { spot in
            EditSpotView(
                spot: spot,
                onSave: { updatedSpot in
                    tripManager.updateSpot(tripId: trip.id, dayIndex: selectedDayIndex, spot: updatedSpot)
                },
                onDelete: {
                    tripManager.deleteSpot(tripId: trip.id, dayIndex: selectedDayIndex, spotId: spot.id)
                }
            )
        }
        // Move Spot Sheet
        .sheet(item: $moveSpotItem) { spot in
            MoveSpotSheet(days: itineraryDays) { targetDayIndex in
                tripManager.moveSpotToDay(tripId: trip.id, fromDayIndex: selectedDayIndex, spotId: spot.id, toDayIndex: targetDayIndex)
                moveSpotItem = nil
            }
            .presentationDetents([.fraction(0.35)])
            .presentationBackground(.white)
        }
        // Replace Spot Sheet
        .sheet(item: $replaceSpotItem) { spot in
            ReplaceSpotSheet(currentName: spot.name) { newSpot in
                tripManager.replaceSpot(tripId: trip.id, dayIndex: selectedDayIndex, oldSpotId: spot.id, newSpot: newSpot)
                replaceSpotItem = nil
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.white)
        }
        .confirmationDialog("行程過長，請選擇導航段落", isPresented: $showNavigationSheet, titleVisibility: .visible) {
            Button("導航上半場 (起點 - 中間點)") {
                if let url = navigationPart1URL {
                    UIApplication.shared.open(url)
                }
            }
            Button("導航下半場 (中間點 - 終點)") {
                if let url = navigationPart2URL {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - Date Parsing Helpers
    private func parseStartDate() -> Date? {
        let parts = trip.date.split(separator: "-").map(String.init)
        guard let startStr = parts.first else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.date(from: startStr)
    }
    
    private func parseEndDate() -> Date? {
        let parts = trip.date.split(separator: "-").map(String.init)
        guard parts.count > 1, let start = parseStartDate() else {
            return parseStartDate()
        }
        
        let endStr = parts[1] // "MM/dd"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)
        if let endCandidate = formatter.date(from: "\(startYear)/\(endStr)") {
            if endCandidate < start {
                 return calendar.date(byAdding: .year, value: 1, to: endCandidate)
            }
            return endCandidate
        }
        return nil
    }

    private var headerArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Bar: Back + Share/Settings
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .retroShadow(color: .black.opacity(0.15), offset: 2.5)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: handleNavigation) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .retroShadow(color: .black.opacity(0.15), offset: 2.5)
                    }
                    Button(action: { withAnimation { showShareModal = true } }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .retroShadow(color: .black.opacity(0.15), offset: 2.5)
                    }
                    
                    Button(action: { showSettingsModal = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .retroShadow(color: .black.opacity(0.15), offset: 2.5)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Trip Title & Date
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: trip.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(PuboColors.navy)
                    .tracking(-1)

                Button(action: { showCalendarModal = true }) {
                    HStack(spacing: 6) {
                        let currentTrip = tripManager.trips.first(where: { $0.id == trip.id }) ?? trip
                        Text(verbatim: currentTrip.date.isEmpty ? "請選擇日期" : currentTrip.date)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PuboColors.navy.opacity(0.6))
                            .tracking(0.5)
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(PuboColors.navy.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Day Selector Capsules
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<days.count, id: \.self) { index in
                        ZStack {
                            if selectedDayIndex == index {
                                Capsule()
                                    .fill(Color(hex: "023B7E"))
                                    .frame(width: 38, height: 52)
                                    .offset(x: 2.5, y: 2.5)
                            }
                            
                            VStack(spacing: 2) {
                                Text("DAY")
                                    .font(.system(size: 7, weight: .black))
                                Text(verbatim: "\((dates.indices.contains(index) ? dates[index].split(separator: "/").last.map(String.init) : "") ?? "")")
                                    .font(.system(size: 14, weight: .black))
                            }
                            .frame(width: 38, height: 52)
                            .background(selectedDayIndex == index ? Color.white : Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedDayIndex == index ? PuboColors.navy : Color.clear, lineWidth: 2)
                            )
                            .foregroundColor(selectedDayIndex == index ? PuboColors.navy : PuboColors.navy.opacity(0.3))
                        }
                        .frame(width: 44, height: 60)
                        .onTapGesture {
                            selectedDayIndex = index
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(PuboColors.yellow)
    }

    private var itineraryContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            
            ScrollView {
                 VStack(alignment: .leading, spacing: 0) {
                     // Day Header
                     if dates.indices.contains(selectedDayIndex) {
                         HStack(alignment: .top) {
                             VStack(alignment: .leading, spacing: 4) {
                                 Text(verbatim: "Day \(selectedDayIndex + 1)")
                                     .font(.system(size: 10, weight: .black))
                                     .foregroundColor(.gray)
                                     .tracking(1.5)
                                     .textCase(.uppercase)
                                     .padding(.horizontal, 12)
                                     .padding(.vertical, 4)
                                     .overlay(
                                         Capsule()
                                             .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                     )
                                 
                                 HStack(spacing: 8) {
                                     Text(verbatim: dates[selectedDayIndex])
                                         .font(.system(size: 24, weight: .black))
                                     if itineraryDays.indices.contains(selectedDayIndex) {
                                         Text(verbatim: itineraryDays[selectedDayIndex].weekday ?? "")
                                             .font(.system(size: 24, weight: .black))
                                     }
                                 }
                                 .foregroundColor(PuboColors.navy)
                             }
                             Spacer()
                             
                             // Right: Sort Button (Red Pill + Bolt)
                             Button(action: { 
                                 if isSorting {
                                     withAnimation { isSorting = false }
                                 } else if tripManager.isAlreadySorted(tripId: trip.id, dayIndex: selectedDayIndex) {
                                     showRestoreSortAlert = true
                                 } else {
                                     Task {
                                         await tripManager.smartSort(tripId: trip.id, dayIndex: selectedDayIndex)
                                     }
                                 }
                             }) {
                                 HStack(spacing: 6) {
                                     let isAlreadySorted = tripManager.isAlreadySorted(tripId: trip.id, dayIndex: selectedDayIndex)
                                     Image(systemName: isSorting ? "checkmark" : (isAlreadySorted ? "arrow.uturn.backward" : "bolt.fill"))
                                         .font(.system(size: 14, weight: .black))
                                     Text(sortButtonLabel)
                                         .font(.system(size: 12, weight: .black))
                                 }
                                 .foregroundColor(.white)
                                 .padding(.horizontal, 16)
                                 .padding(.vertical, 8)
                                 .background(isSorting ? PuboColors.navy : (tripManager.isAlreadySorted(tripId: trip.id, dayIndex: selectedDayIndex) ? Color.gray : PuboColors.red))
                                 .clipShape(Capsule())
                                .retroShadow(color: .black, offset: 2.5)
                             }
                         }
                         .padding(.horizontal, 24)
                         .padding(.top, 24)
                         .padding(.bottom, 24)
                     }

                      // Timeline Content
                      if isSorting {
                          sortingList
                      } else {
                          VStack(spacing: 24) { // Increased spacing between spots
                                let accommodations = currentDaySpots.filter { $0.category == .accommodation }
                              let regularSpots = currentDaySpots.filter { $0.category != .accommodation }
                              
                              // 1. Pinned Accommodation (If exists)
                              if let hotel = accommodations.first {
                                  PinnedAccommodationHeader(spot: hotel)
                                      .padding(.horizontal, 24)
                                  
                                  // Show transport from hotel to first spot
                                  if let firstSpot = regularSpots.first {
                                      AccommodationToSpotGap(from: hotel, to: firstSpot)
                                          .padding(.horizontal, 24)
                                  }
                              }
                              
                              // 2. Regular Spots
                              ForEach(Array(regularSpots.enumerated()), id: \.element.id) { index, spot in
                                  TimelineSpotView(
                                      spot: spot,
                                      isLast: index == regularSpots.count - 1,
                                      index: index,
                                      onEdit: {
                                          editingSpot = spot
                                      },
                                      onMove: {
                                          moveSpotItem = spot
                                      },
                                      onReplace: {
                                          replaceSpotItem = spot
                                      },
                                      onDelete: {
                                          tripManager.deleteSpot(tripId: trip.id, dayIndex: selectedDayIndex, spotId: spot.id)
                                      },
                                      onTransportChange: { newType in
                                          tripManager.updateSpotTransport(tripId: trip.id, dayIndex: selectedDayIndex, spotId: spot.id, transportType: newType)
                                      },
                                      dayDate: itineraryDays[selectedDayIndex].date
                                  )
                              }
                              
                               // Add Spot Button
                              addSpotButton
                          }
                          .padding(.bottom, 100)
                          .id("trip-\(trip.id)-day-\(selectedDayIndex)-\(currentDaySpots.count)-\(currentDaySpots.map { "\($0.travelMode?.rawValue ?? "")-\($0.travelTime ?? "")-\($0.travelDistance ?? "")" }.joined())") // Force re-render on any relevant change
                      }
                }
            }
        }
    }

    private var sortingList: some View {
        List {
            ForEach(currentDaySpots) { spot in
                HStack {
                    Text(verbatim: spot.time).font(.caption).frame(width: 40, alignment: .leading)
                    Text(verbatim: spot.name).font(.headline)
                    Spacer()
                    Image(systemName: "line.3.horizontal").foregroundColor(.gray)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
            }
            .onMove { indices, newOffset in
                tripManager.moveSpot(tripId: trip.id, dayIndex: selectedDayIndex, from: indices, to: newOffset)
            }
        }
        .listStyle(.plain)
        .frame(minHeight: 400)
        .environment(\.editMode, .constant(.active))
    }

    private var addSpotButton: some View {
        Button(action: { isAddingSpotSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                
                Text("新增景點")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(Color.gray.opacity(0.4))
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    var planningView: some View {
        ZStack {
            VStack(spacing: 0) {
                headerArea
                
                // === CONTENT AREA (Beige with Navy Top Border + Rounded Top) ===
                ZStack {
                    Color(hex: "FFF9E1").ignoresSafeArea() // Background matches beige card
                    itineraryContent
                }
                .cornerRadius(40, corners: [.topLeft, .topRight])
                .alert("取消排序", isPresented: $showRestoreSortAlert) {
                    Button("取消", role: .cancel) { }
                    Button("確定還原", role: .destructive) {
                        Task {
                            await tripManager.restoreOriginalOrder(tripId: trip.id, dayIndex: selectedDayIndex)
                        }
                    }
                } message: {
                    Text("是否要取消目前的排序，恢復成您原本安排的順序？")
                }
            }
            .background(PuboColors.yellow)

            
            // === FLOATING MAP/LIST TOGGLE ===
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        // Map Button
                        Button(action: { withAnimation { isMapMode = true } }) {
                            Image(systemName: "map")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isMapMode ? PuboColors.navy : Color(hex: "FDF1CA"))
                                .frame(width: 36, height: 38)
                                .background(isMapMode ? Color.white : Color.clear)
                                .clipShape(Circle())
                                .shadow(color: isMapMode ? .black.opacity(0.1) : .clear, radius: 4)
                        }
                        // List Button
                        Button(action: { withAnimation { isMapMode = false } }) {
                            Image(systemName: "list.number")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isMapMode ? PuboColors.navy : .white)
                                .frame(width: 36, height: 38)
                                .background(isMapMode ? Color.clear : PuboColors.navy)
                                .clipShape(Circle())
                                .shadow(color: isMapMode ? .clear : .black.opacity(0.1), radius: 4)
                        }
                    }
                    .padding(4)
                    .frame(width: 44, height: 92)
                    .background(Color(hex: "9BB8D9"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 80)
            } // End VStack (Floating)
        } // End ZStack (planningView)
    }
    // MARK: - Navigation Logic
    func handleNavigation() {
        // 1. Get current spots
        let spots = getAllSpots()
        guard spots.count >= 2 else { return }
        
        // 2. Determine Mode
        let mode = getDominantTransportMode(for: spots)
        
        // 3. Split Check (Google Maps limit ~10 waypoints + origin + destination)
        if spots.count > 10 {
            let mid = spots.count / 2
            let part1 = Array(spots[0...mid])
            // Start Part 2 from the last point of Part 1 to ensure continuity
            let part2 = Array(spots[mid...])
            
            navigationPart1URL = generateGoogleMapsUrl(spots: part1, mode: mode)
            navigationPart2URL = generateGoogleMapsUrl(spots: part2, mode: mode)
            showNavigationSheet = true
        } else {
            if let url = generateGoogleMapsUrl(spots: spots, mode: mode) {
                print("🚀 Launching Google Maps: \(url)")
                UIApplication.shared.open(url)
            }
        }
    }
    
    func generateGoogleMapsUrl(spots: [ItinerarySpot], mode: TransportType) -> URL? {
        guard spots.count >= 2 else { return nil }
        
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        components.queryItems = [URLQueryItem(name: "api", value: "1")]
        
        // Origin
        if let origin = spots.first {
            components.queryItems?.append(URLQueryItem(name: "origin", value: formatLocation(origin)))
        }
        
        // Destination
        if let dest = spots.last {
            components.queryItems?.append(URLQueryItem(name: "destination", value: formatLocation(dest)))
        }
        
        // Waypoints
        if spots.count > 2 {
            let waypoints = spots[1..<spots.count-1].map { formatLocation($0) }.joined(separator: "|")
            components.queryItems?.append(URLQueryItem(name: "waypoints", value: waypoints))
        }
        
        // Mode
        let googleMode: String
        switch mode {
        case .car: googleMode = "driving"
        case .walk: googleMode = "walking"
        case .train, .bus: googleMode = "transit"
        }
        components.queryItems?.append(URLQueryItem(name: "travelmode", value: googleMode))
        
        return components.url
    }
    
    func formatLocation(_ spot: ItinerarySpot) -> String {
        // Priority: Coordinate > Address > Name
        if let lat = spot.latitude, let lon = spot.longitude {
            // Only use coordinates if they are valid (not 0.0, 0.0)
            if lat != 0.0 && lon != 0.0 {
                return "\(lat),\(lon)"
            }
        }
        // Fallback to name (URL encoded automatically by URLComponents)
        return spot.name
    }
    
    func getDominantTransportMode(for spots: [ItinerarySpot]) -> TransportType {
        var counts: [TransportType: Int] = [:]
        for spot in spots {
            let mode = spot.travelMode ?? .car
            counts[mode, default: 0] += 1
        }
        // Default to car if empty or equal
        return counts.max(by: { $0.value < $1.value })?.key ?? .car
    }
    
    func getAllSpots() -> [ItinerarySpot] {
        // Flatten days into spots
        return itineraryDays.flatMap { $0.spots }
    }
}


// MARK: - Reconstructed Subviews

// MARK: - Reconstructed Subviews

struct TimelineSpotView: View {
    let spot: ItinerarySpot
    let isLast: Bool
    let index: Int
    var onEdit: () -> Void
    var onMove: () -> Void
    var onReplace: () -> Void
    var onDelete: () -> Void
    var onTransportChange: ((TransportType) -> Void)?
    var dayDate: Date? // Passed from parent
    
    @State private var showTransportPicker = false
    @State private var offset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. MAIN CARD (Full Width)
            // 1. MAIN CARD (Full Width) with Swipe to Delete
            ZStack(alignment: .trailing) {
                // Background Delete Button
                if offset < 0 {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(PuboColors.red)
                            .padding(.trailing, 24)
                    }
                    .transition(.opacity)
                }
                
                // Card Content
                SpotCardView(
                    spot: spot,
                    index: index,
                    onEdit: onEdit,
                    onMove: onMove,
                    onReplace: onReplace,
                    onDelete: onDelete,
                    dayDate: dayDate
                )
                .padding(.horizontal, 24)
                // .background(Color.white) // Removed to prevent white corners
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            // Only allow sliding left
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { _ in
                            if offset < -50 {
                                withAnimation(.spring()) {
                                    offset = -60 // Snap open
                                }
                            } else {
                                withAnimation(.spring()) {
                                    offset = 0 // Snap close
                                }
                            }
                        }
                )
                .onTapGesture {
                    if offset != 0 {
                        withAnimation { offset = 0 }
                    }
                }
                .zIndex(1)
            }
            .alert("確定要刪除此景點嗎？", isPresented: $showDeleteConfirmation) {
                Button("刪除", role: .destructive) {
                    onDelete()
                }
                Button("取消", role: .cancel) {
                    withAnimation {
                        offset = 0
                    }
                }
            }
            
            Spacer().frame(height: 12) // Gap between card and memo
            // 2. GAP (Line + Memo/Transport)
            // Only show if there's content OR it's not the last one (to show line connecting to next)
            if !isLast {
                HStack(alignment: .top, spacing: 0) {
                    
                    // Left Spacer to align line nicely - Image is 115 wide, centered in 335 block.
                    // Card is horizontally centered. Image center is at (ScreenWidth - 335)/2 + 57.5.
                    // But in this view it's simpler to just align it under the image.
                    // Image width 115, offset -20 overlap with info box.
                    // Total width 335. If we use horizontal padding 24, we need to match it.
                    Spacer().frame(width: 82) 
                    
                    // Dotted Line
                    VStack {
                        Line()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                            .foregroundColor(Color.gray.opacity(0.3))
                            .frame(width: 2)
                    }
                    
                    // Gap content (Memo + Transport) aligned to line
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Memo
                        if let notes = spot.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                // Time Range Calculation (Moved to top of Memo)
                                let endTime = calculateEndTime(start: spot.time, duration: spot.duration)
                                Text(verbatim: "\(spot.time) - \(endTime)")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(Color(hex: "023B7E")) // Deep Blue text for time
                                    .tracking(1)
                                
                                Text(verbatim: notes.joined(separator: "、"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray) // Gray text for content
                                    .lineSpacing(4)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(hex: "FFC649").opacity(0.23)) // Light Yellow Background
                            .overlay(
                                HStack {
                                    Rectangle()
                                        .fill(Color(hex: "FFC649")) // Dark Yellow Line
                                        .frame(width: 4)
                                    Spacer()
                                }
                            )
                            .cornerRadius(4)
                            .padding(.leading, 12)
                            .padding(.top, 4)
                        }
                        
                        // Transport (tappable to change mode)
                        VStack(spacing: 8) {
                            Button(action: {
                                print("Transport button tapped for spot: \(spot.name)")
                                withAnimation(.spring(response: 0.3)) {
                                    showTransportPicker.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    let info = spot.travelToNext
                                    let transportType = info?.type ?? .train
                                    let transportTime = info?.time ?? "--"
                                    let transportDistance = info?.distance ?? "--"
                                    
                                    Image(systemName: transportIcon(for: transportType))
                                        .font(.system(size: 14))
                                        .foregroundColor(info != nil ? PuboColors.navy : .gray.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 3)
                                    
                                    Text("\(transportTime) • \(transportDistance)")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(info != nil ? .black.opacity(0.7) : .gray.opacity(0.4))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle()) // Essential for hit area
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showTransportPicker {
                                TransportPicker(currentType: spot.travelToNext?.type ?? .train) { newType in
                                    onTransportChange?(newType)
                                    withAnimation { showTransportPicker = false }
                                }
                                .padding(.leading, 32)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(minHeight: 40) // Minimum height for line
            }
        }
    }
    
    // Helpers
    func transportIcon(for type: TransportType) -> String {
        switch type {
        case .train: return "tram.fill"
        case .walk: return "figure.walk"
        case .car: return "car.fill"
        case .bus: return "bus.fill"
        }
    }
    
    func calculateEndTime(start: String, duration: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        var minutes = 60
        if duration.contains("小時") {
             minutes = (Int(duration.replacingOccurrences(of: "小時", with: "")) ?? 1) * 60
        } else if duration.contains("分鐘") {
             minutes = Int(duration.replacingOccurrences(of: "分鐘", with: "")) ?? 60
        } else if let val = Int(duration) {
             minutes = val
        }
        
        if let date = formatter.date(from: start) {
            let endDate = Calendar.current.date(byAdding: .minute, value: minutes, to: date) ?? date
            return formatter.string(from: endDate)
        }
        return start
    }
}

// Reconstructed SpotCardView
struct SpotCardView: View {
    let spot: ItinerarySpot
    let index: Int
    var onEdit: () -> Void
    var onMove: () -> Void
    var onReplace: () -> Void
    var onDelete: () -> Void
    var dayDate: Date? // Passed from parent
    var fallbackImageUrl: String? = nil // From Trip.coverImageUrl
    
    // Computed Business Status
    var businessStatus: BusinessStatusResult? {
        spot.businessStatusText(for: dayDate)
    }
    
    @State private var otmImageUrl: String? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer() // Center push
            
            HStack(alignment: .center, spacing: -20) { // Overlap
                // Left: Image Area with Index Badge
                ZStack(alignment: .topLeading) {
                    // Image Logic: Backend > OTM > Placeholder
                    if let imageUrl = spot.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                        // 1. Backend Image
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            defaultImagePlaceholder
                        }
                        .frame(width: 115, height: 115)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let fallback = fallbackImageUrl, let url = URL(string: fallback) {
                         // 2. Fallback (Trip Image)
                         AsyncImage(url: url) { image in
                             image.resizable().aspectRatio(contentMode: .fill)
                         } placeholder: {
                             defaultImagePlaceholder
                         }
                         .frame(width: 115, height: 115)
                         .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let otmString = otmImageUrl, let url = URL(string: otmString) {
                         // 2. OTM Image
                         AsyncImage(url: url) { image in
                             image.resizable().aspectRatio(contentMode: .fill)
                         } placeholder: {
                             defaultImagePlaceholder
                         }
                         .frame(width: 115, height: 115)
                         .clipShape(RoundedRectangle(cornerRadius: 12))
                         .transition(.opacity)
                    } else {
                        // 3. Placeholder
                        defaultImagePlaceholder
                            .frame(width: 115, height: 115)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Index Badge
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PuboColors.red)
                        .cornerRadius(8, corners: [.topLeft, .bottomRight])
                }
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .zIndex(1)
                
                // Right: Info Box
                ZStack {
                    // 1. Centered Info Section
                    VStack(alignment: .leading, spacing: 5) {
                        // Status & Opening Time
                        Text(spot.simplifiedStatusText)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(PuboColors.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(PuboColors.red.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(PuboColors.red, lineWidth: 1))
                        
                        // Name
                        Text(verbatim: spot.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "023B7E"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Duration
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("停留 \(spot.duration)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                    .padding(.trailing, 45) // Room for buttons
                    
                    // 2. Corner Buttons Overlay
                    VStack {
                        // Top Right: Pencil
                        HStack {
                            Spacer()
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .frame(width: 28, height: 28)
                                    .background(Color.white)
                                    .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                            }
                        }
                        
                        Spacer()
                        
                        // Bottom Right: Move & Replace
                        HStack {
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: onMove) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(PuboColors.navy)
                                        .frame(width: 28, height: 28)
                                        .background(Color.white)
                                        .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                                }
                                
                                Button(action: onReplace) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(PuboColors.navy)
                                        .frame(width: 28, height: 28)
                                        .background(Color.white)
                                        .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                                }
                            }
                        }
                    }
                    .padding(10) // Equal spacing from all corners
                }
                .frame(width: 240, height: 115) // Fixed height to match image
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.8), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            
            Spacer() // Center push
        }
        .task {
            // Fetch OTM photo if backend photo is missing
            print("SpotCardView: Task started for \(spot.name)")
            print("SpotCardView: ImageKey='\(spot.imageUrl ?? "nil")'")
            
            if (spot.imageUrl == nil || spot.imageUrl?.isEmpty == true),
               let lat = spot.latitude, let lon = spot.longitude,
               lat != 0.0 || lon != 0.0 {
                print("SpotCardView: Coordinates valid: \(lat), \(lon)")
                if otmImageUrl == nil {
                    print("SpotCardView: Fetching OTM...")
                    if let info = try? await OTMService.shared.fetchPlaceInfo(for: lat, longitude: lon) {
                        otmImageUrl = info.imageUrl
                        print("SpotCardView: OTM Result for \(spot.name): Img=\(info.imageUrl ?? "nil")")
                    }
                }
            } else {
                print("SpotCardView: Skipping OTM. HasImage=\(spot.imageUrl != nil), LatLon=\(spot.latitude != nil)")
            }
        }
    }
    
    var defaultImagePlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.1)
            Image(systemName: iconForCategory(spot.category ?? .spot))
                .font(.system(size: 30))
                .foregroundColor(.gray)
        }
    }
    
    func iconForCategory(_ category: SpotCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .shopping: return "bag.fill"
        case .attraction: return "camera.fill"
        case .spot: return "mappin.circle.fill"
        case .accommodation: return "bed.double.fill"
        case .transport: return "tram.fill"
        }
    }
}

// Reconstructed TransportPicker
struct TransportPicker: View {
    let currentType: TransportType
    let onSelect: (TransportType) -> Void
    
    let types: [TransportType] = [.train, .bus, .car, .walk]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(types, id: \.self) { type in
                Button(action: { onSelect(type) }) {
                    ZStack {
                        Circle()
                            .fill(currentType == type ? PuboColors.navy : Color.white)
                            .frame(width: 32, height: 32)
                            .shadow(radius: 2)
                        
                        Image(systemName: iconName(for: type))
                            .font(.system(size: 14))
                            .foregroundColor(currentType == type ? .white : .gray)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.9))
        .cornerRadius(20)
    }
    
    func iconName(for type: TransportType) -> String {
        switch type {
        case .train: return "tram.fill"
        case .walk: return "figure.walk"
        case .car: return "car.fill"
        case .bus: return "bus.fill"
        }
    }
}

// Reconstructed MoveSpotSheet
struct MoveSpotSheet: View {
    let days: [ItineraryDay]
    var onMoveCompete: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("移動行程到...")
                .font(.headline)
                .padding()
            
            List {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Button(action: {
                        onMoveCompete(index)
                        dismiss()
                    }) {
                        HStack {
                            Text("Day \(index + 1)")
                            Spacer()
                            Text(day.dateString)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
    }
}

// Reconstructed ReplaceSpotSheet — Search + Collection
struct ReplaceSpotSheet: View {
    let currentName: String
    var onReplace: (ItinerarySpot) -> Void
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var searchService = SearchService(apiKey: Secrets.googleAPIKey)
    @Query(sort: \SDContent.createdAt, order: .reverse) private var sdContents: [SDContent]
    
    @State private var searchText = ""
    @State private var showCollection = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("替換地點")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Search Bar with Collection Icon
            HStack(spacing: 10) {
                // Collection icon button
                Button(action: {
                    withAnimation { showCollection.toggle() }
                    if showCollection { isSearchFocused = false }
                }) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(showCollection ? PuboColors.yellow : .gray)
                        .frame(width: 32, height: 32)
                        .background(showCollection ? PuboColors.navy : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    TextField("搜尋新地點", text: $searchText)
                        .font(.system(size: 15))
                        .focused($isSearchFocused)
                        .onChange(of: searchText) {
                            if !searchText.isEmpty { showCollection = false }
                            searchService.updateQuery(searchText)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchService.updateQuery("")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(10)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Divider().padding(.horizontal, 20)
            
            // Content: Search Results or Collection
            if showCollection {
                collectionListView
            } else if !searchService.suggestions.isEmpty {
                searchResultsView
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("輸入地點名稱搜尋，或點擊 ⭐ 從收藏庫選取")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            // Auto-focus search bar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(searchService.suggestions) { result in
                    Button(action: { selectSearchResult(result) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                Text(result.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(PuboColors.navy)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    Divider().padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Collection List
    private var collectionListView: some View {
        let allPlaces = sdContents.flatMap { $0.places }
        
        return Group {
            if allPlaces.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "star.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("收藏庫沒有地點")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(allPlaces, id: \.id) { place in
                            Button(action: { selectCollectionPlace(place) }) {
                                HStack(spacing: 12) {
                                    let imgUrl = place.contents.first?.previewThumbnailUrl
                                    
                                    if let urlStr = imgUrl, let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.1)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "mappin.circle.fill")
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(PuboColors.navy)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                        if let addr = place.address, !addr.isEmpty {
                                            Text(addr)
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(PuboColors.navy)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func selectSearchResult(_ result: SearchResult) {
        Task {
            do {
                let details = try await searchService.getDetails(for: result)
                await MainActor.run {
                    var spot = ItinerarySpot.empty()
                    spot.name = result.title
                    spot.latitude = details.lat
                    spot.longitude = details.lng
                    spot.googlePlaceId = result.source == .google ? result.placeId : nil
                    
                    spot.place = PlaceInfo(
                        name: result.title,
                        placeId: result.placeId,
                        address: details.address,
                        latitude: details.lat,
                        longitude: details.lng,
                        category: nil,
                        rating: nil,
                        userRatingsTotal: nil,
                        openingHours: nil
                    )
                    
                    onReplace(spot)
                    dismiss()
                }
            } catch {
                // Fallback: just use name
                await MainActor.run {
                    var spot = ItinerarySpot.empty()
                    spot.name = result.title
                    onReplace(spot)
                    dismiss()
                }
            }
        }
    }
    
    private func selectCollectionPlace(_ place: SDPlace) {
        var spot = ItinerarySpot.empty()
        spot.name = place.name
        spot.latitude = place.latitude
        spot.longitude = place.longitude
        spot.googlePlaceId = place.id
        
        // Map category
        if let cat = place.category?.lowercased() {
            if cat.contains("food") || cat.contains("restaurant") { spot.category = .food }
            else if cat.contains("lodging") || cat.contains("hotel") { spot.category = .accommodation }
            else if cat.contains("shopping") || cat.contains("store") { spot.category = .shopping }
            else { spot.category = .spot }
        }
        
        // Build PlaceInfo
        var openHours: OpenHours? = nil
        if let jsonStr = place.openingHours,
           let data = jsonStr.data(using: .utf8) {
            openHours = try? JSONDecoder().decode(OpenHours.self, from: data)
        }
        
        spot.place = PlaceInfo(
            name: place.name,
            placeId: place.id,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            category: place.category,
            rating: place.rating,
            userRatingsTotal: place.userRatingCount,
            openingHours: openHours
        )
        
        onReplace(spot)
        dismiss()
    }
}

// Line Shape
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        return path
    }
}

// Custom Range Calendar View ("Restored" to match screenshot)
struct CustomRangeCalendarView: View {
    @Binding var isPresented: Bool
    var initialStartDate: Date?
    var initialEndDate: Date?
    var onConfirm: (Date, Date) -> Void
    
    @State private var currentMonth: Date = Date()
    @State private var selectedStartDate: Date?
    @State private var selectedEndDate: Date?
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["日", "一", "二", "三", "四", "五", "六"] // Traditional Chinese week days
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                // 1. Yellow Header with Navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.3)) // Subtle circle bg
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(verbatim: "\(yearString(from: currentMonth))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PuboColors.navy.opacity(0.7))
                        Text(verbatim: "\(monthString(from: currentMonth))月")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(PuboColors.navy)
                    }
                    
                    Spacer()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(PuboColors.yellow)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                
                // 2. Calendar Body (White)
                VStack(spacing: 20) {
                    
                    // Days of Week
                    HStack {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(PuboColors.navy.opacity(0.4))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Days Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    isSelected: isSelected(date),
                                    isInRange: isInRange(date),
                                    isToday: calendar.isDateInToday(date)
                                )
                                .onTapGesture {
                                    handleDateSelection(date)
                                }
                            } else {
                                Text("")
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // Footer Buttons
                    HStack(spacing: 24) {
                        Button("清除") {
                            selectedStartDate = nil
                            selectedEndDate = nil
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PuboColors.navy.opacity(0.6))
                        
                        Button(action: {
                            if let start = selectedStartDate, let end = selectedEndDate {
                                onConfirm(start, end)
                            } else if let start = selectedStartDate {
                                onConfirm(start, start) // Single day fallback? Or prevent?
                            }
                            isPresented = false
                        }) {
                            Text("確認日期")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(PuboColors.navy)
                                .cornerRadius(28) // Pill shape
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(Color.white)
                .cornerRadius(24, corners: [.bottomLeft, .bottomRight])
            }
            .padding(24)
        }
        .onAppear {
            if let start = initialStartDate {
                selectedStartDate = start
                currentMonth = start
            }
            if let end = initialEndDate { selectedEndDate = end }
        }
    }
    
    // Logic Helpers
    func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    func yearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        return formatter.string(from: date)
    }
    
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1 // 0-indexed (Sun=0)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    func isSelected(_ date: Date) -> Bool {
        if let start = selectedStartDate, calendar.isDate(date, inSameDayAs: start) { return true }
        if let end = selectedEndDate, calendar.isDate(date, inSameDayAs: end) { return true }
        return false
    }
    
    func isInRange(_ date: Date) -> Bool {
        guard let start = selectedStartDate, let end = selectedEndDate else { return false }
        return date > start && date < end
    }
    
    func handleDateSelection(_ date: Date) {
        if selectedStartDate == nil {
            selectedStartDate = date // First tap
        } else if selectedEndDate == nil {
            if date < selectedStartDate! {
                selectedEndDate = selectedStartDate // Swap
                selectedStartDate = date
            } else {
                selectedEndDate = date
            }
        } else {
            // Reset and start new selection
            selectedStartDate = date
            selectedEndDate = nil
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isInRange: Bool
    let isToday: Bool
    
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    var body: some View {
        ZStack {
            if isInRange {
                Rectangle()
                    .fill(PuboColors.navy.opacity(0.1))
                    .frame(height: 36)
            }
            
            if isSelected {
                Circle()
                    .fill(PuboColors.navy)
                    .frame(width: 36, height: 36)
                    .shadow(color: PuboColors.navy.opacity(0.3), radius: 4, y: 2)
            }
            
            Text(dayFormatter.string(from: date))
                .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isToday ? PuboColors.red : PuboColors.navy))
            
            if isToday && !isSelected {
                 Circle()
                     .fill(PuboColors.red)
                     .frame(width: 4, height: 4)
                     .offset(y: 12)
            }
        }
        .frame(width: 36, height: 36)
    }
}

// Re-map CalendarView usage to CustomRangeCalendarView in main view
// (Requires ensuring the `CalendarView` struct name matches what's used above, or rename above usage)
// I replaced `struct CalendarView` directly below, but the logic in `ItineraryView` calls `CalendarView`.
// So I will alias it or rename this struct to `CalendarView`.

typealias CalendarView = CustomRangeCalendarView

// MARK: - Accommodation Start Point UI Components

struct PinnedAccommodationHeader: View {
    let spot: ItinerarySpot
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bed.double.fill")
                .foregroundColor(PuboColors.navy)
                .font(.system(size: 18))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("當日住宿")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(1)
                Text(spot.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PuboColors.navy)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct AccommodationToSpotGap: View {
    let from: ItinerarySpot
    let to: ItinerarySpot
    @EnvironmentObject var tripManager: TripManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: 22 + 24) // Align with the center of the bed circle - account for overall horizontal padding 24
            
            VStack {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .foregroundColor(Color.gray.opacity(0.3))
                    .frame(width: 2, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(from.travelTime ?? "計算中...")
                        .font(.system(size: 11, weight: .bold))
                    
                    if let dist = from.travelDistance {
                        Text("•")
                        Text(dist)
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(.gray)
                .padding(.leading, 12)
                .offset(y: 10)
            }
            
            Spacer()
        }
    }
}
