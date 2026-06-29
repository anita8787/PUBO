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

                    // 1. Header Info (Restored)
                    HStack {
                        Image("Star icon ")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("已收藏了\(content.places.filter { $0.isSaved }.count)個地點")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)

                    // 2. Main Post Card
                    HStack(alignment: .bottom, spacing: 16) {
                        // Left: Image
                        Group {
                            if let urlStr = content.previewThumbnailUrl, !urlStr.isEmpty {
                                AsyncImage(url: URL(string: urlStr)) { img in
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.12))
                                }
                            } else {
                                // Fallback for Plain Text
                                ZStack {
                                    Color(hex: "F9F9F9")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(content.text ?? "筆記內容")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray.opacity(0.6))
                                            .lineLimit(8)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .frame(width: 120, height: 160)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(alignment: .bottomTrailing) {
                            if let sourceUrl = content.sourceUrl, let url = URL(string: sourceUrl) {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .offset(x: 1)
                                    }
                                }
                                .padding(8)
                            }
                        }
                        
                        // Right: Info
                        VStack(alignment: .leading, spacing: 10) {
                            // If no memo, show add button
                            if content.userNote?.isEmpty != false {
                                Button(action: { showingMemoSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                        Text("添加備註")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().stroke(PuboColors.navy, lineWidth: 1)
                                    )
                                }
                            }
                            
                            // Platform & Share
                            HStack(spacing: 6) {
                                content.platformIcon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                
                                Text(content.sourceType.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                if let sourceUrl = content.sourceUrl, let url = URL(string: sourceUrl) {
                                    ShareLink(item: url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
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
                    
                    // 2.5 Memo Section (If exists, now below the post card)
                    if let note = content.userNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 14))
                                Text("我的備註")
                                    .font(.system(size: 12, weight: .black))
                                Spacer()
                                Button(action: { showingMemoSheet = true }) {
                                    Text("編輯")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(PuboColors.navy)
                                }
                            }
                            .foregroundColor(PuboColors.navy.opacity(0.6))
                            
                            Text(note)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PuboColors.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(PuboColors.blue) // EBF2FF is light blue
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(PuboColors.navy.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, -8) // Slight adjust to stay close to card
                    }
                    
                    // 3. Spots List
                    LazyVStack(spacing: 16) {
                        ForEach(content.places) { place in
                            LibraryPlaceRow(
                                place: place,
                                onToggleSave: {
                                    withAnimation {
                                        place.isSaved.toggle()
                                    }
                                },
                                onTapContent: {
                                    if place.isSaved {
                                        NotificationCenter.default.post(name: NSNotification.Name("FocusMapOnPlace"), object: place)
                                        dismiss() // Dismiss LibraryDetailView
                                    }
                                }
                            )
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
    let onToggleSave: () -> Void
    let onTapContent: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Interactive Checkmark
            Button(action: onToggleSave) {
                Image(systemName: place.isSaved ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(place.isSaved ? Color.blue.opacity(0.8) : Color.gray.opacity(0.4))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            // Spot Information Content
            Button(action: onTapContent) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundColor(place.isSaved ? .black : .gray)
                        
                        if let category = place.category, !category.isEmpty {
                            Text(category)
                                .font(.caption)
                                .foregroundColor(place.isSaved ? .blue : .gray.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(place.isSaved ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Text((place.address?.isEmpty == false) ? place.address! : "暫無詳細地址")
                            .font(.caption2)
                            .lineLimit(2)
                            .foregroundColor(place.isSaved ? .gray : .gray.opacity(0.6))
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!place.isSaved) // Disable navigation tap if the place is unsaved
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .opacity(place.isSaved ? 1.0 : 0.6) // Grays out whole row when unchecked
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
            return String(txt.prefix(15)) + (txt.count > 15 ? "..." : "")
        }
        
        return "無標題"
    }
}
