import SwiftUI

struct LibraryView: View {
    @State private var viewMode: ViewMode = .content
    @State private var contents: [Content] = [] // 從 API 獲取
    @State private var places: [Place] = []     // 從 API 獲取 (去重後)

    enum ViewMode {
        case content
        case place
    }

    var body: some View {
        NavigationView {
            VStack {
                // 模式切換器
                Picker("展示模式", selection: $viewMode) {
                    Text("連結模式").tag(ViewMode.content)
                    Text("地點模式").tag(ViewMode.place)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if viewMode == .content {
                    ContentViewList(contents: contents)
                } else {
                    PlaceViewList(places: places)
                }
            }
            .navigationTitle("我的收藏")
        }
    }
}

// A. 連結模式 (Content View)
struct ContentViewList: View {
    let contents: [Content]
    
    var body: some View {
        List(contents) { content in
            HStack(alignment: .top) {
                // 示意縮圖
                AsyncImage(url: URL(string: content.previewThumbnailUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title ?? content.text ?? "無標題")
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        AsyncImage(url: URL(string: content.authorAvatarUrl ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color.gray)
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        
                        Text(content.authorName ?? "匿名作者")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// B. 地點模式 (Place View)
struct PlaceViewList: View {
    let places: [Place]
    
    var body: some View {
        List {
            // 依類別分組 (PRD 規則)
            ForEach(groupedPlaces.keys.sorted(), id: \.self) { category in
                Section(header: Text(category)) {
                    ForEach(groupedPlaces[category] ?? []) { place in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(place.address ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { /* 加入行程 */ }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 按類別分組的地點
    private var groupedPlaces: [String: [Place]] {
        Dictionary(grouping: places, by: { $0.category ?? "其他" })
    }
}
