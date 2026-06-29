import SwiftUI
import Foundation

struct ShareColors {
    static let navy = Color(hex: "0C51A2")
    static let yellow = Color(hex: "FFCF5E")
    static let red = Color(hex: "F54E20")
    static let beige = Color(hex: "FDFAEE")
    static let background = Color(hex: "FEF9F6")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum ShareState {
    case loading
    case placePreview(ResolvedMapPlace)
    case tripSelection(ResolvedMapPlace)
    case creatingNewTrip(ResolvedMapPlace)
    case success(String)
    case successPrompt
    case error(String)
}

struct ShareExtensionView: View {
    let onClose: () -> Void
    let onExtractURL: (@escaping (URL?, String?) -> Void) -> Void
    let onOpenApp: () -> Void
    
    @State private var state: ShareState = .loading
    @State private var isVisible = false
    @State private var isHeartFilled = false
    @State private var sheetOffset: CGFloat = 500  // start off-screen below
    
    @State private var tripSummaries: [TripSummary] = []
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background — tap to dismiss
            Color.black.opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    hideAndClose()
                }
                .animation(.easeInOut(duration: 0.25), value: isVisible)
            
            // Bottom Sheet Card — slides up from bottom
            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                
                sheetContent
            }
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .offset(y: sheetOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sheetOffset)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            loadTripSummaries()
            // Slide in from bottom
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    sheetOffset = 0
                    isVisible = true
                }
            }
            // Extract URL and process
            onExtractURL { url, preExtractedName in
                guard let url = url else {
                    DispatchQueue.main.async {
                        self.state = .error("無法讀取網址")
                    }
                    return
                }
                
                let urlString = url.absoluteString.lowercased()
                let isGoogleMaps = urlString.contains("google.com/maps") || urlString.contains("maps.app.goo.gl")
                
                if isGoogleMaps {
                    GoogleMapsURLResolver.shared.resolve(url: url, preExtractedName: preExtractedName) { place in
                        if let place = place {
                            self.state = .placePreview(place)
                        } else {
                            self.state = .error("無法解析景點資訊，請確認網路狀態後重試，或於 App 中手動新增。")
                        }
                    }
                } else {
                    // General URL (Instagram, TikTok, etc.)
                    saveGeneralURL(url: url.absoluteString)
                    self.state = .successPrompt
                }
            }
        }
    }
    
    private var sheetContent: some View {
        VStack(spacing: 0) {
            switch state {
            case .loading:
                ProgressView("讀取中...")
                    .padding(40)
            case .error(let msg):
                VStack(spacing: 20) {
                    Text(msg)
                        .foregroundColor(.red)
                        .padding(.horizontal, 40)
                    
                    Button(action: hideAndClose) {
                        Text("取消")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 40)
            case .placePreview(let place):
                placePreview(place)
            case .tripSelection(let place):
                tripSelection(place)
            case .creatingNewTrip(let place):
                createNewTrip(place)
            case .success(let msg):
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 40))
                        .padding(.bottom, 10)
                    Text(msg)
                        .font(.headline)
                }
                .padding(40)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        hideAndClose()
                    }
                }
            case .successPrompt:
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 40))
                    
                    Text("分享成功！")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Button(action: hideAndClose) {
                            Text("稍後查看")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(25)
                        }
                        
                        Button(action: {
                            onOpenApp()
                            hideAndClose()
                        }) {
                            Text("現在查看")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(ShareColors.navy)
                                .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 30)
            }
        }
    }
    
    private var backgroundColor: Color {
        if case .tripSelection = state {
            return ShareColors.background
        }
        return Color.white
    }
    
    // MARK: - Place Preview UI
    private func placePreview(_ place: ResolvedMapPlace) -> some View {
        VStack(spacing: 16) {
            Text("匯入景點")
                .font(.headline)
                .foregroundColor(.black)
            
            Divider()
            
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ShareColors.navy)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "mappin")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ShareColors.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .lineLimit(2)
                    
                    // Show address extracted from URL if available
                    if let addr = place.address, !addr.isEmpty {
                        Text(addr)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    } else {
                        Text("★ -- · 景點")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    isHeartFilled = true
                    saveAction(place: place, destination: .library)
                }) {
                    Image(systemName: isHeartFilled ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isHeartFilled ? ShareColors.red : .gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    state = .tripSelection(place)
                }
            }) {
                Text("＋ 加入行程")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(ShareColors.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ShareColors.beige)
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(ShareColors.red, lineWidth: 2)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            Button(action: hideAndClose) {
                Text("取消")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Trip Selection UI
    @State private var expandedTripId: String? = nil
    
    private func tripSelection(_ place: ResolvedMapPlace) -> some View {
        // Use a VStack with fixed bottom section so "建立新行程" and "取消" are always visible
        VStack(spacing: 0) {
            // Title
            Text("選擇要加入的行程")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ShareColors.navy)
                .padding(.top, 10)
                .padding(.bottom, 16)
            
            // Scrollable trip list — constrained max height so buttons below are never hidden
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(tripSummaries, id: \.id) { trip in
                        tripAccordionCard(trip: trip, place: place)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 450)
            
            Divider()
            
            // Fixed bottom action buttons — always visible, never overlapped
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        state = .creatingNewTrip(place)
                    }
                }) {
                    Text("＋ 建立新行程")
                        .font(.headline)
                        .foregroundColor(ShareColors.navy)
                }
                
                Button(action: hideAndClose) {
                    Text("取消")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            if expandedTripId == nil {
                expandedTripId = tripSummaries.first?.id
            }
        }
    }
    
    private func tripAccordionCard(trip: TripSummary, place: ResolvedMapPlace) -> some View {
        let isExpanded = expandedTripId == trip.id
        
        return VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    expandedTripId = isExpanded ? nil : trip.id
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("\(trip.startDate ?? "未定") · \(trip.totalDays) 天" + (trip.isCollaborative ? " · 👥 共編" : ""))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ShareColors.navy)
                        .fontWeight(.bold)
                }
                .padding(16)
                .background(ShareColors.beige)
            }
            
            if isExpanded {
                let bestDay = recommendBestDay(for: place, in: trip)
                
                VStack(spacing: 0) {
                    ForEach(Array(trip.days.enumerated()), id: \.offset) { index, day in
                        Divider()
                        Button(action: {
                            saveAction(place: place, destination: .itinerary, tripId: trip.id, dayIndex: index)
                            withAnimation {
                                state = .success("成功加入行程！")
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.dayLabel)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                    Text("\(day.dateString) · \(day.spotCount) 個景點")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                if index == bestDay {
                                    Text("👍 加在這天最順")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(ShareColors.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ShareColors.beige)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(ShareColors.red, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(ShareColors.beige)
                        }
                    }
                }
            }
        }
        .background(ShareColors.beige)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ShareColors.navy, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Create New Trip
    @State private var newTripName: String = ""
    private func createNewTrip(_ place: ResolvedMapPlace) -> some View {
        VStack(spacing: 20) {
            Text("建立新行程")
                .font(.headline)
                .foregroundColor(.black)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("行程名稱")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("輸入行程名稱...", text: $newTripName)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ShareColors.navy)
                Text("「\(place.name)」將自動加入第 1 天")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                guard !newTripName.isEmpty else { return }
                saveAction(place: place, destination: .newTrip, newTripName: newTripName)
                withAnimation {
                    state = .success("建立成功！")
                }
            }) {
                Text("建立並加入")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(newTripName.isEmpty ? Color.gray : ShareColors.navy)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 20)
            .disabled(newTripName.isEmpty)
            .padding(.bottom, 8)
            
            Button(action: hideAndClose) {
                Text("取消")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helper Methods
    private func hideAndClose() {
        withAnimation(.easeIn(duration: 0.25)) {
            sheetOffset = 500
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onClose()
        }
    }
    
    private func loadTripSummaries() {
        if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo"),
           let data = userDefaults.data(forKey: "trip_summaries"),
           let decoded = try? JSONDecoder().decode([TripSummary].self, from: data) {
            self.tripSummaries = decoded
        } else {
            self.tripSummaries = []
        }
    }
    
    private func saveGeneralURL(url: String) {
        if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo") {
            var actions: [PendingPlaceAction] = []
            if let data = userDefaults.data(forKey: "pending_place_actions"),
               let decoded = try? JSONDecoder().decode([PendingPlaceAction].self, from: data) {
                actions = decoded
            }
            
            let action = PendingPlaceAction(
                placeName: "共享連結",
                latitude: nil,
                longitude: nil,
                address: nil,
                googleMapsUrl: url,
                destination: .library,
                tripId: nil,
                dayIndex: nil,
                newTripName: nil,
                createdAt: Date()
            )
            
            actions.append(action)
            if let encoded = try? JSONEncoder().encode(actions) {
                userDefaults.set(encoded, forKey: "pending_place_actions")
            }
        }
    }
    
    private func saveAction(place: ResolvedMapPlace, destination: PlaceDestination, tripId: String? = nil, dayIndex: Int? = nil, newTripName: String? = nil) {
        let action = PendingPlaceAction(
            placeName: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address,
            googleMapsUrl: place.finalURL ?? place.originalURL,
            destination: destination,
            tripId: tripId,
            dayIndex: dayIndex,
            newTripName: newTripName,
            createdAt: Date()
        )
        
        if let userDefaults = UserDefaults(suiteName: "group.com.anita.Pubo") {
            var actions: [PendingPlaceAction] = []
            if let data = userDefaults.data(forKey: "pending_place_actions"),
               let decoded = try? JSONDecoder().decode([PendingPlaceAction].self, from: data) {
                actions = decoded
            }
            actions.append(action)
            if let encoded = try? JSONEncoder().encode(actions) {
                userDefaults.set(encoded, forKey: "pending_place_actions")
            }
        }
    }
    
    private func recommendBestDay(for newPlace: ResolvedMapPlace, in trip: TripSummary) -> Int? {
        guard let lat = newPlace.latitude, let lng = newPlace.longitude else { return nil }
        var minDistance: Double = .infinity
        var bestIndex: Int? = nil
        
        for (index, day) in trip.days.enumerated() {
            guard !day.spotCoordinates.isEmpty else { continue }
            let distances = day.spotCoordinates.map { spot in
                sqrt(pow(spot.latitude - lat, 2) + pow(spot.longitude - lng, 2))
            }
            let avg = distances.reduce(0, +) / Double(distances.count)
            if avg < minDistance {
                minDistance = avg
                bestIndex = index
            }
        }
        return bestIndex
    }
}

// MARK: - RoundedCorner Shape & View Extension
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
