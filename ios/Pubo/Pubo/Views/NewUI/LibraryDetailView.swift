import SwiftUI
import SwiftData

struct LibraryDetailView: View {
    @Bindable var content: SDContent
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var showingMemoSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Top Spacer for padding
                    Spacer()
                        .frame(height: 20)

                    // 1. Header Info
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(PuboColors.yellow)
                        Text("已收藏了\(content.places.count)個地點")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    
                    // 2. Main Post Card
                    HStack(alignment: .bottom, spacing: 16) {
                        // Left: Image
                        AsyncImage(url: URL(string: content.previewThumbnailUrl ?? "")) { img in
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.12))
                        }
                        .frame(width: 120, height: 160)
                        .clipped()
                        .cornerRadius(12)
                        
                        // Right: Info
                        VStack(alignment: .leading, spacing: 10) {
                            // Memo Button
                            Button(action: { showingMemoSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                    Text(content.userNote?.isEmpty == false ? "編輯備註" : "添加備註")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(PuboColors.navy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().stroke(PuboColors.navy, lineWidth: 1)
                                )
                            }
                            
                            // Platform & Share
                            HStack {
                                content.platformIcon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                
                                Text(content.sourceType.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                if let url = URL(string: content.sourceUrl) {
                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            // Title
                            Text(content.displayTitle)
                                .font(.system(size: 16, weight: .bold)) // Adjusted size
                                .foregroundColor(.black)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 3. Spots List
                    LazyVStack(spacing: 16) {
                        ForEach(content.places) { place in
                            LibraryPlaceRow(place: place)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 4. Delete Button
                    Button(role: .destructive) {
                        modelContext.delete(content)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("刪除此行程資訊")
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.white)
        .sheet(isPresented: $showingMemoSheet) {
            MemoEditSheet(text: Binding(
                get: { content.userNote ?? "" },
                set: { content.userNote = $0 }
            ))
            .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Subviews

struct LibraryPlaceRow: View {
    let place: SDPlace
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Checkmark (Visual only or interactive?)
            // Design shows blue checkmark.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Color.blue.opacity(0.8)) // Darker blue
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.headline)
                    .foregroundColor(.black)
                
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                HStack {
                    if let cat = place.category {
                        Text(cat.capitalized) // Or map to "Shinto Shrine" etc.
                            .font(.caption2)
                            .foregroundColor(PuboColors.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PuboColors.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    if let rating = place.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(PuboColors.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .fontWeight(.bold)
                            if let count = place.userRatingCount {
                                Text("(\(count))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    if place.openNow == true {
                        Text("營業中")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.green, lineWidth: 1))
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct MemoEditSheet: View {
    @Binding var text: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("編輯備註")
                .font(.headline)
                .padding(.top, 20)
            
            TextEditor(text: $text)
                .frame(maxHeight: .infinity)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            
            Button("完成") {
                dismiss()
            }
            .fontWeight(.bold)
            .padding(.bottom, 20)
        }
    }
}

// Helper for title
extension SDContent {
    var displayTitle: String {
        let t = title ?? ""
        // Check for default titles (case insensitive)
        let ignoredPhrases = ["來自 instagram 的分享", "來自 threads 的分享", "來自 youtube 的分享"]
        let lowerT = t.lowercased()
        
        let isDefaultTitle = t.isEmpty || ignoredPhrases.contains(where: { lowerT.contains($0) })
        
        if !isDefaultTitle {
            return t
        }
        
        if let txt = text, !txt.isEmpty {
            return String(txt.prefix(10)) + (txt.count > 10 ? "..." : "")
        }
        
        return "無標題"
    }
}
