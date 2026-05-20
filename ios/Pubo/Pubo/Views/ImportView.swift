import SwiftUI
import MapKit

struct ImportView: View {
    let content: Content
    let suggestedPlaces: [ContentPlaceInfo]
    var onConfirm: ([ContentPlaceInfo]) -> Void
    var onCancel: () -> Void
    
    @State private var selectedPlaceIds: Set<String> = []
    @State private var isPromoting = false
    @State private var showingPromoteAlert = false
    @State private var promoteMessage = ""
    
    // 初始化時預設全選
    init(content: Content, suggestedPlaces: [ContentPlaceInfo], onConfirm: @escaping ([ContentPlaceInfo]) -> Void, onCancel: @escaping () -> Void) {
        self.content = content
        self.suggestedPlaces = suggestedPlaces
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // 預設全選 (使用 placeId 作為 key)
        self._selectedPlaceIds = State(initialValue: Set(suggestedPlaces.map { $0.place.placeId }))
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: 內容摘要 (卡片式設計)
                Section {
                    HStack(alignment: .bottom, spacing: 14) {
                        // 左側：貼文原圖（保持原比例）
                        if let urlStr = content.previewThumbnailUrl, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 110)
                                    .cornerRadius(10)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 110, height: 140)
                            }
                        }
                        
                        // 右側：文字資訊
                        VStack(alignment: .leading, spacing: 8) {
                            Text(content.title ?? "未命名內容")
                                .font(.headline)
                                .lineLimit(2)
                            
                            if let author = content.authorName {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                    Text(author)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(content.text ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Section 2: 地點清單
                Section {
                    ForEach(suggestedPlaces, id: \.place.placeId) { info in
                        HStack {
                            Image(systemName: selectedPlaceIds.contains(info.place.placeId) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPlaceIds.contains(info.place.placeId) ? .blue : .gray)
                                .font(.title2)
                                .onTapGesture {
                                    toggleSelection(info.place.placeId)
                                }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.place.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if let address = info.place.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                if let category = info.place.category {
                                    Text(category)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                
                                HStack(spacing: 8) {
                                    if let rating = info.place.rating {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption2)
                                            Text(String(format: "%.1f", rating))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                            if let count = info.place.userRatingCount {
                                                Text("(\(count))")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    if let openNow = info.place.openNow {
                                        Text(openNow ? "營業中" : "休息中")
                                            .font(.caption2)
                                            .foregroundColor(openNow ? .green : .red)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .stroke(openNow ? Color.green : Color.red, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // 讓整個 Row 都能點擊
                        .onTapGesture {
                            toggleSelection(info.place.placeId)
                        }
                    }
                } header: {
                    HStack {
                        Text("偵測到的地點 (\(suggestedPlaces.count))")
                        Spacer()
                        Button(selectedPlaceIds.count == suggestedPlaces.count ? "取消全選" : "全選") {
                            if selectedPlaceIds.count == suggestedPlaces.count {
                                selectedPlaceIds.removeAll()
                            } else {
                                selectedPlaceIds = Set(suggestedPlaces.map { $0.place.placeId })
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("匯入預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        isPromoting = true
                        Task {
                            do {
                                let selected = suggestedPlaces.filter { selectedPlaceIds.contains($0.place.placeId) }
                                try await DataService.shared.promoteToCurated(content: content, places: selected)
                                await MainActor.run {
                                    promoteMessage = "✅ 成功加入推薦行程！"
                                    showingPromoteAlert = true
                                    isPromoting = false
                                }
                            } catch {
                                await MainActor.run {
                                    promoteMessage = "❌ 失敗：\(error.localizedDescription)"
                                    showingPromoteAlert = true
                                    isPromoting = false
                                }
                            }
                        }
                    }) {
                        if isPromoting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("👑 設為推薦")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                    .disabled(selectedPlaceIds.isEmpty || isPromoting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("匯入 (\(selectedPlaceIds.count))") {
                        let selected = suggestedPlaces.filter { selectedPlaceIds.contains($0.place.placeId) }
                        onConfirm(selected)
                    }
                    .disabled(selectedPlaceIds.isEmpty)
                }
            }
            .alert(isPresented: $showingPromoteAlert) {
                Alert(title: Text("推薦行程"), message: Text(promoteMessage), dismissButton: .default(Text("好的")))
            }
        }
    }
    
    private func toggleSelection(_ id: String) {
        if selectedPlaceIds.contains(id) {
            selectedPlaceIds.remove(id)
        } else {
            selectedPlaceIds.insert(id)
        }
    }
}
