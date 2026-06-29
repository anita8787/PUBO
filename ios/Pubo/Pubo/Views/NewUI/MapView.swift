import SwiftUI
import MapKit
import SwiftData

enum APIError: Error {
    case invalidURL
}

struct MapView: View {
    // 預設台北；onAppear 時若 LocationManager 已有座標則移動
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    
    @State private var isManuallySelectedRegion = false
    @State private var selectedPlace: MapPlace? = nil
    @State private var selectedCategory: String = "全部"
    @State private var showCityPicker = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var currentCountry = "台灣"
    @State private var currentCity = "台北市"
    @State private var searchedPlaces: [MapPlace] = []
    @State private var mapSelection: MapFeature? = nil
    @State private var visibleRegion: MKCoordinateRegion?
    @EnvironmentObject var tripManager: TripManager
    @EnvironmentObject var locationManager: LocationManager
    @Query var savedPlaces: [SDPlace]
    var onBack: () -> Void
    
    let categories = ["全部", "美食", "景點", "購物", "住宿"]
    let categoryEmoji: [String: String] = ["全部": "📍", "美食": "🍴", "景點": "🌿", "購物": "🛍️", "住宿": "🏨"]
    
    // Removed mock places
    
    var filteredPlaces: [SDPlace] {
        savedPlaces.filter { sdPlace in
            guard sdPlace.isSaved else { return false }
            if selectedCategory == "全部" { return true }
            return normalizedCategory(sdPlace.category ?? "") == selectedCategory
        }
    }
    
    var filteredSearchedPlaces: [MapPlace] {
        if selectedCategory == "全部" { return searchedPlaces }
        return searchedPlaces.filter { place in
            normalizedCategory(place.category) == selectedCategory
        }
    }
    
    private func normalizedCategory(_ category: String) -> String {
        let cat = category.lowercased()
        if cat.contains("美食") || cat.contains("food") || cat.contains("餐廳") || cat.contains("咖啡") || cat.contains("拉麵") || cat.contains("小吃") || cat.contains("餐餐") {
            return "美食"
        } else if cat.contains("購物") || cat.contains("shopping") || cat.contains("百貨") || cat.contains("商店") {
            return "購物"
        } else if cat.contains("住宿") || cat.contains("stay") || cat.contains("hotel") || cat.contains("宿") {
            return "住宿"
        } else {
            return "景點"
        }
    }
    
    private func searchMapForCategory(_ category: String) {
        guard let region = visibleRegion else { return }
        Task {
            let request = MKLocalSearch.Request()
            let query: String
            switch category {
            case "美食": query = "餐廳"
            case "購物": query = "購物"
            case "住宿": query = "飯店"
            case "景點": query = "景點"
            default: query = category
            }
            request.naturalLanguageQuery = query
            request.region = region
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                await MainActor.run {
                    var newPlaces: [MapPlace] = []
                    for item in response.mapItems {
                        guard let name = item.name else { continue }
                        let mapPlace = MapPlace(
                            id: UUID().uuidString,
                            name: name,
                            rating: 4.5,
                            category: category,
                            time: "營業時間未知",
                            address: item.placemark.title ?? name,
                            image: "",
                            coordinate: item.placemark.coordinate
                        )
                        if !searchedPlaces.contains(where: { $0.name == name && abs($0.coordinate.latitude - mapPlace.coordinate.latitude) < 0.0001 }) {
                            newPlaces.append(mapPlace)
                        }
                    }
                    searchedPlaces.append(contentsOf: newPlaces)
                }
            } catch {
                print("Search failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        let cat = category.lowercased()
        if cat.contains("甜點") || cat.contains("dessert") || cat.contains("冰") || cat.contains("蛋糕") || cat.contains("cafe") || cat.contains("coffee") || cat.contains("咖啡") || cat.contains("tea") || cat.contains("飲料") { return "dessert" }
        if cat.contains("美食") || cat.contains("food") || cat.contains("餐廳") || cat.contains("拉麵") || cat.contains("小吃") || cat.contains("ramen") || cat.contains("restaurant") || cat.contains("meal") || cat.contains("dining") || cat.contains("bistro") { return "restaurant" }
        if cat.contains("購物") || cat.contains("shopping") || cat.contains("百貨") || cat.contains("商店") || cat.contains("store") || cat.contains("market") || cat.contains("mall") { return "shopping" }
        if cat.contains("娛樂") || cat.contains("fun") || cat.contains("遊樂") || cat.contains("親子") || cat.contains("kids") || cat.contains("amusement") || cat.contains("game") { return "fun" }
        if cat.contains("住宿") || cat.contains("stay") || cat.contains("hotel") || cat.contains("宿") || cat.contains("民宿") || cat.contains("inn") { return "hotel" }
        if cat.contains("景點") || cat.contains("attraction") || cat.contains("旅遊") || cat.contains("地標") || cat.contains("文青") || cat.contains("文化") || cat.contains("park") || cat.contains("museum") || cat.contains("shrine") || cat.contains("temple") { return "camera" }
        return "camera" // Default
    }
    
    var body: some View {
        ZStack {
            // Map Layer — full screen
            Map(position: $position, selection: $mapSelection) {
                // 1. Show saved places filtered by category
                ForEach(filteredPlaces) { sdPlace in
                    // Make sure coordinate is valid
                    if sdPlace.latitude != 0.0 && sdPlace.longitude != 0.0 {
                        savedPlacePin(sdPlace)
                    }
                }
                
                // 3. Show searched places as pins
                ForEach(filteredSearchedPlaces) { place in
                    searchedPlacePin(place)
                }
            }
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .onAppear {
                if let sdPlace = tripManager.focusPlaceFromLibrary {
                    // --- 1. 跳轉到收藏庫景點 ---
                    let coord = CLLocationCoordinate2D(latitude: sdPlace.latitude, longitude: sdPlace.longitude)
                    let status = sdPlace.simplifiedStatusText
                    let timeText = sdPlace.openNow == true ? (status.isEmpty ? "營業中" : "營業中 · \(status)") : (status.isEmpty ? "休息中" : "休息中 · \(status)")
                    let mapPlace = MapPlace(
                        id: sdPlace.id,
                        name: sdPlace.name,
                        rating: sdPlace.rating ?? 0.0,
                        category: sdPlace.category ?? "景點",
                        time: timeText,
                        address: sdPlace.address ?? "",
                        image: sdPlace.imageUrl ?? "",
                        coordinate: coord
                    )
                    let cat = mapPlace.category
                    if cat.contains("美食") || cat.contains("餐廳") || cat.contains("咖啡") || cat.contains("food") || cat.contains("拉麵") || cat.contains("小吃") {
                        selectedCategory = "美食"
                    } else if cat.contains("購物") || cat.contains("shopping") || cat.contains("百貨") || cat.contains("商店") {
                        selectedCategory = "購物"
                    } else if cat.contains("住宿") || cat.contains("stay") || cat.contains("hotel") || cat.contains("宿") {
                        selectedCategory = "住宿"
                    } else {
                        selectedCategory = "景點"
                    }
                    
                    if !searchedPlaces.contains(where: { $0.id == mapPlace.id }) && !savedPlaces.contains(where: { $0.id == mapPlace.id }) {
                        searchedPlaces.append(mapPlace)
                    }
                    selectedPlace = mapPlace
                    
                    // 立即設定地圖位置
                    position = .camera(MapCamera(centerCoordinate: coord, distance: 3000))
                    
                    // 延遲清除標記，防止 LocationManager 剛載入時立刻覆蓋掉位置
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            tripManager.focusPlaceFromLibrary = nil
                        }
                    }
                } else {
                    // --- 2. 正常開啟地圖，定位到用戶位置 ---
                    if let coord = locationManager.currentCoordinate {
                        position = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                        currentCity = locationManager.currentCity
                        currentCountry = locationManager.currentCountry
                    }
                }
            }
            .onChange(of: locationManager.currentCoordinate?.latitude) { oldLat, newLat in
                // 若用戶已手動選擇過，則不再自動跳轉回目前位置，也不要覆蓋城市文字
                guard !isManuallySelectedRegion else { return }
                
                // 定位初次更新時（從 nil 到有值），移動地圖並更新城市名稱
                // 只有在用戶沒有聚焦某個景點時才移動
                guard tripManager.focusPlaceFromLibrary == nil, selectedPlace == nil else { return }
                if let coord = locationManager.currentCoordinate, oldLat == nil {
                    withAnimation(.easeInOut) {
                        position = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
                currentCity = locationManager.currentCity
                currentCountry = locationManager.currentCountry
            }
            .onChange(of: mapSelection) {
                if let feature = mapSelection {
                    // Convert MapFeature to MapPlace with more details
                    Task {
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = feature.title
                        request.region = MKCoordinateRegion(center: feature.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        let search = MKLocalSearch(request: request)
                        
                        var address = "地址載入中..."
                        do {
                            let response = try await search.start()
                            if let item = response.mapItems.first {
                                address = item.name ?? feature.title ?? "未知地址"
                            }
                        } catch {
                            address = feature.title ?? "未知地址"
                        }

                        await MainActor.run {
                            let newPlace = MapPlace(
                                id: UUID().uuidString,
                                name: feature.title ?? "未知地點",
                                rating: 4.5,
                                category: selectedCategory, // Use current selected category
                                time: "營業時間未知",
                                address: address,
                                image: "",
                                coordinate: feature.coordinate
                            )
                            withAnimation {
                                // Add to searchedPlaces so it stays visible as a pin
                                if !searchedPlaces.contains(where: { $0.coordinate.latitude == newPlace.coordinate.latitude && $0.coordinate.longitude == newPlace.coordinate.longitude }) {
                                    searchedPlaces.append(newPlace)
                                }
                                selectedPlace = newPlace
                            }
                        }
                    }
                }
            }
            .onChange(of: tripManager.focusPlaceFromLibrary) { _, newValue in
                guard let sdPlace = newValue else { return }
                let coord = CLLocationCoordinate2D(latitude: sdPlace.latitude, longitude: sdPlace.longitude)
                let status = sdPlace.simplifiedStatusText
                let timeText = sdPlace.openNow == true ? (status.isEmpty ? "營業中" : "營業中 · \(status)") : (status.isEmpty ? "休息中" : "休息中 · \(status)")
                let mapPlace = MapPlace(
                    id: sdPlace.id,
                    name: sdPlace.name,
                    rating: sdPlace.rating ?? 0.0,
                    category: sdPlace.category ?? "景點",
                    time: timeText,
                    address: sdPlace.address ?? "",
                    image: sdPlace.imageUrl ?? "",
                    coordinate: coord
                )
                // Update selectedCategory so the saved pin is visible
                let cat = mapPlace.category
                if cat.contains("美食") || cat.contains("餐廳") || cat.contains("咖啡") || cat.contains("food") || cat.contains("拉麵") || cat.contains("小吃") {
                    selectedCategory = "美食"
                } else if cat.contains("購物") || cat.contains("shopping") || cat.contains("百貨") || cat.contains("商店") {
                    selectedCategory = "購物"
                } else if cat.contains("住宿") || cat.contains("stay") || cat.contains("hotel") || cat.contains("宿") {
                    selectedCategory = "住宿"
                } else {
                    selectedCategory = "景點"
                }
                
                if !searchedPlaces.contains(where: { $0.id == mapPlace.id }) && !savedPlaces.contains(where: { $0.id == mapPlace.id }) {
                    searchedPlaces.append(mapPlace)
                }
                selectedPlace = mapPlace
                
                withAnimation(.easeInOut(duration: 0.8)) {
                    position = .camera(MapCamera(centerCoordinate: coord, distance: 3000))
                }
                
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        tripManager.focusPlaceFromLibrary = nil
                    }
                }
            }
            
            // Floating header components — NO white background
            VStack(alignment: .leading, spacing: 8) {
                
                // Row 1: Back button + Spacer + Search
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.8))
                    }
                    
                    Spacer()
                    
                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.8))
                    }
                }
                
                // Row 2: City + Weather
                HStack(spacing: 4) {
                    Button(action: { withAnimation { showCityPicker = true } }) {
                        HStack(spacing: 4) {
                            Text(currentCity)
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.black)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Text("晴 16° - 27°")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("☀️")
                        .font(.system(size: 13))
                }
                
                // Row 3: Category Chips — floating pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { cat in
                            let isSelected = selectedCategory == cat
                            Button(action: {
                                withAnimation {
                                    if selectedCategory == cat {
                                        selectedCategory = ""
                                        searchedPlaces.removeAll()
                                    } else {
                                        selectedCategory = cat
                                        searchMapForCategory(cat)
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(categoryEmoji[cat] ?? "")
                                        .font(.system(size: 14))
                                    Text(cat)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isSelected ? PuboColors.navy : .primary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        Capsule().fill(Color.white)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.85))
                                            .background(Capsule().fill(.ultraThinMaterial))
                                    }
                                }
                                .overlay(
                                    Capsule().strokeBorder(
                                        isSelected ? PuboColors.navy : Color.clear,
                                        lineWidth: isSelected ? 1.5 : 0
                                    )
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.trailing, -20)
                
                Spacer()
                
                // Jump to Current Location Button
                HStack {
                    Spacer()
                    Button(action: {
                        isManuallySelectedRegion = false
                        if let coord = locationManager.currentCoordinate {
                            withAnimation(.easeInOut) {
                                position = .region(MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
                            currentCity = locationManager.currentCity
                            currentCountry = locationManager.currentCountry
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(PuboColors.navy)
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 5, y: 3)
                    }
                }
                .padding(.bottom, selectedPlace != nil ? 220 : 30) // Move up if place card is showing
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Full-screen Search Overlay
            if showSearch {
                MapSearchOverlay(isPresented: $showSearch) { place in
                    withAnimation {
                        // Avoid duplicates in searchedPlaces
                        if !searchedPlaces.contains(where: { $0.coordinate.latitude == place.coordinate.latitude && $0.coordinate.longitude == place.coordinate.longitude }) {
                            searchedPlaces.append(place)
                        }
                        selectedPlace = place
                        position = .region(MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
            
            // Country → City Picker
            if showCityPicker {
                CountryCityPicker(
                    currentCountry: $currentCountry,
                    currentCity: $currentCity,
                    isPresented: $showCityPicker,
                    onSelect: { country, city in
                        isManuallySelectedRegion = true
                        Task {
                            let request = MKLocalSearch.Request()
                            request.naturalLanguageQuery = "\(country) \(city)"
                            let search = MKLocalSearch(request: request)
                            if let response = try? await search.start(), let item = response.mapItems.first {
                                await MainActor.run {
                                    withAnimation(.easeInOut) {
                                        position = .region(MKCoordinateRegion(
                                            center: item.placemark.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                        ))
                                    }
                                }
                            }
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(50)
            }
            
            // Bottom Detail Card — shown when pin is tapped
            if let place = selectedPlace {
                VStack {
                    Spacer()
                    PlaceDetailCard(place: place, onClose: {
                        withAnimation { selectedPlace = nil }
                    })
                    .id(place.id) // Force trigger state resets & onAppear when place switches
                    .transition(.move(edge: .bottom))
                }
                .zIndex(10)
            }
        }
    }
    
    @MapContentBuilder
    private func savedPlacePin(_ sdPlace: SDPlace) -> some MapContent {
        Annotation(sdPlace.name, coordinate: CLLocationCoordinate2D(latitude: sdPlace.latitude, longitude: sdPlace.longitude)) {
            Button(action: {
                withAnimation {
                    let status = sdPlace.simplifiedStatusText
                    let timeText = sdPlace.openNow == true ? (status.isEmpty ? "營業中" : "營業中 · \(status)") : (status.isEmpty ? "休息中" : "休息中 · \(status)")
                    
                    let socialImage = sdPlace.contents.first?.previewThumbnailUrl
                    
                    selectedPlace = MapPlace(
                        id: sdPlace.id,
                        name: sdPlace.name,
                        rating: sdPlace.rating ?? 0.0,
                        category: sdPlace.category ?? "景點",
                        time: timeText,
                        address: sdPlace.address ?? "",
                        image: sdPlace.imageUrl ?? "",
                        coordinate: CLLocationCoordinate2D(latitude: sdPlace.latitude, longitude: sdPlace.longitude),
                        sourceImageUrl: socialImage,
                        sourceAuthor: sdPlace.contents.first?.authorName
                    )
                }
            }) {
                MapPinView(
                    icon: iconForCategory(sdPlace.category ?? ""),
                    hasImage: sdPlace.imageUrl != nil,
                    imageUrl: sdPlace.imageUrl ?? "",
                    name: sdPlace.name
                )
            }
        }
    }
    
    @MapContentBuilder
    private func mockPlacePin(_ place: MapPlace) -> some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            Button(action: {
                withAnimation { selectedPlace = place }
            }) {
                MapPinView(
                    icon: iconForCategory(place.category),
                    hasImage: !place.image.isEmpty,
                    imageUrl: place.image,
                    name: place.name
                )
            }
        }
    }
    
    @MapContentBuilder
    private func searchedPlacePin(_ place: MapPlace) -> some MapContent {
        Annotation(place.name, coordinate: place.coordinate) {
            Button(action: {
                withAnimation { selectedPlace = place }
            }) {
                MapPinView(
                    icon: iconForCategory(place.category),
                    hasImage: !place.image.isEmpty,
                    imageUrl: place.image,
                    name: place.name
                )
            }
        }
    }
}

// MARK: - Map Pin
struct MapPinView: View {
    let icon: String
    let hasImage: Bool
    let imageUrl: String
    let name: String
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(PuboColors.cardYellow, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                
                if let uiImage = UIImage(named: icon) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: (icon == "restaurant" || icon == "shopping") ? 32 : 26, 
                               height: (icon == "restaurant" || icon == "shopping") ? 32 : 26) // 放大餐廳與購物圖示
                } else {
                    Text(emojiFallback(for: icon))
                        .font(.system(size: 18))
                }
            }
                
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
        }
    }
    private func emojiFallback(for icon: String) -> String {
        switch icon {
        case "restaurant": return "🍴"
        case "shopping": return "🛍️"
        case "dessert": return "🍰"
        case "fun": return "🎢"
        case "hotel": return "🏨"
        case "camera": return "📸"
        default: return "📍"
        }
    }
}

// MARK: - Full-screen Search Overlay
struct MapSearchOverlay: View {
    @Binding var isPresented: Bool
    var onSelect: (MapPlace) -> Void
    @State private var searchText = ""
    @StateObject private var searchService = SearchService(apiKey: Secrets.googleAPIKey)
    
    struct PopularDestination: Identifiable {
        let id = UUID()
        let name: String
        let image: String
        let coordinate: CLLocationCoordinate2D
    }
    
    let popular: [PopularDestination] = [
        PopularDestination(name: "東京", image: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917)),
        PopularDestination(name: "京都", image: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681)),
        PopularDestination(name: "大阪", image: "https://images.unsplash.com/photo-1590253697795-a7403487624c?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023)),
        PopularDestination(name: "北海道", image: "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469)),
        PopularDestination(name: "首爾", image: "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)),
        PopularDestination(name: "釜山", image: "https://images.unsplash.com/photo-1578351508240-5e3a36cc17f2?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 35.1796, longitude: 129.0756)),
        PopularDestination(name: "曼谷", image: "https://images.unsplash.com/photo-1508009603885-50cf7c579365?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018)),
        PopularDestination(name: "峴港", image: "https://images.unsplash.com/photo-1559592443-7f87a79f6386?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 16.0544, longitude: 108.2022)),
        PopularDestination(name: "台北", image: "https://images.unsplash.com/photo-1583116632441-046637373842?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)),
        PopularDestination(name: "台南", image: "https://images.unsplash.com/photo-1627918805689-69335a16d97c?auto=format&fit=crop&w=400&q=80", coordinate: CLLocationCoordinate2D(latitude: 22.9997, longitude: 120.2270)),
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search Bar + Cancel
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    TextField("請輸入地點，發現更多精選行程", text: $searchText)
                        .font(.system(size: 14))
                        .onChange(of: searchText) { old, newValue in
                            searchService.updateQuery(newValue)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PuboColors.navy, lineWidth: 2.5)
                )
                .retroShadow(color: Color.black.opacity(0.15), offset: 3)
                
                Button(action: { withAnimation { isPresented = false } }) {
                    Text("取消")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            // Suggestions or Popular
            if !searchService.suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchService.suggestions) { result in
                            Button(action: {
                                // For MapView, we just close search and let user handle it or navigate
                                // But more useful to center map on selection
                                Task {
                                    if let details = try? await searchService.getDetails(for: result) {
                                        let mapPlace = MapPlace(
                                            id: result.placeId,
                                            name: result.title,
                                            rating: 4.5, // Default rating if missing
                                            category: "景點",
                                            time: "營業時間未知",
                                            address: details.address ?? "",
                                            image: "", // We can try to fetch image later
                                            coordinate: CLLocationCoordinate2D(latitude: details.lat, longitude: details.lng)
                                        )
                                        await MainActor.run {
                                            onSelect(mapPlace)
                                            isPresented = false
                                        }
                                    } else {
                                        await MainActor.run {
                                            isPresented = false
                                        }
                                    }
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                    Text(result.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Divider().padding(.horizontal, 20)
                        }
                    }
                }
            } else {
                // Popular Destinations
                Text("熱門目的地行程")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(popular) { dest in
                            Button(action: {
                                // Select destination
                                let place = MapPlace(
                                    id: dest.id.uuidString,
                                    name: dest.name,
                                    rating: 4.8,
                                    category: "熱門目的地",
                                    time: "",
                                    address: dest.name,
                                    image: dest.image,
                                    coordinate: dest.coordinate
                                )
                                onSelect(place)
                                withAnimation { isPresented = false }
                            }) {
                                HStack(spacing: 10) {
                                    AsyncImage(url: URL(string: dest.image)) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                                    .clipped()
                                    
                                    Text(dest.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - Country → City Picker
struct CountryCityPicker: View {
    @Binding var currentCountry: String
    @Binding var currentCity: String
    @Binding var isPresented: Bool
    var onSelect: ((String, String) -> Void)? = nil
    @State private var pickerStep: PickerStep = .country
    
    enum PickerStep { case country, city }
    
    static let countryData: [String: [String]] = [
        "台灣": ["台北市", "新北市", "台中市", "高雄市", "台南市", "桃園市", "新竹市"],
        "日本": ["東京", "大阪", "京都", "北海道", "沖繩", "名古屋", "福岡"],
        "韓國": ["首爾", "釜山", "濟州", "仁川", "大邱"],
        "泰國": ["曼谷", "清邁", "普吉島", "芭達雅"],
        "美國": ["紐約", "洛杉磯", "舊金山", "西雅圖", "夏威夷"],
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if pickerStep == .city {
                        Button(action: { withAnimation { pickerStep = .country } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                        }
                    }
                    
                    Text(pickerStep == .country ? "選擇國家" : "選擇城市")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(PuboColors.navy)
                    
                    Spacer()
                    
                    Button(action: { withAnimation { isPresented = false } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                if pickerStep == .country {
                    // Country list
                    let countries = Array(Self.countryData.keys).sorted()
                    ForEach(countries, id: \.self) { country in
                        Button(action: {
                            currentCountry = country
                            withAnimation { pickerStep = .city }
                        }) {
                            HStack {
                                Text(countryFlag(country))
                                    .font(.system(size: 20))
                                    .foregroundColor(.black) // Temporary fix
                                Text(country)
                                    .font(.system(size: 15, weight: currentCountry == country ? .black : .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                if currentCountry == country {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(PuboColors.navy)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        if country != countries.last { Divider().padding(.horizontal, 20) }
                    }
                } else {
                    // City list for selected country
                    let cities = Self.countryData[currentCountry] ?? []
                    ForEach(cities, id: \.self) { city in
                        Button(action: {
                            currentCity = city
                            onSelect?(currentCountry, city)
                            withAnimation { isPresented = false }
                        }) {
                            HStack {
                                Text(city)
                                    .font(.system(size: 15, weight: currentCity == city ? .black : .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                if currentCity == city {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(PuboColors.navy)
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        if city != cities.last { Divider().padding(.horizontal, 20) }
                    }
                }
                
                Spacer().frame(height: 16)
            }
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        }
    }
    
    func countryFlag(_ country: String) -> String {
        switch country {
        case "台灣": return "🇹🇼"
        case "日本": return "🇯🇵"
        case "韓國": return "🇰🇷"
        case "泰國": return "🇹🇭"
        case "美國": return "🇺🇸"
        default: return "🌍"
        }
    }
}

// MARK: - Old components kept
struct CustomMarker: View {
    let icon: String
    var body: some View {
        ZStack {
            Circle()
                .fill(PuboColors.yellow)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(radius: 4)
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
            Triangle()
                .fill(PuboColors.yellow)
                .frame(width: 20, height: 16)
                .offset(y: 28)
        }
    }
}

struct PlaceDetailCard: View {
    // AI Server Configuration — Change this to match your computer's IP
    private let aiServerBaseUrl = "https://pubo-api-641234109681.asia-east1.run.app"
    
    let place: MapPlace
    let onClose: () -> Void
    
    @EnvironmentObject var tripManager: TripManager
    @State private var showAddSheet = false
    @State private var description: String? = nil
    @State private var proReview: String? = nil
    @State private var conReview: String? = nil
    @State private var isLoadingDescription = false
    @State private var detailedAddress: String? = nil
    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGFloat = 0

    private let collapsedHeight: CGFloat = 255
    private let expandedFraction: CGFloat = 0.80


    var body: some View {
        GeometryReader { geo in
            let screenHeight = geo.size.height + geo.safeAreaInsets.bottom
            let expandedHeight = screenHeight * expandedFraction
            let currentTarget: CGFloat = isExpanded ? expandedHeight : collapsedHeight
            let displayHeight = max(collapsedHeight, currentTarget - dragOffset)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // ── Fixed Header: Drag pill + Title + X button ──
                    VStack(spacing: 0) {
                        // Drag Pill
                        HStack {
                            Spacer()
                            Capsule()
                                .fill(Color(hex: "D1D1D6"))
                                .frame(width: 36, height: 5)
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        
                        // Title and Close Button
                        HStack(alignment: .top) {
                            Text(place.name)
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(PuboColors.navy)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, 20)
                            
                            Spacer()
                            
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.black.opacity(0.6))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                            .padding(.top, -4)
                        }
                    }
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())

                    // ── Scrolling Content (展開時才可滾動，收合時整體可上滑展開) ──
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // 1. (Title moved to header)

                            // 2. Category
                            HStack(spacing: 8) {
                                Text(place.category)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1)).cornerRadius(7)
                            }
                            .padding(.bottom, 10)



                            // 4. Address
                            let addr = detailedAddress ?? place.address
                            if !addr.isEmpty {
                                Button(action: {
                                    let encodedAddress = addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    if let url = URL(string: "maps://?q=\(encodedAddress)") {
                                        if UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                        } else {
                                            // Fallback to Google Maps or web if Apple Maps is somehow unavailable
                                            if let webUrl = URL(string: "https://maps.apple.com/?q=\(encodedAddress)") {
                                                UIApplication.shared.open(webUrl)
                                            }
                                        }
                                    }
                                }) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue) // 提示可點擊
                                            .padding(.top, 2)
                                        Text(addr)
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue) // 提示可點擊
                                            .underline()
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 20)
                            }

                            // 5. Image
                            let fixedSourceUrl = place.sourceImageUrl?.replacingOccurrences(of: "pubo-images/", with: "pubo_image/") ?? ""
                            let fixedPlaceImage = place.image.replacingOccurrences(of: "pubo-images/", with: "pubo_image/")
                            
                            if !fixedSourceUrl.isEmpty, let url = URL(string: fixedSourceUrl) ?? URL(string: fixedSourceUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                                ZStack(alignment: .bottomLeading) {
                                    CachedAsyncImage(url: url) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.08).overlay(ProgressView())
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 180).clipped()

                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill").font(.system(size: 9))
                                        Text(place.sourceAuthor.flatMap { $0.isEmpty ? nil : "來自 \($0)" } ?? "來自社群貼文")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5)).cornerRadius(6).padding(12)
                                }
                                .cornerRadius(16)
                                .padding(.bottom, 20)
                            } else if !fixedPlaceImage.isEmpty, let url = URL(string: fixedPlaceImage) ?? URL(string: fixedPlaceImage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                                CachedAsyncImage(url: url) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.08).overlay(ProgressView())
                                }
                                .frame(maxWidth: .infinity).frame(height: 180).clipped()
                                .cornerRadius(16)
                                .padding(.bottom, 20)
                            } else {
                                // Placeholder
                                ZStack {
                                    Color.gray.opacity(0.1)
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity).frame(height: 180).clipped()
                                .cornerRadius(16)
                                .padding(.bottom, 20)
                            }

                            // AI Description & Reviews sections removed as per simplified details requirements

                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                    .scrollDisabled(!isExpanded) // 收合時禁止滾動，只允許上滑展開

                    // 7. Action Buttons (Fixed at bottom)
                    HStack(spacing: 12) {
                        MapPlaceNavigateButton(place: place)
                        
                        Button(action: { showAddSheet = true }) {
                            Label("加入行程", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(PuboColors.navy).cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                    .background(Color.white)
                }
                .frame(height: displayHeight, alignment: .top)
                .background(Color.white)
                .cornerRadius(32, corners: [.topLeft, .topRight])
                .overlay(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]).stroke(PuboColors.cardOrange.opacity(0.5), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.12), radius: 15, y: -5)
                // 收合時：整張卡片上滑 → 展開；展開時：下滑 → 收合
                .highPriorityGesture(
                    isExpanded ? nil :
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            if value.translation.height < 0 {
                                dragOffset = -value.translation.height
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if value.translation.height < -60 { isExpanded = true }
                                dragOffset = 0
                            }
                        }
                )
                .gesture(
                    isExpanded ?
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = -value.translation.height
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if value.translation.height > 80 { isExpanded = false }
                                dragOffset = 0
                            }
                        }
                    : nil
                )

            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {
            fetchDetailedAddress()
            fetchAIDescription()
        }
        .sheet(isPresented: $showAddSheet) {
            AddToTripSheet(place: place, onClose: {
                showAddSheet = false
                onClose()
            })
            .environmentObject(tripManager)
        }
    }

    private func fetchDetailedAddress() {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    let addr = [placemark.locality, placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
                    if !addr.isEmpty { await MainActor.run { self.detailedAddress = addr } }
                }
            } catch { print("Geocoder error: \(error)") }
        }
    }

    private func fetchAIDescription() {
        // Disabled background Gemini API calls as per simplified details requirements
        return
    }
}

// Helper Shapes
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
