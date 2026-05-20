import SwiftUI

struct CuratedPostDetailView: View {
    let post: CuratedPost
    var onImport: ([PlaceInfo]) -> Void
    var onCancel: () -> Void
    
    @State private var selectedPlaceIds: Set<String> = []
    
    init(post: CuratedPost, onImport: @escaping ([PlaceInfo]) -> Void, onCancel: @escaping () -> Void) {
        self.post = post
        self.onImport = onImport
        self.onCancel = onCancel
        // 預設全選
        let ids = post.spots?.compactMap { $0.placeId } ?? []
        self._selectedPlaceIds = State(initialValue: Set(ids))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navy Header
            ZStack {
                Text("靈感清單")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    Button(action: onCancel) {
                        Image("x")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(PuboColors.navy)
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Post Info Row
                    HStack(alignment: .bottom, spacing: 16) {
                        // Image with play button
                        ZStack(alignment: .bottomTrailing) {
                            if let urlStr = post.coverImageUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 140, height: 180)
                                            .cornerRadius(20)
                                            .clipped()
                                    } else {
                                        Color.gray.opacity(0.1)
                                            .frame(width: 140, height: 180)
                                            .cornerRadius(20)
                                            .overlay(ProgressView())
                                    }
                                }
                            } else {
                                Color.gray.opacity(0.1)
                                    .frame(width: 140, height: 180)
                                    .cornerRadius(20)
                                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
                            }
                            
                            // Play button icon - Click to Jump to IG
                            Button(action: {
                                if let urlStr = post.sourceUrl, let url = URL(string: urlStr) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .shadow(radius: 4)
                            }
                        }
                        
                        // Right side info (Instagram link + Title)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image("Instagram")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                
                                Text("Instagram")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                // Share Button - Click to share link
                                Button(action: {
                                    if let urlStr = post.sourceUrl {
                                        shareLink(urlStr)
                                    }
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text(post.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .lineLimit(4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Found spots Title
                    HStack(spacing: 8) {
                        Image("Star icon ") // Use the provided SVG icon
                            .resizable()
                            .frame(width: 28, height: 28)
                        Text("找到了\(post.spotCount ?? post.spots?.count ?? 0)個地點")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    // Spots List Cards
                    VStack(spacing: 16) {
                        if let spots = post.spots {
                            ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                                let spotId = spot.placeId ?? "\(spot.name ?? "unknown")_\(index)"
                                HStack(spacing: 16) {
                                    Image(systemName: selectedPlaceIds.contains(spotId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedPlaceIds.contains(spotId) ? PuboColors.navy : .gray.opacity(0.3))
                                        .font(.system(size: 24))
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(spot.name ?? "未知地點")
                                            .font(.system(size: 16, weight: .black))
                                            .foregroundColor(PuboColors.navy)
                                        
                                        HStack(spacing: 8) {
                                            if let category = spot.category {
                                                Text(category)
                                                    .font(.system(size: 11, weight: .black))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(PuboColors.cardOrange)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if let rating = spot.rating, rating > 0 {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "star.fill")
                                                        .foregroundColor(PuboColors.cardOrange) // Or yellow
                                                        .font(.system(size: 10))
                                                    Text(String(format: "%.1f", rating))
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        
                                        if let address = spot.address {
                                            HStack(alignment: .top, spacing: 4) {
                                                Image(systemName: "mappin.and.ellipse")
                                                    .font(.system(size: 12))
                                                Text(address)
                                                    .font(.system(size: 12))
                                                    .lineLimit(2)
                                            }
                                            .foregroundColor(.gray.opacity(0.8))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(PuboColors.navy.opacity(0.3), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(spotId)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.white)
            
            // Bottom Import button
            VStack(spacing: 0) {
                Divider()
                Button(action: {
                    let selected = post.spots?.filter { selectedPlaceIds.contains($0.placeId ?? "") } ?? []
                    onImport(selected)
                }) {
                    HStack {
                        Image(systemName: "plus.square.fill")
                        Text("加入收藏庫 (\(selectedPlaceIds.count, specifier: "%d"))")
                    }
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedPlaceIds.isEmpty ? Color.gray : PuboColors.navy)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .disabled(selectedPlaceIds.isEmpty)
            }
            .background(Color.white)
        }
        .cornerRadius(24, corners: [.topLeft, .topRight]) // Standard rounding for the top of the modal
    }
    
    private func toggleSelection(_ id: String) {
        if selectedPlaceIds.contains(id) {
            selectedPlaceIds.remove(id)
        } else {
            selectedPlaceIds.insert(id)
        }
    }
    
    private func shareLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // Fix for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topController.present(activityVC, animated: true)
        }
    }
}


