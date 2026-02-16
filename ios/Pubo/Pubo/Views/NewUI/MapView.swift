import SwiftUI
import MapKit

struct MapView: View {
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // Taipei
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var selectedPlace: MapPlace? = nil
    @State private var selectedCategory: String = "美食"
    @State private var showCityPicker = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var currentCountry = "台灣"
    @State private var currentCity = "台北市"
    @State private var searchedPlaces: [MapPlace] = []
    @State private var mapSelection: MapFeature? = nil
    var onBack: () -> Void
    
    let categories = ["美食", "景點", "文青朝聖"]
    let categoryEmoji: [String: String] = ["美食": "🍜", "景點": "🌿", "文青朝聖": "✝️"]
    
    // Mock places
    let places = [
        MapPlace(id: "1", name: "契茶小豆", rating: 4.3, category: "美食", time: "11:00am - 17:00pm", address: "台北市士林區德惠街49號", image: "https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=400&auto=format&fit=crop", coordinate: CLLocationCoordinate2D(latitude: 25.0550, longitude: 121.5250)),
        MapPlace(id: "2", name: "小坪頂土雞農家菜", rating: 4.5, category: "美食", time: "10:00am - 20:00pm", address: "台北市北投區", image: "https://images.unsplash.com/photo-1570459027562-4a916cc6113f?q=80&w=400&auto=format&fit=crop", coordinate: CLLocationCoordinate2D(latitude: 25.0800, longitude: 121.5100)),
        MapPlace(id: "3", name: "De Ji Shao La Dim Sum", rating: 4.7, category: "美食", time: "09:00am - 21:00pm", address: "台北市士林區", image: "https://images.unsplash.com/photo-1576675466969-38eeae4b41f6?q=80&w=400&auto=format&fit=crop", coordinate: CLLocationCoordinate2D(latitude: 25.0400, longitude: 121.5300)),
        MapPlace(id: "4", name: "越南美食", rating: 4.2, category: "美食", time: "11:00am - 22:00pm", address: "台北市萬華區", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.0280, longitude: 121.4950)),
        MapPlace(id: "5", name: "麥當勞", rating: 3.8, category: "美食", time: "24hr", address: "台北市北投區", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.0150, longitude: 121.5200)),
        MapPlace(id: "6", name: "星巴克咖啡(天母SOGO店)", rating: 4.1, category: "美食", time: "07:00am - 22:00pm", address: "台北市士林區天母", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.1050, longitude: 121.5350)),
        MapPlace(id: "7", name: "芦洲土林串燒", rating: 4.4, category: "美食", time: "17:00pm - 01:00am", address: "台北市蘆洲區", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.0050, longitude: 121.4700)),
        MapPlace(id: "8", name: "全球唯二青磺泉", rating: 4.8, category: "景點", time: "09:00am - 18:00pm", address: "台北市北投區", image: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=400&auto=format&fit=crop", coordinate: CLLocationCoordinate2D(latitude: 25.0700, longitude: 121.5150)),
        MapPlace(id: "9", name: "陽明山竹子淞杉木林餐廳", rating: 4.6, category: "景點", time: "08:00am - 17:00pm", address: "台北市北投區陽明山", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.0900, longitude: 121.5450)),
        MapPlace(id: "10", name: "草山夜未眠觀餐廳", rating: 4.3, category: "景點", time: "18:00pm - 02:00am", address: "台北市北投區", image: "", coordinate: CLLocationCoordinate2D(latitude: 25.0850, longitude: 121.5500)),
    ]
    
    var filteredPlaces: [MapPlace] {
        places.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        ZStack {
            // Map Layer — full screen
            Map(position: $position, selection: $mapSelection) {
                ForEach(filteredPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate) {
                        Button(action: {
                            withAnimation { selectedPlace = place }
                        }) {
                            MapPinView(
                                icon: place.category == "美食" ? "fork.knife" : "camera.fill",
                                hasImage: !place.image.isEmpty,
                                imageUrl: place.image,
                                name: place.name
                            )
                        }
                    }
                }
                
                // Show searched places as pins
                ForEach(searchedPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate) {
                        Button(action: {
                            withAnimation { selectedPlace = place }
                        }) {
                            MapPinView(
                                icon: "mappin.circle.fill",
                                hasImage: !place.image.isEmpty,
                                imageUrl: place.image,
                                name: place.name
                            )
                        }
                    }
                }
            }
            .ignoresSafeArea()
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
                                address = item.placemark.title ?? feature.title ?? "未知地址"
                            }
                        } catch {
                            address = feature.title ?? "未知地址"
                        }

                        await MainActor.run {
                            withAnimation {
                                selectedPlace = MapPlace(
                                    id: UUID().uuidString,
                                    name: feature.title ?? "未知地點",
                                    rating: 4.5,
                                    category: "景點",
                                    time: "暫無營業時間",
                                    address: address,
                                    image: "",
                                    coordinate: feature.coordinate
                                )
                            }
                        }
                    }
                }
            }
            
            // Floating header components — NO white background
            VStack(alignment: .leading, spacing: 8) {
                
                // Row 1: Back button + Spacer + Search
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    }
                    
                    Spacer()
                    
                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
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
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { cat in
                        Button(action: {
                            withAnimation { selectedCategory = cat }
                        }) {
                            HStack(spacing: 4) {
                                Text(categoryEmoji[cat] ?? "")
                                    .font(.system(size: 14))
                                Text(cat)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == cat
                                    ? .ultraThinMaterial
                                    : .ultraThinMaterial
                            )
                            .overlay(
                                Capsule().stroke(
                                    selectedCategory == cat ? Color.black.opacity(0.3) : Color.clear,
                                    lineWidth: 1
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
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
                    isPresented: $showCityPicker
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
                    .transition(.move(edge: .bottom))
                }
                .zIndex(10)
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
            if hasImage {
                VStack(spacing: 0) {
                    AsyncImage(url: URL(string: imageUrl)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 60, height: 50)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    
                    Text(name)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                }
            } else {
                // Icon-only pin (e.g. fork.knife for 美食)
                ZStack {
                    Circle()
                        .fill(PuboColors.yellow)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                Triangle()
                    .fill(PuboColors.yellow)
                    .frame(width: 12, height: 8)
                    .offset(y: -4)
            }
        }
    }
}

// MARK: - Full-screen Search Overlay
struct MapSearchOverlay: View {
    @Binding var isPresented: Bool
    var onSelect: (MapPlace) -> Void
    @State private var searchText = ""
    @StateObject private var searchService = SearchService(apiKey: "")
    
    struct PopularDestination: Identifiable {
        let id = UUID()
        let name: String
        let image: String
    }
    
    let popular: [PopularDestination] = [
        PopularDestination(name: "上海市", image: "https://images.unsplash.com/photo-1537519646099-5e63701ff581?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "北京市", image: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "廣州市", image: "https://images.unsplash.com/photo-1583394293214-28ded15ee548?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "青島市", image: "https://images.unsplash.com/photo-1559827260-dc66d52bef19?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "南京市", image: "https://images.unsplash.com/photo-1567095761054-7a02e69e5b2b?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "成都市", image: "https://images.unsplash.com/photo-1590736969955-71cc94901144?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "重慶市", image: "https://images.unsplash.com/photo-1547981609-4b6bfe67ca0b?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "杭州市", image: "https://images.unsplash.com/photo-1599571234909-29ed5d1321d6?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "韓國", image: "https://images.unsplash.com/photo-1553621042-f6e147245754?q=80&w=200&auto=format&fit=crop"),
        PopularDestination(name: "香港(中國)", image: "https://images.unsplash.com/photo-1536599018102-9f803c140fc1?q=80&w=200&auto=format&fit=crop"),
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
                        .onChange(of: searchText) {
                            searchService.updateQuery(searchText)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
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
    let place: MapPlace
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 48, height: 6)
                .padding(.top, 12)
            
            HStack(alignment: .top, spacing: 16) {
                if !place.image.isEmpty {
                    AsyncImage(url: URL(string: place.image)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(place.name)
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(PuboColors.navy)
                            .lineLimit(1)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("\(String(format: "%.1f", place.rating))")
                                .font(.system(size: 12, weight: .black))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PuboColors.cardOrange.opacity(0.1))
                        .foregroundColor(PuboColors.cardOrange)
                        .cornerRadius(4)
                        
                        Text(place.category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if !place.time.isEmpty && place.time != "暫無營業時間" {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(place.time)
                            }
                        }
                        
                        if !place.address.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(place.address)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                }
            }
            .padding(24)
            .padding(.bottom, 4)
            
            // AI Description Section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(PuboColors.yellow)
                        .font(.system(size: 14))
                    Text("地點介紹")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                    Spacer()
                }
                
                if isLoadingDescription {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("AI 正在分析中...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                } else if let desc = description {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.8))
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("暫無介紹資訊")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // Add to Trip Button
            Button(action: { showAddSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("加入行程")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(PuboColors.navy)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(Color.white)
        .cornerRadius(40, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        .overlay(
            RoundedCorner(radius: 40, corners: [.topLeft, .topRight])
                .stroke(PuboColors.cardOrange, lineWidth: 2)
        )
        .onAppear {
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
    
    @EnvironmentObject var tripManager: TripManager
    @State private var showAddSheet = false
    @State private var description: String? = nil
    @State private var isLoadingDescription = false
    
    private func fetchAIDescription() {
        guard description == nil else { return }
        isLoadingDescription = true
        
        Task {
            do {
                let url = URL(string: "http://127.0.0.1:8000/api/v1/analyze/place")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "name": place.name,
                    "address": place.address,
                    "category": place.category
                ]
                request.httpMethod = "POST"
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let desc = json["description"] as? String {
                    await MainActor.run {
                        self.description = desc
                        self.isLoadingDescription = false
                    }
                }
            } catch {
                print("❌ AI Description fetch failed: \(error)")
                await MainActor.run {
                    self.isLoadingDescription = false
                }
            }
        }
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
