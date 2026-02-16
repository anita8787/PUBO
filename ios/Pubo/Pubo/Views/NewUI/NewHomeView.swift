import SwiftUI

struct NewHomeView: View {
    @State private var activeTab = 1 // 0: Map, 1: Home, 2: Itinerary, 3: Profile
    @EnvironmentObject var tripManager: TripManager
    
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
                        onAddClick: { withAnimation { showingAddModal = true } }
                    )
                case 3:
                    // Profile Tab
                    ProfileView(onBack: { activeTab = 1 })
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
                    withAnimation { showingAddModal = true }
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
                .zIndex(100) // Ensure on top
            }
        }
        .ignoresSafeArea(.keyboard) // 整個 ZStack 不跟隨鍵盤移動
        .ignoresSafeArea(.container, edges: .bottom)
        // Removed Sheet
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
                            // Profile Action
                            print("Profile Tapped")
                        }) {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .background(Circle().fill(Color.gray))
                                .frame(width: 64, height: 64)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .overlay(
                                    Image(systemName: "person.fill") // Placeholder Avatar
                                        .foregroundColor(.white)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text("HI! NITA")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(PuboColors.navy)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        CircleButton(icon: "magnifyingglass")
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
                                Text("MORE >")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(recommendations) { item in
                                        RecommendationCard(item: item)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8) // Shadow + clip space
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
                                
                                TripCardView(
                                    title: nearestTrip.title,
                                    date: nearestTrip.date,
                                    spotsCount: nearestTrip.spots,
                                    color: nearestTrip.color.rawValue
                                )
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
    var body: some View {
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
                    Text("台北").font(.system(size: 32, weight: .black)).foregroundColor(PuboColors.navy)
                    Text("TAIPEI").font(.system(size: 11, weight: .medium))
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
                    Text("BR719")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(PuboColors.navy.opacity(0.6))
                }
                .frame(maxWidth: 100)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("TO").font(.system(size: 9, weight: .bold)).foregroundColor(PuboColors.navy)
                    Text("大阪").font(.system(size: 32, weight: .black)).foregroundColor(PuboColors.navy)
                    Text("OSAKA").font(.system(size: 11, weight: .medium))
                }
            }
            .padding(24)
            .background(Color.white)
            
            // Footer Info
            HStack {
                VStack(alignment: .leading) { Text("DATE").font(.caption2).bold(); Text("02.20 THU").font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("TIME").font(.caption2).bold(); Text("12:30 PM").font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("SEAT").font(.caption2).bold(); Text("12A").font(.caption) }
                Spacer()
                VStack(alignment: .leading) { Text("GATE").font(.caption2).bold(); Text("B7").font(.caption) }
            }
            .foregroundColor(PuboColors.navy)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
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
    }
}

struct RecommendationCard: View {
    let item: Recommendation
    var body: some View {
        VStack(spacing: 0) {
            // Image Area — 2/3 of total height
            GeometryReader { geo in
                AsyncImage(url: URL(string: item.image)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(height: 120) // 2/3 of ~180 total
            .clipped()
            .overlay(
                Image(systemName: "heart")
                    .foregroundColor(PuboColors.red)
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PuboColors.red, lineWidth: 1.5))
                    .padding(8),
                alignment: .topTrailing
            )
            
            // Text Area — 1/3 of total, full-width white bg
            VStack(alignment: .leading, spacing: 4) {
                Text(item.category)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(PuboColors.navy, lineWidth: 1))
                
                Text(item.name)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(PuboColors.yellow)
                    Text("\(String(format: "%.1f", item.rating))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
        .frame(width: 140)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(PuboColors.red, lineWidth: 2.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// Data Models for View
// Trip and other models are now in Models.swift

struct Recommendation: Identifiable {
    let id: String
    let category: String
    let name: String
    let rating: Double
    let image: String
}

// Preview
struct NewHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NewHomeView()
            .environmentObject(TripManager())
    }
}
