import SwiftUI
import MapKit

struct ImportView: View {
    let content: Content
    let suggestedPlaces: [ContentPlaceInfo]
    var onConfirm: ([ContentPlaceInfo]) -> Void
    var onCancel: () -> Void
    
    @State private var selectedPlaceIds: Set<String> = []
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        if let urlStr = content.previewThumbnailUrl, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(12)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 180)
                                    .cornerRadius(12)
                            }
                        }
                        
                        Text(content.title ?? "未命名內容")
                            .font(.headline)
                            .lineLimit(2)
                        
                        if let author = content.authorName {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(content.text ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("來自 \(content.sourceType.rawValue.capitalized) 的分享")
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
                                    if let rating = info.place.rating, let count = info.place.userRatingCount {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption2)
                                            Text(String(format: "%.1f", rating))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                            Text("(\(count))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("匯入 (\(selectedPlaceIds.count))") {
                        let selected = suggestedPlaces.filter { selectedPlaceIds.contains($0.place.placeId) }
                        onConfirm(selected)
                    }
                    .disabled(selectedPlaceIds.isEmpty)
                }
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
