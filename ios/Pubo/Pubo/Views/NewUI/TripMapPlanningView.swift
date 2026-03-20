import SwiftUI
import MapKit

struct TripMapPlanningView: View {
    @EnvironmentObject var tripManager: TripManager
    let trip: Trip
    @Binding var position: MapCameraPosition
    var spots: [ItinerarySpot]
    var allDays: [ItineraryDay]
    var selectedDayIndex: Int
    var onBack: () -> Void
    var onDaySelected: (Int) -> Void
    var onEditSpot: (ItinerarySpot) -> Void
    var onAddClick: () -> Void
    var onShareClick: () -> Void
    
    @State private var mapSubMode: MapSubMode = .overview // Default to overview
    @State private var isConcise: Bool = false // Default to false (List Mode)
    @State private var isOverviewExpanded: Bool = true // Overview card expanded state
    @State private var activeMemoId: String? // 展開備忘錄的景點 ID
    
    enum MapSubMode {
        case overview, daily
    }
    
    @State private var routes: [MKRoute] = [] // 真實導航路線條

    
    var body: some View {
        ZStack(alignment: .bottom) {
            // === 地圖圖層（背景）===
            mapLayer
            
            // === 浮動控制項（分開佈置，避免全螢幕遮擋）===
            // 使用獨立的 Top 容器，不蓋住中央地圖區域
            VStack {
                HStack(alignment: .top) {
                    backButton
                    Spacer()
                    headerActionButtons
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                Spacer()
            }
            
            // === 底部面板 ===
            bottomSheetPanel
                .zIndex(10)
        }
    }
    
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .offset(x: 2.5, y: 2.5)
                )
        }
    }
    
    private var headerActionButtons: some View {
        HStack(spacing: 12) {
            headerCircleButton(icon: "square.and.arrow.up", action: onShareClick)
            headerCircleButton(icon: "gearshape", action: {})
        }
    }
    
    
    // MARK: - 地圖圖層
    private var mapLayer: some View {
        Map(position: $position) { 
            ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                if let coord = spot.coordinate {
                    Annotation(spot.name, coordinate: CLLocationCoordinate2D(
                        latitude: coord.lat,
                        longitude: coord.long
                    )) {
                        mapMarker(for: spot, index: index)
                    }
                }
            }
            
            // 路線圖 (Real Road Routes)
            if !routes.isEmpty {
                ForEach(routes, id: \.self) { route in
                    MapPolyline(route)
                        .stroke(Color(hex: "FFC649").opacity(0.8), lineWidth: 5)
                }
            } else if spots.count >= 2 {
                // Fallback to straight lines if routes are not yet loaded
                MapPolyline(coordinates: spots.compactMap { spot in
                    if let coord = spot.coordinate {
                        return CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.long)
                    }
                    return nil
                })
                .stroke(Color(hex: "FFC649").opacity(0.4), lineWidth: 3)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
        .onAppear {
            updateMapToFitSpots()
            calculateRoutes()
        }
        .onChange(of: selectedDayIndex) {
            updateMapToFitSpots()
            calculateRoutes()
        }
        .onChange(of: spots.count) {
            updateMapToFitSpots()
            calculateRoutes()
        }
    }
    
    private func calculateRoutes() {
        guard spots.count >= 2 else {
            self.routes = []
            return
        }
        
        Task {
            var newRoutes: [MKRoute] = []
            
            for i in 0..<(spots.count - 1) {
                guard let startCoord = spots[i].coordinate,
                      let endCoord = spots[i+1].coordinate else { continue }
                
                // Skip invalid 0,0
                if startCoord.lat == 0 || endCoord.lat == 0 { continue }
                
                let startLocation = CLLocation(latitude: startCoord.lat, longitude: startCoord.long)
                let endLocation = CLLocation(latitude: endCoord.lat, longitude: endCoord.long)
                
                let request = MKDirections.Request()
                request.source = MKMapItem(location: startLocation, address: nil)
                request.destination = MKMapItem(location: endLocation, address: nil)
                
                // Determine transport type based on spot preference or default to automobile
                switch spots[i].travelMode {
                case .walk: request.transportType = .walking
                default: request.transportType = .automobile // Apple directions only support auto/walking/transit/any
                }
                
                let directions = MKDirections(request: request)
                do {
                    let response = try await directions.calculate()
                    if let route = response.routes.first {
                        newRoutes.append(route)
                    }
                } catch {
                    print("❌ Error fetching route for segment \(i): \(error)")
                }
            }
            
            await MainActor.run {
                self.routes = newRoutes
            }
        }
    }
    
    private func updateMapToFitSpots() {
        guard !spots.isEmpty else { return }
        
        let coords = spots.compactMap { spot -> CLLocationCoordinate2D? in
            guard let c = spot.coordinate else { return nil }
            // Filter out invalid 0,0 coordinates to prevent Null Island center
            if c.lat == 0.0 && c.long == 0.0 { return nil }
            return CLLocationCoordinate2D(latitude: c.lat, longitude: c.long)
        }
        
        guard !coords.isEmpty else {
            // Priority: Korea if destination contains SEOUL/KOREA, else default center
            var center = CLLocationCoordinate2D(latitude: 35.6895, longitude: 139.6917) // Tokyo default
            if trip.destination?.lowercased().contains("korea") == true || 
               trip.destination?.lowercased().contains("seoul") == true ||
               trip.destination?.lowercased().contains("韓國") == true ||
               trip.destination?.lowercased().contains("首爾") == true {
                center = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780) // Seoul
            }
            position = .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)))
            return 
        }
        
        // Calculate Bounding Box
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let deltaLat = max(0.012, (maxLat - minLat) * 1.5)
        let deltaLon = max(0.012, (maxLon - minLon) * 1.5)
        
        // 限制最大縮放，避免過大範圍
        let finalDeltaLat = min(0.5, deltaLat)
        let finalDeltaLon = min(0.5, deltaLon)
        
        let span = MKCoordinateSpan(
            latitudeDelta: finalDeltaLat,
            longitudeDelta: finalDeltaLon
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func focusOnSpot(_ spot: ItinerarySpot) {
        guard let coord = spot.coordinate else { return }
        let center = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.long)
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }
    
    // MARK: - 定位使用者
    
    // MARK: - 地圖標記
    @ViewBuilder
    private func mapMarker(for spot: ItinerarySpot, index: Int) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                // Main Marker Circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .retroShadow(color: .black.opacity(0.1), offset: 2)
                        .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                    
                    // Category Icon
                    categoryIcon(for: spot.category)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                }
                
                // Index Badge (Small Red Circle)
                ZStack {
                    Circle()
                        .fill(PuboColors.red)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    
                    Text("\(index + 1)")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: -4)
            }
            
            // 下方加入倒三角形當作大頭針的尖角
            Triangle()
                .fill(PuboColors.navy)
                .frame(width: 10, height: 8)
                .rotationEffect(.degrees(180))
                .offset(y: -1) // 微微向上偏移貼合圓圈
        }
        .offset(y: -16) // 讓尖角正對著座標點 (32+8=40/2=20，微調讓底部針尖對齊座標)
    }
    
    private func categoryIcon(for category: SpotCategory?) -> Image {
        switch category {
        case .food: return Image(systemName: "fork.knife")
        case .accommodation: return Image(systemName: "house.fill")
        case .shopping: return Image(systemName: "bag.fill")
        case .attraction: return Image(systemName: "camera.fill")
        case .spot: return Image(systemName: "mappin.and.ellipse")
        default: return Image(systemName: "mappin.and.ellipse")
        }
    }
    
    
    private func headerCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .offset(x: 2.5, y: 2.5)
                )
        }
    }
    
    // MARK: - 底部面板
    private var bottomSheetPanel: some View {
        VStack(spacing: 0) {
            // 拖曳把手
            dragHandle

            // 日期選擇器
            dayTabsSelector

            // 內容區域
            contentArea
        }
        .frame(height: isConcise ? 310 : ScreenUtils.height * 0.58) // 摺疊時高度需足以顯示輪播卡片
        .background(Color(hex: "FDFAEE"))
        .clipShape(RoundedCorner(radius: 40, corners: [.topLeft, .topRight]))
        .overlay(
            RoundedCorner(radius: 40, corners: [.topLeft, .topRight])
                .stroke(Color.black, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, y: -10)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isConcise)
        // 移除強制重置視圖的 .id，避免添加景點後自動跳回總覽
    }
    
    // MARK: - 拖曳把手
    private var dragHandle: some View {
        Button(action: { isConcise.toggle() }) {
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 48, height: 4)
                Spacer()
            }
            .frame(height: 32)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 日期選擇器
    private var dayTabsSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) { // Reduced spacing for oval style
                // 總覽 Tab
                Button(action: {
                    mapSubMode = .overview
                    isConcise = false // 點擊總覽時自動展開面板
                }) {
                    let isSelected = mapSubMode == .overview
                    Text("總覽")
                        .font(.system(size: 11, weight: .bold)) // Smaller font
                        .foregroundColor(isSelected ? .black : Color.gray.opacity(0.35))
                        .padding(.horizontal, 12) // Smaller padding
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(PuboColors.navy)
                                        .offset(x: 3, y: 3)
                                    Capsule()
                                        .fill(Color.white)
                                        .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 1.5))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                
                // 每日 Tabs
                ForEach(Array(allDays.enumerated()), id: \.offset) { index, day in
                    Button(action: {
                        mapSubMode = .daily
                        onDaySelected(index)
                    }) {
                        let isSelected = mapSubMode == .daily && selectedDayIndex == index
                        Text(verbatim: day.mapTabDateString)
                            .font(.system(size: 11, weight: .bold)) // Smaller font
                            .foregroundColor(isSelected ? .black : Color.gray.opacity(0.35))
                            .padding(.horizontal, 12) // Smaller padding
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(PuboColors.navy)
                                            .offset(x: 3, y: 3)
                                        Capsule()
                                            .fill(Color.white)
                                            .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 1.5))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14) // Increased for shadow room
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - 內容區域
    @ViewBuilder
    private var contentArea: some View {
        if isConcise {
            conciseSpotCarousel
        } else {
            ScrollView(showsIndicators: false) {
                if mapSubMode == .overview {
                    overviewContent
                } else {
                    dailySpotListContent
                }
            }
        }
    }
    
    // MARK: - 精簡模式輪播 (Concise Mode)
    private var conciseSpotCarousel: some View {
        TabView {
            ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                conciseSpotCard(spot: spot, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 240)
    }
    
    private func conciseSpotCard(spot: ItinerarySpot, index: Int) -> some View {
        VStack(spacing: 0) {
            // 頂部資訊區 (圖 + 文)
            HStack(alignment: .top, spacing: 16) {
                // 圖片
                AsyncImage(url: URL(string: spot.image)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.15))
                }
                .frame(width: 84, height: 84)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                
                // 文字資訊
                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.category == .food ? "美食" : "景點")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color(hex: "023B7E"))
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    Text(verbatim: "\(index + 1). \(spot.name)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("停留" + (spot.subLabel ?? "10分鐘"))
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer().frame(height: 12) 
            
            // 底部交通資訊列
            HStack(alignment: .center, spacing: 0) {
                // 左側：上一站交通 (若有)
                Group {
                    if index > 0, index - 1 < spots.count, let transport = spots[index - 1].travelToNext {
                         HStack(spacing: 4) {
                             Image(systemName: transport.type == .train ? "tram.fill" : (transport.type == .car ? "car.fill" : (transport.type == .bus ? "bus.fill" : "figure.walk")))
                                 .font(.system(size: 12))
                                 .foregroundColor(.gray.opacity(0.4))
                             Text(verbatim: "\(transport.time) \(transport.distance)")
                                 .font(.system(size: 10, weight: .black))
                                 .foregroundColor(.gray.opacity(0.4))
                         }
                         .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                
                // 中間：編號圓圈
                ZStack {
                    Circle()
                        .fill(PuboColors.navy)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
                .padding(.horizontal, 16)
                
                // 右側：下一站交通 (若有)
                Group {
                    if index < spots.count - 1, let transport = spot.travelToNext {
                        HStack(spacing: 4) {
                            Text(verbatim: "\(transport.time) \(transport.distance)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.gray.opacity(0.4))
                            Image(systemName: transport.type == .train ? "tram.fill" : (transport.type == .car ? "car.fill" : (transport.type == .bus ? "bus.fill" : "figure.walk")))
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .contentShape(Rectangle()) // 確保點擊區域覆蓋整個卡片
        .onTapGesture(count: 2) {
            focusOnSpot(spot)
        }
    }
    
    
    // MARK: - 總覽模式內容
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // 行程概要卡
            overviewSummaryCard
            
            // 行李清單卡
            luggageListCard
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    private var overviewSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行程概要")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.gray.opacity(0.5))
                .tracking(2)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(allDays.prefix(isOverviewExpanded ? allDays.count : 2).enumerated()), id: \.offset) { idx, day in
                    HStack(spacing: 8) {
                        Text(verbatim: "\(day.mapTabDateString) >")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(PuboColors.navy)
                        
                        Text(day.spots.isEmpty ? "尚未安排" : day.spots.map { $0.name }.joined(separator: " - "))
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            
            Button(action: { isOverviewExpanded.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: isOverviewExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .black))
                    Text(isOverviewExpanded ? "展開較少" : "展開全部")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(.gray.opacity(0.35))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color(hex: "E8F0FA"))
        .cornerRadius(40)
        .overlay(
            RoundedRectangle(cornerRadius: 40)
                .stroke(PuboColors.navy, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(PuboColors.navy.opacity(0.15))
                .offset(x: 2.5, y: 2.5)
        )
    }
    
    private var luggageListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bag")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                Text("行李清單")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(PuboColors.navy)
                    .tracking(2)
                    .textCase(.uppercase)
            }
            
            HStack(spacing: 12) {
                // Circular Plus Button
                Button(action: {
                    // Action for add luggage item
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold)) // Smaller icon
                        .foregroundColor(PuboColors.navy)
                        .frame(width: 24, height: 24) // Smaller frame
                        .background(Color.clear)
                        .overlay(Circle().stroke(PuboColors.navy, lineWidth: 2))
                }
                
                Text("快點添加你的出遊物品吧這樣子")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(40)
        .overlay(
            RoundedRectangle(cornerRadius: 40)
                .stroke(PuboColors.navy, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(PuboColors.navy.opacity(0.15))
                .offset(x: 2.5, y: 2.5)
        )
    }
    
    // MARK: - 每日景點列表
    private var dailySpotListContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                VStack(spacing: 0) {
                    spotRow(spot: spot, index: index)
                    
                    // 備忘錄展開區域
                    if activeMemoId == spot.id, let notes = spot.notes, !notes.isEmpty {
                        memoSection(notes: notes, time: spot.time)
                    }
                    
                    // 交通資訊（非最後一個景點才顯示）
                    if index < spots.count - 1 {
                        transportInfoRow(for: spot)
                    }
                }
            }

            
            // Add Spot Button (Dashed Border)
            Button(action: {
                onAddClick()
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 24, height: 24)
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                    Text("添加行程")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.gray.opacity(0.3))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundColor(.gray.opacity(0.3))
                )
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    private func spotRow(spot: ItinerarySpot, index: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // 景點圖片
            AsyncImage(url: URL(string: spot.image)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15))
            }
            .frame(width: 64, height: 64)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            
            // 景點資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.category == .food ? "美食" : "景點")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Color(hex: "023B7E"))
                    .tracking(2)
                    .textCase(.uppercase)
                
                Text(verbatim: "\(index + 1). \(spot.name)")
                    .font(.system(size: 17, weight: .bold)) // Less bold (black -> bold)
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .textCase(.uppercase)
                
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text("停留" + (spot.subLabel ?? ""))
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                }
            }
            
            
            Spacer()
            
            // 刪除按鈕 (地圖內快速操作)
            Button(action: {
                tripManager.deleteSpot(tripId: trip.id, dayIndex: selectedDayIndex, spotId: spot.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.6))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // 勾勾按鈕（點擊切換備忘錄）
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    activeMemoId = activeMemoId == spot.id ? nil : spot.id
                }
            }) {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.1))
                            .offset(x: 2, y: 2)
                    )
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            focusOnSpot(spot)
        }
    }
    
    // MARK: - 備忘錄區塊（與規劃模式相同樣式）
    private func memoSection(notes: [String], time: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(PuboColors.yellow)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(PuboColors.navy)
                    Text(time)
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(PuboColors.navy)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                .opacity(0.4)
                
                Text(notes.joined(separator: "、"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(PuboColors.navy.opacity(0.7))
                    .lineSpacing(4)
            }
            .padding(12)
            
            Spacer()
        }
        .background(Color(hex: "FFF9E1"))
        .cornerRadius(12, corners: [.topRight, .bottomRight])
        .padding(.leading, 42)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func transportInfoRow(for spot: ItinerarySpot) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 32)
            
            VStack {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundColor(Color.gray.opacity(0.15))
                    .frame(width: 1.5, height: 32)
            }
            .padding(.leading, 0)
            
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.3))
                Text(verbatim: "10分鐘 2.4公里")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.gray.opacity(0.3))
                    .textCase(.uppercase)
            }
            .padding(.leading, 16)
            
            Spacer()
        }
    }
}
