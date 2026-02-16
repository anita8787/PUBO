import SwiftUI
import MapKit

struct TripMapPlanningView: View {
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
    

    
    var body: some View {
        ZStack(alignment: .bottom) {
            // === 地圖圖層（全螢幕背景）===
            mapLayer
            
            // === 浮動頂部控制按鈕 ===
            floatingHeaderLayer
            
            // === 底部面板 ===
            bottomSheetPanel
            
            // === 底部面板 ===
            bottomSheetPanel
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
            
            // 路線圖 (Polylines)
            if spots.count >= 2 {
                MapPolyline(coordinates: spots.compactMap { spot in
                    if let coord = spot.coordinate {
                        return CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.long)
                    }
                    return nil
                })
                .stroke(Color(hex: "FFC649"), lineWidth: 4) // 黃色路徑
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
        .onAppear {
            updateMapToFitSpots()
        }
        .onChange(of: selectedDayIndex) {
            updateMapToFitSpots()
        }
        .onChange(of: spots.count) {
            updateMapToFitSpots()
        }
    }
    
    private func updateMapToFitSpots() {
        guard !spots.isEmpty else { return }
        
        let coords = spots.compactMap { spot -> CLLocationCoordinate2D? in
            guard let c = spot.coordinate else { return nil }
            return CLLocationCoordinate2D(latitude: c.lat, longitude: c.long)
        }
        
        guard !coords.isEmpty else { return }
        
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
        
        let deltaLat = max(0.015, (maxLat - minLat) * 1.8)
        let deltaLon = max(0.015, (maxLon - minLon) * 1.8)
        
        let span = MKCoordinateSpan(
            latitudeDelta: deltaLat,
            longitudeDelta: deltaLon
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    // MARK: - 定位使用者
    
    // MARK: - 地圖標記
    @ViewBuilder
    private func mapMarker(for spot: ItinerarySpot, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(PuboColors.red)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - 浮動頂部控制按鈕
    private var floatingHeaderLayer: some View {
        VStack {
            HStack {
                // 返回按鈕
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

                Spacer()

                // 分享 + 設定按鈕
                HStack(spacing: 12) {
                    headerCircleButton(icon: "square.and.arrow.up", action: onShareClick)
                    headerCircleButton(icon: "gearshape", action: {})
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
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
        .frame(height: isConcise ? 280 : ScreenUtils.height * 0.58)
        .background(Color(hex: "FDFAEE"))
        .clipShape(RoundedCorner(radius: 40, corners: [.topLeft, .topRight]))
        .overlay(
            RoundedCorner(radius: 40, corners: [.topLeft, .topRight])
                .stroke(Color.black, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: -10)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isConcise)
        .id("day-\(selectedDayIndex)-\(spots.count)") // Force re-render when day or count changes
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
                Button(action: { mapSubMode = .overview }) {
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
        .frame(height: 200) // 固定高度以適應版面
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
            
            Spacer().frame(height: 12) // Smaller fixed spacer instead of flexible one
            
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
                        .frame(width: 28, height: 28) // Reduced from 36
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .black)) // Slightly smaller font
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
                        transportInfoRow
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
    
    private var transportInfoRow: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 32)
            
            VStack {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundColor(Color.gray.opacity(0.2))
                    .frame(width: 2, height: 32)
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
