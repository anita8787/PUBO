import SwiftUI
import SwiftData

struct AddSpotSheet: View {
    @Environment(\.dismiss) var dismiss
    
    // Callback to Parent
    var onAddSpot: (ItinerarySpot) -> Void
    
    @StateObject private var searchService = SearchService(apiKey: "AIzaSyCz-lkSBaT0_YuTSa-uBWSDWB_4E3Plqec")
    
    // UI State
    @State private var searchText = ""
    @State private var activeSheet: AddSpotMode? = nil
    
    // Custom Mode State
    @State private var isCustomMode = false
    
    // Real Data for Collection
    @Query(sort: \SDContent.createdAt, order: .reverse) private var sdContents: [SDContent]
    
    enum AddSpotMode: String, Identifiable {
        case smartImport
        case collection
        case accommodation
        
        var id: String { rawValue }
    }
    
    var searchPlaceholder: String {
        return isCustomMode ? "自定義行程" : "搜尋地點"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Dashboard Row of 4 Buttons
            if !isCustomMode {
                HStack(spacing: 12) {
                    // ... buttons ...
                    FunctionButton(
                        icon: "sparkles",
                        title: "智能導入",
                        color: PuboColors.navy,
                        isBlue: true
                    ) {
                        activeSheet = .smartImport
                    }
                    
                    FunctionButton(
                        icon: "bed.double.fill",
                        title: "住宿",
                        color: PuboColors.red
                    ) {
                        activeSheet = .accommodation
                    }
                    
                    FunctionButton(
                        icon: "star.fill",
                        title: "收藏庫",
                        color: PuboColors.red
                    ) {
                        activeSheet = .collection
                    }
                    
                    FunctionButton(
                        icon: "doc.text.fill",
                        title: "自定義",
                        color: PuboColors.red
                    ) {
                        withAnimation {
                            isCustomMode = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            
            // 2. Search Bar + Suggestions
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    
                    TextField(searchPlaceholder, text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .submitLabel(.search)
                        .onChange(of: searchText) {
                            searchService.updateQuery(searchText)
                        }
                        .onSubmit {
                            handleAddFromSearch(category: .spot)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { 
                            searchText = ""
                            searchService.updateQuery("")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(16)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // 3. Suggestions List
                if !searchService.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchService.suggestions) { result in
                                    Button(action: {
                                        selectResult(result)
                                    }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(result.title)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Text(result.source == .google ? "Google" : "MapKit")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                            }
                                            Text(result.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                        .frame(maxHeight: 250) // Adjust height as needed
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        .padding(.top, 8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60) // Increased to clear safe area and feel more "up"
            .zIndex(100) // Ensure list stays on top
        }
        .padding(.top, 20)
        .background(Color.clear) 
        .presentationDetents([.height(searchService.suggestions.isEmpty ? 220 : 500)])
        .presentationCornerRadius(32)
        .presentationBackground(.clear) 
        .presentationDragIndicator(.hidden)
        // ... rest of sheet ...
        .sheet(item: $activeSheet) { mode in
            switch mode {
            case .smartImport:
                SmartImportView(onDismiss: { activeSheet = nil })
            case .accommodation:
                AccommodationPopupView(onAdd: { name in
                    var spot = ItinerarySpot.empty()
                    spot.name = name
                    spot.category = .accommodation
                    onAddSpot(spot)
                    activeSheet = nil
                    dismiss()
                })
            case .collection:
                SavedPlacesResultView(sdContents: sdContents, onAdd: { selectedSpots in
                    for spot in selectedSpots {
                        onAddSpot(spot)
                    }
                    activeSheet = nil
                    dismiss()
                })
            }
        }
    }
    
    private func selectResult(_ result: SearchResult) {
        Task {
            do {
                let details = try await searchService.getDetails(for: result)
                await MainActor.run {
                    var spot = ItinerarySpot.empty()
                    spot.name = result.title
                    spot.latitude = details.lat
                    spot.longitude = details.lng
                    spot.googlePlaceId = result.source == .google ? result.placeId : nil
                    onAddSpot(spot)
                    dismiss()
                }
            } catch {
                print("❌ Failed to fetch details: \(error)")
                // Fallback to simple add
                await MainActor.run {
                    var spot = ItinerarySpot.empty()
                    spot.name = result.title
                    onAddSpot(spot)
                    dismiss()
                }
            }
        }
    }
    
    private func handleAddFromSearch(category: SpotCategory) {
        guard !searchText.isEmpty else { return }
        
        var spot = ItinerarySpot.empty()
        spot.name = searchText
        spot.category = category
        onAddSpot(spot)
        
        searchText = ""
        dismiss()
    }
}

// MARK: - Sub Views

struct FunctionButton: View {
    let icon: String
    let title: String
    let color: Color
    var isBlue: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                
                // Icon (Top Left)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.top, 10)
                    .padding(.leading, 10)
                
                // Text (Bottom Left)
                VStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.bottom, 10)
                        .padding(.leading, 10)
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            // Border
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2.5)
            )
            // Solid L-shape Shadow
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .offset(x: 4, y: 4)
            )
        }
    }
}

// 1. Smart Import View
struct SmartImportView: View {
    var onDismiss: () -> Void
    @State private var linkText = ""
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("智能導入")
                    .font(.title2).bold()
                    .padding(.top, 24)
                
                // Link Import
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "link")
                        Text("文本或鏈接識別")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    
                    TextEditor(text: $linkText)
                        .frame(height: 80) // Slightly shorter
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    
                    Button("開始識別") { }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
                .padding(.horizontal)
                
                // Screenshot Import
                Button(action: {}) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title)
                            .foregroundColor(.black)
                        VStack(alignment: .leading) {
                            Text("截圖識別")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .presentationDetents([.height(350)]) // Fixed lower height
        .presentationCornerRadius(32)
    }
}

// 2. Accommodation Popup
struct AccommodationPopupView: View {
    var onAdd: (String) -> Void
    @State private var text = ""
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("添加住宿")
                    .font(.title2).bold()
                    .padding(.top, 24)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜尋住宿地點", text: $text)
                        .onSubmit { onAdd(text) }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .presentationDetents([.height(200)])
        .presentationCornerRadius(32)
    }
}

// 3. Collection (Real Data + Tags)
struct SavedPlacesResultView: View {
    let sdContents: [SDContent]
    var onAdd: ([ItinerarySpot]) -> Void
    
    @State private var selectedIds: Set<String> = []
    @State private var selectedFilter = "全部"
    
    // Category Logic
    @AppStorage("customLibraryCategories") private var customCategoriesRaw: String = "[]"
    let defaultFilters = ["全部", "美食 🍜", "景點 🗻", "住宿 🏠", "購物 🛍️"]
    
    var allFilters: [String] {
        var filters = defaultFilters
        if let data = customCategoriesRaw.data(using: .utf8),
           let custom = try? JSONDecoder().decode([String].self, from: data) {
            filters.append(contentsOf: custom)
        }
        return filters
    }
    
    var filteredContent: [SDContent] {
        if selectedFilter == "全部" { return sdContents }
        let catName = selectedFilter.components(separatedBy: " ").first ?? selectedFilter
        return sdContents.filter { content in
            // Basic matching logic
            if let userCat = content.userCategory { return userCat == catName }
            // Auto-cat check (simplified)
            let cats = content.places.compactMap { $0.category?.lowercased() }.joined()
            if catName == "美食" && (cats.contains("food") || cats.contains("restaurant")) { return true }
            if catName == "住宿" && (cats.contains("lodging") || cats.contains("hotel")) { return true }
            if catName == "購物" && (cats.contains("store") || cats.contains("shop")) { return true }
            if catName == "景點" { return true }
            return false
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("已收藏的地點")
                    .font(.title2).bold()
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allFilters, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter)
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundColor(PuboColors.navy)
                                    .background(selectedFilter == filter ? PuboColors.yellow : Color.gray.opacity(0.1))
                                    .cornerRadius(20)
                                    .overlay(Capsule().stroke(selectedFilter == filter ? PuboColors.navy : Color.gray.opacity(0.2)))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4) // Fix clipping
                }
                
                // Places List
                let places = filteredContent.flatMap { $0.places }
                
                if places.isEmpty {
                     VStack {
                        Spacer()
                        Text("此分類無地點")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(places, id: \.id) { place in
                                HStack {
                                    // Try to find image from content
                                    // Reverse lookup or just use placeholder
                                    let imgUrl = place.contents.first?.previewThumbnailUrl
                                    
                                    if let urlStr = imgUrl, let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Color.gray.opacity(0.1)
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        // Fallback icon
                                        Image(systemName: "mappin.circle.fill")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(PuboColors.navy)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(place.name).font(.headline)
                                        Text(place.address ?? "").font(.caption).foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Selection
                                    Button(action: {
                                        if selectedIds.contains(place.id) {
                                            selectedIds.remove(place.id)
                                        } else {
                                            selectedIds.insert(place.id)
                                        }
                                    }) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(selectedIds.contains(place.id) ? .white : .clear)
                                            .frame(width: 24, height: 24)
                                            .background(selectedIds.contains(place.id) ? PuboColors.navy : Color.white)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(PuboColors.navy, lineWidth: 2))
                                    }
                                }
                                .padding(.horizontal, 24)
                                .onTapGesture {
                                    if selectedIds.contains(place.id) {
                                        selectedIds.remove(place.id)
                                    } else {
                                        selectedIds.insert(place.id)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Confirm
                if !selectedIds.isEmpty {
                    Button(action: {
                        let selectedPlaces = places.filter { selectedIds.contains($0.id) }
                        let spots = selectedPlaces.map { place -> ItinerarySpot in
                            var s = ItinerarySpot.empty()
                            s.name = place.name
                            s.placeId = Int(place.id)
                            s.googlePlaceId = place.id // Pass SDPlace.id (String) as googlePlaceId
                            s.latitude = place.latitude
                            s.longitude = place.longitude
                            
                            // Restore Opening Hours from SDPlace
                            if let jsonStr = place.openingHours,
                               let data = jsonStr.data(using: .utf8),
                               let openHours = try? JSONDecoder().decode(OpenHours.self, from: data) {
                                
                                s.place = PlaceInfo(
                                    name: place.name,
                                    placeId: place.id, // Pass SDPlace.id (String) as PlaceInfo.placeId
                                    address: place.address,
                                    latitude: place.latitude,
                                    longitude: place.longitude,
                                    category: place.category,
                                    rating: place.rating,
                                    userRatingsTotal: place.userRatingCount,
                                    openingHours: openHours
                                )
                            } else {
                                // Fallback if no opening hours (but we have rating)
                                s.place = PlaceInfo(
                                    name: place.name,
                                    placeId: place.id, // Pass SDPlace.id (String) as PlaceInfo.placeId
                                    address: place.address,
                                    latitude: place.latitude,
                                    longitude: place.longitude,
                                    category: place.category,
                                    rating: place.rating,
                                    userRatingsTotal: place.userRatingCount,
                                    openingHours: nil
                                )
                            }
                            
                            if let cat = place.category?.lowercased() {
                                if cat.contains("food") { s.category = .food }
                                else if cat.contains("lodging") { s.category = .accommodation }
                                else { s.category = .spot }
                            }
                            return s
                        }
                        onAdd(spots)
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(PuboColors.navy)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
