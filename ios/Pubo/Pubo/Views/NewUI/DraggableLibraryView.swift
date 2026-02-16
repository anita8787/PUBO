import SwiftUI
import SwiftData

struct DraggableLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDContent.createdAt, order: .reverse) private var sdContents: [SDContent]
    
    // UI State
    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @GestureState private var gestureOffset: CGFloat = 0
    @State private var selectedFilter: String = "全部"
    
    // Custom Category State
    @AppStorage("customLibraryCategories") private var customCategoriesRaw: String = "[]"
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    // Selection Mode State (Adding posts to a category)
    @State private var isSelectionMode = false
    @State private var targetCategoryForSelection: String? = nil
    
    // Formatting
    @State private var selectedContent: SDContent? = nil
    
    // Constants
    let collapsedHeight: CGFloat = 180
    let expandedOffset: CGFloat = 100
    
    // Default Filters (Emojis for display)
    let defaultFilters = ["全部", "美食 🍜", "景點 🗻", "住宿 🏠", "購物 🛍️"]
    
    var allFilters: [String] {
        var filters = defaultFilters
        // Add custom categories
        if let data = customCategoriesRaw.data(using: .utf8),
           let custom = try? JSONDecoder().decode([String].self, from: data) {
            filters.append(contentsOf: custom)
        }
        return filters
    }
    
    var filteredContents: [SDContent] {
        if selectedFilter == "全部" {
            return sdContents
        }
        
        let categoryName = selectedFilter.components(separatedBy: " ").first ?? selectedFilter
        
        return sdContents.filter { content in
            // 1. If explicit user category matches
            if let userCat = content.userCategory {
                return userCat == categoryName
            }
            // 2. If no user category, check auto-categorization (only for default categories)
            if defaultFilters.contains(where: { $0.contains(categoryName) }) {
                return content.determinedCategory == categoryName
            }
            return false
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.frame(in: .global).height
            
            ZStack(alignment: .top) {
                // Background
                Color.white
                    .clipShape(RoundedCorner(radius: 40, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                    .overlay(
                        RoundedCorner(radius: 40, corners: [.topLeft, .topRight])
                            .stroke(PuboColors.navy, lineWidth: 2)
                    )
                
                VStack(spacing: 0) {
                    // Drag Handle
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 48, height: 6)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Header Area
                    HStack {
                        if isSelectionMode {
                            // Selection Mode Header
                            Button(action: { exitSelectionMode() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            Text("加入至 \(targetCategoryForSelection ?? "")")
                                .font(.headline)
                                .foregroundColor(PuboColors.navy)
                            Spacer()
                        } else {
                            // Normal Header
                            Text("收藏庫")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(PuboColors.navy)
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(PuboColors.navy)
                                .rotationEffect(.degrees(offset < height / 2 ? 180 : 0))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    // Filter Chips (Hide in selection mode or keep?)
                    // User said: "Click add post -> go to ALL view". So we might hide filters or force ALL.
                    if !isSelectionMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(allFilters, id: \.self) { filter in
                                    FilterChip(title: filter, isSelected: selectedFilter == filter) {
                                        withAnimation { selectedFilter = filter }
                                    }
                                }
                                
                                // Add Category Button
                                Button(action: { showingAddCategoryAlert = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(PuboColors.navy)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 6)
                        }
                        .padding(.bottom, 12)
                    }
                    
                    // Grid Content
                    if filteredContents.isEmpty && selectedFilter != "全部" && !defaultFilters.contains(selectedFilter) && !isSelectionMode {
                        // Empty Custom Category State
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("此分類尚無貼文")
                                .foregroundColor(.gray)
                            
                            Button(action: { enterSelectionMode() }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("添加貼文")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.gray)) // User requested gray oval
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Content Grid
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                ForEach(filteredContents) { content in
                                    Button(action: {
                                        if !isSelectionMode {
                                            selectedContent = content
                                        } else {
                                            assignCategory(content: content)
                                        }
                                    }) {
                                        LibraryCard(content: content, isSelectionMode: isSelectionMode, targetCategory: targetCategoryForSelection) {
                                            // On Add (Selection Mode) - Redundant if card handles click? 
                                            // LibraryCard onAdd is for the + button only.
                                            assignCategory(content: content)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 120) // Bottom padding for safe area
                        }
                    }
                }
            }
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .updating($gestureOffset) { value, out, _ in
                        out = value.translation.height
                    }
                    .onEnded { value in
                        let threshold = height * 0.4
                        if -value.translation.height > threshold || value.translation.height < -100 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                offset = expandedOffset
                            }
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                offset = height - collapsedHeight
                            }
                        }
                        lastOffset = offset
                    }
            )
            .onAppear {
                offset = height - collapsedHeight
            }
            .sheet(item: $selectedContent) { content in
                LibraryDetailView(content: content)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("新增分類", isPresented: $showingAddCategoryAlert) {
                TextField("分類名稱", text: $newCategoryName)
                Button("取消", role: .cancel) { newCategoryName = "" }
                Button("新增") {
                    addNewCategory(newCategoryName)
                    newCategoryName = ""
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addNewCategory(_ name: String) {
        guard !name.isEmpty else { return }
        var categories = (try? JSONDecoder().decode([String].self, from: customCategoriesRaw.data(using: .utf8)!)) ?? []
        if !categories.contains(name) {
            categories.append(name)
            if let data = try? JSONEncoder().encode(categories) {
                customCategoriesRaw = String(data: data, encoding: .utf8) ?? "[]"
                // Select new category
                selectedFilter = name
            }
        }
    }
    
    private func enterSelectionMode() {
        guard selectedFilter != "全部" && !defaultFilters.contains(selectedFilter) else { return }
        let categoryName = selectedFilter
        isSelectionMode = true
        targetCategoryForSelection = categoryName
        selectedFilter = "全部" // Switch to All to pick items
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        // Return to the custom category view (or default)
        if let target = targetCategoryForSelection {
            selectedFilter = target
        }
        targetCategoryForSelection = nil
    }
    
    private func assignCategory(content: SDContent) {
        guard let target = targetCategoryForSelection else { return }
        content.userCategory = target
        // Save handled mainly by SwiftData autosave or manual context save?
        // Usually implicit in bindings? No, need explicit save or change on MainActor.
        // But SDContent is object. Changes persist.
        // We might want to give visual feedback?
        // For now, simple assignment.
    }
}

// MARK: - Subviews

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(PuboColors.navy)
                .background(
                    Capsule()
                        .fill(isSelected ? PuboColors.yellow : Color.gray.opacity(0.05))
                )
                .overlay(
                    Capsule().stroke(isSelected ? PuboColors.navy : Color.gray.opacity(0.2), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct LibraryCard: View {
    let content: SDContent
    let isSelectionMode: Bool
    let targetCategory: String?
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Area
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: content.previewThumbnailUrl ?? "")) { img in
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.12))
                }
                .frame(width: 160, height: 200) // Fixed size approx
                .clipped()
                .cornerRadius(14)
                
                // Selection Mode Overlay / Button
                if isSelectionMode {
                    Button(action: onAdd) {
                        ZStack {
                            Circle().fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(radius: 2)
                            
                            if content.userCategory == targetCategory {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .frame(height: 200)
            
            // Info Area
            VStack(alignment: .leading, spacing: 4) {
                // Title
                // Title
                Text(content.displayTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    // Platform Icon
                    content.platformIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    
                    // Spot Count
                    Text("\(content.places.count) 個地點")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Logic Extensions

extension SDContent {
    var determinedCategory: String {
        // If has user category, return it? 
        // Logic: Filter view calls this to check matching.
        // But logic in filteredContents separates userCat vs auto.
        // This helper is for auto-categorization.
        
        // Analyze places
        let categories = places.compactMap { $0.category?.lowercased() }
        let joined = categories.joined(separator: " ")
        
        if joined.contains("restaur") || joined.contains("food") || joined.contains("cafe") || joined.contains("bar") {
            return "美食"
        }
        if joined.contains("lodging") || joined.contains("hotel") {
            return "住宿"
        }
        if joined.contains("store") || joined.contains("shop") || joined.contains("mall") {
            return "購物"
        }
        // Default to Spot
        return "景點"
    }
    
    var platformIcon: Image {
        switch sourceType.lowercased() {
        case "youtube": return Image("platform-youtube")
        case "instagram": return Image("platform-instagram")
        case "threads": return Image("platform-threads")
        default: return Image(systemName: "link.circle.fill")
        }
    }
    

}
