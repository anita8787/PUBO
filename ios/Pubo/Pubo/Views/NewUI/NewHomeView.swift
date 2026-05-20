import SwiftUI
import Combine

struct NewHomeView: View {
    @State private var activeTab = 1 // 0: Map, 1: Home, 2: Itinerary, 3: Profile
    @EnvironmentObject var tripManager: TripManager
    @EnvironmentObject var dataService: DataService
    @AppStorage("userGender") private var userGender: String = "girl" // "girl" or "boy"
    
    // Mock Data
    let recommendations = [
        Recommendation(id: "r1", category: "景點", name: "京都古都巡禮", rating: 4.8, image: "https://images.unsplash.com/photo-1545569341-9eb8b30979d9?q=80&w=400&auto=format&fit=crop"),
        Recommendation(id: "r2", category: "美食", name: "大阪道頓堀拉麵", rating: 4.5, image: "https://images.unsplash.com/photo-1576675466969-38eeae4b41f6?q=80&w=400&auto=format&fit=crop"),
        Recommendation(id: "r3", category: "購物", name: "銀座豪華購物區", rating: 4.3, image: "https://images.unsplash.com/photo-1555617766-c94804975da3?q=80&w=400&auto=format&fit=crop"),
    ]
    
    // Trips are now from tripManager
    
    let posts = [
        Post(id: "1", author: "User1", avatar: "", content: "Content1", image: "https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=1740&auto=format&fit=crop", platform: .instagram, tags: ["富士山"]),
        Post(id: "2", author: "User2", avatar: "", content: "Content2", image: "https://images.unsplash.com/photo-1570459027562-4a916cc6113f?q=80&w=1587&auto=format&fit=crop", platform: .instagram, tags: ["豪德寺"]),
        Post(id: "3", author: "User3", avatar: "", content: "Content3", image: "https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80&w=1740&auto=format&fit=crop", platform: .instagram, tags: ["澀谷"]),
    ]

    @State private var showingAddModal = false
    @State private var isTabBarHidden = false
    @State private var selectedCuratedPost: CuratedPost? = nil
    @State private var showingAvatarSelection = false
    @State private var showingAllCuratedPosts = false

    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Main Content Layer
            Group {
                switch activeTab {
                case 0:
                    // Map Tab
                    MapView(onBack: { activeTab = 1 })
                case 1:
                    // Home Tab
                    homeContent
                case 2:
                    // Itinerary Tab
                    ItineraryView(
                        isTabBarHidden: $isTabBarHidden,
                        onBack: { activeTab = 1 },
                        onAddClick: { withAnimation(.easeInOut(duration: 0.2)) { showingAddModal = true } }
                    )
                case 3:
                    // Profile Tab
                    ProfileView(
                        onBack: { activeTab = 1 },
                        onGoToCollection: {
                            activeTab = 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                NotificationCenter.default.post(name: NSNotification.Name("TriggerLibraryPullUp"), object: nil)
                            }
                        }
                    )
                default:
                    homeContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Library Sheet (Visible on Home Tab)
            if activeTab == 1 {
                DraggableLibraryView()
                    .zIndex(10) // Below Tab Bar but above Home Content
            }
            
            // Tab Bar Layer - Hidden when on Map (Tab 0) or Map Mode in Itinerary
            if activeTab != 0 && !isTabBarHidden {
                CustomTabBar(activeTab: $activeTab, onAddClick: {
                    withAnimation(.easeInOut(duration: 0.2)) { showingAddModal = true }
                })
                .zIndex(20)
            }
            
            // Plus Modal Overlay
            if showingAddModal {
                PlusModalView(
                    isPresented: $showingAddModal,
                    onAdd: { _ in },
                    onOpenLibrary: { activeTab = 2 },
                    onCustom: { }
                )
                .transition(.opacity)
                .zIndex(100) // Ensure on top
            }
        }
        .ignoresSafeArea(.keyboard) // 整個 ZStack 不跟隨鍵盤移動
        .ignoresSafeArea(.container, edges: .bottom)
        .environmentObject(tripManager)
        .overlay {
            if showingAvatarSelection {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { showingAvatarSelection = false }
                    
                    AvatarSelectionModal(
                        selectedGender: $userGender,
                        onConfirm: { showingAvatarSelection = false },
                        onCancel: { showingAvatarSelection = false }
                    )
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(1000)
            }
        }
        .onAppear {
            tripManager.refreshTrips()
            dataService.fetchCuratedPosts()
        }
        .sheet(item: $selectedCuratedPost) { post in
            CuratedPostDetailView(post: post) { selectedSpots in
                tripManager.importCuratedPost(post, selectedSpots: selectedSpots)
                selectedCuratedPost = nil
            } onCancel: {
                selectedCuratedPost = nil
            }
        }
        .fullScreenCover(isPresented: $showingAllCuratedPosts) {
            AllCuratedPostsView(selectedCuratedPost: $selectedCuratedPost)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusMapOnPlace"))) { notif in
            if let place = notif.object as? SDPlace {
                self.activeTab = 0
                tripManager.focusPlaceFromLibrary = place
            }
        }
    }
    
    // Extracted Home Content to keep body clean
    var homeContent: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F5F5F5").ignoresSafeArea() // Background
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAvatarSelection = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 68, height: 68)
                                    .overlay(Circle().stroke(PuboColors.navy, lineWidth: 2.5))
                                    .retroShadow(color: .black.opacity(0.1), offset: 3)
                                
                                Image(userGender)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("HI! NITA")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(PuboColors.navy)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        CircleButton(icon: "person", action: { activeTab = 3 })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // 1. Boarding Pass (Mock)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("即將出發")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(PuboColors.navy)
                                .padding(.horizontal, 24)
                            
                            BoardingPassView()
                                .padding(.horizontal, 24)
                        }
                        
                        // 2. 推薦行程
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("推薦行程")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                Spacer()
                                Button(action: { showingAllCuratedPosts = true }) {
                                    Text("MORE >")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    if dataService.curatedPosts.isEmpty {
                                        // Show skeleton or placeholder
                                        ForEach(0..<3) { _ in
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color.gray.opacity(0.1))
                                                .frame(width: 140, height: 180)
                                        }
                                    } else {
                                        ForEach(dataService.curatedPosts) { post in
                                            RecommendationCard(post: post)
                                                .onTapGesture {
                                                    selectedCuratedPost = post
                                                }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // 3. 即將到來 — show only nearest upcoming trip
                        if let nearestTrip = tripManager.trips.first {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("即將到來")
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(PuboColors.navy)
                                    Image(systemName: "sparkles")
                                        .foregroundColor(PuboColors.yellow)
                                }
                                .padding(.horizontal, 24)
                                
                                Button(action: {
                                    tripManager.selectedTripId = nearestTrip.id
                                    activeTab = 2
                                }) {
                                    TripCardView(
                                        title: nearestTrip.title,
                                        date: nearestTrip.date,
                                        spotsCount: nearestTrip.spots,
                                        color: nearestTrip.color.rawValue,
                                        tripId: nearestTrip.id,
                                        onShareTap: {
                                            shareTrip(nearestTrip)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // 4. 探索
                        VStack(alignment: .leading, spacing: 16) {
                            Text("探索")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(PuboColors.navy)
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(posts) { post in
                                        ExploreCardView(imageUrl: post.image, tag: post.tags.first ?? "")
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer().frame(height: 120) // Bottom structure for tab bar
                    }
                }
            }
        }
    }
    
    private func shareTrip(_ trip: Trip) {
        let inviteCode = trip.inviteCode ?? ""
        let text = "快來和我一起在 Pubo 規劃「\(trip.title)」！\n使用 Pubo App 輸入邀請碼加入：\(inviteCode)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}

// Sub-components used in Home
struct CircleButton: View {
    let icon: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(PuboColors.navy)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(PuboColors.navy, lineWidth: 2)
                )
        }
    }
}

struct BoardingPassView: View {
    @AppStorage("bpFromCity") private var fromCity: String = "台北"
    @AppStorage("bpFromCode") private var fromCode: String = "TAIPEI"
    @AppStorage("bpToCity") private var toCity: String = "大阪"
    @AppStorage("bpToCode") private var toCode: String = "OSAKA"
    @AppStorage("bpFlightNumber") private var flightNumber: String = "BR719"
    @AppStorage("bpDate") private var date: String = "02.20 THU"
    @AppStorage("bpTime") private var time: String = "12:30 PM"
    @AppStorage("bpSeat") private var seat: String = "12A"
    @AppStorage("bpGate") private var gate: String = "B7"
    
    @State private var isEditing = false
    
    var body: some View {
        Button(action: { isEditing = true }) {
            VStack(spacing: 0) {
            // Header
            HStack {
                Text("BOARDING PASS")
                Spacer()
                Text("CONFIRMED")
            }
            .font(.system(size: 10, weight: .black))
            .foregroundColor(PuboColors.navy)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(PuboColors.yellow)
            
            // Content — cities with connecting blue line
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text("FROM").font(.system(size: 9, weight: .bold)).foregroundColor(PuboColors.navy)
                    Text(fromCity).font(.system(size: 32, weight: .black)).foregroundColor(PuboColors.navy)
                    Text(fromCode).font(.system(size: 11, weight: .medium))
                }
                
                Spacer()
                
                // Blue connecting line with airplane
                VStack(spacing: 2) {
                    ZStack {
                        // Dashed blue line
                        Rectangle()
                            .fill(PuboColors.navy)
                            .frame(height: 2)
                        
                        // Airplane centered on line
                        Image(systemName: "airplane")
                            .font(.system(size: 16))
                            .foregroundColor(PuboColors.navy)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                            )
                    }
                    
                    // Flight number below airplane
                    Text(flightNumber)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(PuboColors.navy.opacity(0.6))
                }
                .frame(maxWidth: 100)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("TO").font(.system(size: 9, weight: .bold)).foregroundColor(PuboColors.navy)
                    Text(toCity).font(.system(size: 32, weight: .black)).foregroundColor(PuboColors.navy)
                    Text(toCode).font(.system(size: 11, weight: .medium))
                }
            }
            .padding(24)
            .background(Color.white)
            
            // Footer Info
            HStack {
                VStack(alignment: .leading) { Text("DATE").font(.caption2).bold(); Text(date).font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("TIME").font(.caption2).bold(); Text(time).font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("SEAT").font(.caption2).bold(); Text(seat).font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("GATE").font(.caption2).bold(); Text(gate).font(.caption) }
            }
            .foregroundColor(PuboColors.navy)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(PuboColors.blue)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(PuboColors.navy.opacity(0.3))
                    .padding(.top, -1),
                alignment: .top
            )
        }
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(PuboColors.navy, lineWidth: 2.5)
        )
        .retroShadow(color: .black.opacity(0.1))
        } // End of Button
        .buttonStyle(.plain)
        .sheet(isPresented: $isEditing) {
            BoardingPassEditSheet()
        }
    }
}

struct BoardingPassEditSheet: View {
    @AppStorage("bpFromCity") private var fromCity: String = "台北"
    @AppStorage("bpFromCode") private var fromCode: String = "TAIPEI"
    @AppStorage("bpToCity") private var toCity: String = "大阪"
    @AppStorage("bpToCode") private var toCode: String = "OSAKA"
    @AppStorage("bpFlightNumber") private var flightNumber: String = "BR719"
    @AppStorage("bpDate") private var date: String = "02.20 THU"
    @AppStorage("bpTime") private var time: String = "12:30 PM"
    @AppStorage("bpSeat") private var seat: String = "12A"
    @AppStorage("bpGate") private var gate: String = "B7"
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // Overall card background is white
            
            VStack(spacing: 0) {
                // Custom Header Bar (Flat Teal)
                VStack(spacing: 0) {
                    ZStack {
                        // Centered Title
                        Text("機票資訊")
                            .font(.system(size: 19, weight: .bold)) // Font size increased by 2
                            .foregroundColor(.white)
                            
                        HStack {
                            Button(action: { dismiss() }) {
                                Image("x")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                            }
                            .buttonStyle(CloseButtonStyle())
                            
                            Spacer()
                            
                            Button(action: { dismiss() }) {
                                Text("保存")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(PuboColors.navy) // Navy text
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(PuboColors.navy, lineWidth: 1) // Navy border
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(hex: "2AA5A0")) // Teal top Background
                    
                    // Red divider line
                    Rectangle()
                        .fill(PuboColors.red)
                        .frame(height: 2)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 出發 / From
                        VStack(alignment: .leading, spacing: 6) {
                            Text("出發 / From")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            
                            TextField("出發城市", text: $fromCity)
                                .font(.system(size: 18, weight: .bold))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PuboColors.red, lineWidth: 1)
                                )
                        }
                        
                        // 目的地 / To
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目的地 / To")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            
                            TextField("目的城市", text: $toCity)
                                .font(.system(size: 18, weight: .bold))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PuboColors.red, lineWidth: 1)
                                )
                        }
                        
                        // 航班詳細資訊 / Flight Details
                        VStack(alignment: .leading, spacing: 6) {
                            Text("航班詳細資訊 / Flight Details")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                            
                            VStack(spacing: 0) {
                                // 班機
                                flightDetailRow(label: "班機", value: $flightNumber)
                                Divider().padding(.horizontal, 16)
                                
                                // 出發日
                                flightDetailRow(label: "出發日", value: $date)
                                Divider().padding(.horizontal, 16)
                                
                                // 時間
                                flightDetailRow(label: "時間", value: $time)
                                Divider().padding(.horizontal, 16)
                                
                                // 座位
                                flightDetailRow(label: "座位", value: $seat)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(PuboColors.red, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 40)
                }
            }
        }
        // 🚀 TRUE OPEN-BOTTOM DRAWER (Matching Map Card)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .overlay(
            SheetBorder(radius: 32)
                .inset(by: 1.5)
                .stroke(PuboColors.red, lineWidth: 3)
        )
        .ignoresSafeArea(.all, edges: .bottom)
        .presentationBackground(.clear)
        .presentationDetents([.fraction(0.65)]) // Height lowered
    }
    
    private func flightDetailRow(label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            
            TextField(label, text: value)
                .font(.system(size: 18, weight: .bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RecommendationCard: View {
    let post: CuratedPost
    var isFullWidth: Bool = false
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var tripManager: TripManager
    
    var isCollected: Bool {
        guard let url = post.sourceUrl else { return false }
        return dataService.isPostCollected(url: url, title: post.title)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Area
            let sanitizedUrl = (post.coverImageUrl ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            AsyncImage(url: URL(string: sanitizedUrl)) { phase in
                if let image = phase.image {
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    // Fallback for load error
                    Color.gray.opacity(0.15)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 14))
                                Text("載入失敗")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.gray)
                        )
                } else {
                    // Loading state
                    Color.gray.opacity(0.1)
                        .overlay(ProgressView().scaleEffect(0.5))
                }
            }
            .frame(width: isFullWidth ? nil : 140)
            .frame(maxWidth: isFullWidth ? .infinity : 140)
            .frame(height: isFullWidth ? 200 : 120)
            .background(Color.gray.opacity(0.05))
            .clipped()
            .overlay(
                Button(action: {
                    toggleCollection()
                }) {
                    Image(systemName: isCollected ? "heart.fill" : "heart")
                        .foregroundColor(PuboColors.red)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PuboColors.red, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding(8),
                alignment: .topTrailing
            )
            
            // Text Area
            VStack(alignment: .leading, spacing: 4) {
                let displayCountry = (post.country ?? "").isEmpty ? "推薦" : post.country!
                Text(displayCountry)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(PuboColors.navy, lineWidth: 1))
                
                Text(post.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 3) {
                    Text(verbatim: "by \(post.author ?? "旅遊達人")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(verbatim: "\(post.spotCount ?? 0) 個景點")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(height: 76, alignment: .topLeading)
            .frame(maxWidth: isFullWidth ? .infinity : 140)
            .background(Color.white)
        }
        .frame(width: isFullWidth ? nil : 140)
        .frame(maxWidth: isFullWidth ? .infinity : 140)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PuboColors.red, lineWidth: 2.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    @State private var isProcessingToggle = false
    
    private func toggleCollection() {
        guard let url = post.sourceUrl, !isProcessingToggle else { return }
        
        isProcessingToggle = true
        let currentState = isCollected
        
        Task {
            if currentState {
                await dataService.removeFromCollection(url: url)
            } else {
                // 一鍵收藏
                let spots = post.spots ?? []
                tripManager.importCuratedPostToLibrary(post, selectedSpots: spots)
            }
            
            // Allow clicking again after a short delay
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            await MainActor.run {
                isProcessingToggle = false
            }
        }
    }
}

// MARK: - Avatar Selection Modal
struct AvatarSelectionModal: View {
    @Binding var selectedGender: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    @State private var tempGender: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("選擇大頭貼")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(PuboColors.navy)
                .padding(.top, 10)
            
            HStack(spacing: 40) {
                // Girl Option
                avatarOption(gender: "girl", label: "女生")
                
                // Boy Option
                avatarOption(gender: "boy", label: "男生")
            }
            .padding(.horizontal, 20)
            
            // Confirm Button
            Button(action: {
                selectedGender = tempGender
                onConfirm()
            }) {
                Text("確認")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PuboColors.navy)
                    .cornerRadius(12)
                    .retroShadow(color: .black.opacity(0.2), offset: 3)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 10)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(PuboColors.navy, lineWidth: 3)
        )
        .padding(.horizontal, 40)
        .onAppear {
            tempGender = selectedGender
        }
    }
    
    private func avatarOption(gender: String, label: String) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                tempGender = gender
            }
        }) {
            VStack(spacing: 12) {
                Image(gender)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(tempGender == gender ? PuboColors.red : Color.gray.opacity(0.2), lineWidth: 3))
                    .background(Circle().fill(Color.white))
                    .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Radio Circle
                ZStack {
                    Circle()
                        .stroke(tempGender == gender ? PuboColors.red : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if tempGender == gender {
                        Circle()
                            .fill(PuboColors.red)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tempGender == gender ? PuboColors.red : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// Preview
struct NewHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NewHomeView()
            .environmentObject(TripManager())
            .environmentObject(DataService.shared)
    }
}
