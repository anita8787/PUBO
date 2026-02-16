import SwiftUI
import MapKit
import PDFKit // Added for PDF generation

// Helper to avoid UIScreen.main deprecation
struct ScreenUtils {
    @MainActor
    static var width: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
             return windowScene.screen.bounds.width
        }
        return 393 // Fallback
    }
    
    @MainActor
    static var height: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
             return windowScene.screen.bounds.height
        }
        return 852
    }
    
    @MainActor
    static var scale: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
             return windowScene.screen.scale
        }
        return 2.0
    }
}

struct LongImagePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let trip: Trip
    let allDays: [ItineraryDay]
    
    @State private var selectedTab: Int = 0
    let tabs = ["行程計畫", "行程路線", "行李清單"]
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    @State private var showExportCard = false
    @State private var showSavedAlert = false
    @State private var showFlash = false
    
    @State private var showDownloadActionSheet = false
    @State private var selectedExportFormat: ExportFormat = .png
    
    enum ExportFormat {
        case png, pdf
    }
    
    // Light cream background to match screenshot
    let creamBackground = Color(hex: "FDFBF7")
    
    var body: some View {
        ZStack {
            // Background
            creamBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    }
                    
                    Spacer()
                    
                    // Custom Segmented Control - Right Aligned, Connected closely
                    HStack(spacing: 12) { // Fixed spacing
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: { withAnimation { selectedTab = index } }) {
                                VStack(spacing: 4) {
                                    Text(tabs[index])
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundColor(selectedTab == index ? PuboColors.red : Color.gray.opacity(0.4))
                                    
                                    // Fixed frame for indicator to prevent shifting
                                    ZStack {
                                        Capsule().fill(Color.clear).frame(height: 3)
                                        if selectedTab == index {
                                            Capsule()
                                                .fill(PuboColors.red)
                                                .frame(height: 3)
                                        }
                                    }
                                    .frame(width: 24, height: 3)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16) // Padding for container
                .padding(.vertical, 16)
                
                // Content TabView
                TabView(selection: $selectedTab) {
                    ItineraryPlanView(trip: trip, allDays: allDays)
                        .tag(0)
                    
                    RouteMapView(trip: trip, allDays: allDays)
                        .tag(1)
                        
                    LuggageListView(trip: trip, allDays: allDays)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Bottom Actions
                HStack(spacing: 40) {
                    actionButton(icon: "square.and.arrow.up", label: "分享") {
                        handleShare()
                    }
                    actionButton(icon: "square.and.arrow.down", label: "下載圖片") {
                        showDownloadActionSheet = true
                    }
                }
                .padding(.bottom, 24)
            }
            
            // Flash Overlay
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            // Export Card Overlay
            if showExportCard {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showExportCard = false
                        }
                    }
                
                VStack {
                    Spacer()
                    ExportCard(
                        onSaveToPhotos: {
                            saveToPhotos()
                            withAnimation { showExportCard = false }
                        },
                        onSaveToFiles: {
                            // Delay slightly to allow card to dismiss visually or keep it?
                            // Better to dismiss card then show share sheet
                            withAnimation { showExportCard = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                saveToFiles()
                            }
                        },
                        onCancel: {
                            withAnimation { showExportCard = false }
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(100)
            }
            
            // Saved Alert
            if showSavedAlert {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("已儲存到相簿")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .transition(.opacity)
                .zIndex(101)
            }
        }

        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
                .presentationDetents([.medium, .large])
        }
        .actionSheet(isPresented: $showDownloadActionSheet) {
            ActionSheet(
                title: Text("選擇檔案格式"),
                buttons: [
                    .default(Text("PNG 圖片")) { startExportProcess(format: .png) },
                    .default(Text("PDF 文件")) { startExportProcess(format: .pdf) },
                    .cancel()
                ]
            )
        }
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(PuboColors.navy)
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            }
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
        }
    }
    
    func handleShare() {
        // Share defaults to PNG image (System Share Sheet)
        if let image = generateSnapshot() {
            shareItems = [image]
            showShareSheet = true
        }
    }
    
    func startExportProcess(format: ExportFormat) {
        selectedExportFormat = format
        
        // 1. Flash Animation
        withAnimation(.linear(duration: 0.1)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.linear(duration: 0.15)) {
                showFlash = false
            }
            
            // 2. Show Card after flash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    showExportCard = true
                }
            }
        }
    }
    
    func saveToPhotos() {
        // Photos always saves as Image, regardless of format selection (PDF saved as image)
        guard let image = generateSnapshot() else { return }
        
        let saver = ImageSaver()
        saver.successHandler = {
            withAnimation {
                showSavedAlert = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSavedAlert = false
                }
            }
        }
        saver.errorHandler = { error in
            print("Save error: \(error.localizedDescription)")
        }
        saver.writeToPhotoAlbum(image: image)
    }
    
    func saveToFiles() {
        if selectedExportFormat == .pdf {
            if let url = generatePDF() {
                shareItems = [url]
                showShareSheet = true
            }
        } else {
            if let image = generateSnapshot() {
                shareItems = [image]
                showShareSheet = true
            }
        }
    }
    
    @MainActor
    func generateSnapshot() -> UIImage? {
        let renderer = ImageRenderer(content: snapshotContent())
        renderer.scale = ScreenUtils.scale
        return renderer.uiImage
    }
    
    @MainActor
    func generatePDF() -> URL? {
        let renderer = ImageRenderer(content: snapshotContent())
        let url = URL.documentsDirectory.appending(path: "trip_export.pdf")
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        return url
    }
    
    @ViewBuilder
    func snapshotContent() -> some View {
        switch selectedTab {
        case 0:
            ItineraryPlanView(trip: trip, allDays: allDays, isScrollable: false)
                .frame(width: ScreenUtils.width) // Fix width for renderer
        case 1:
            RouteMapView(trip: trip, allDays: allDays, isScrollable: false)
                .frame(width: ScreenUtils.width)
        case 2:
            LuggageListView(trip: trip, allDays: allDays, isScrollable: false)
                .frame(width: ScreenUtils.width)
        default:
            EmptyView()
        }
    }

// Helper View for Header Pattern
struct CheckeredHeader: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let squareSize = width / 16.0 // Smaller squares, shorter height
            
            VStack(spacing: 0) {
                // Row 1
                HStack(spacing: 0) {
                    ForEach(0..<16) { i in
                        Rectangle()
                            .fill(i % 2 == 0 ? PuboColors.navy : PuboColors.yellow)
                            .frame(width: squareSize, height: squareSize)
                    }
                }
                
                // Row 2
                HStack(spacing: 0) {
                    ForEach(0..<16) { i in
                        Rectangle()
                            .fill(i % 2 == 0 ? PuboColors.yellow : PuboColors.navy)
                            .frame(width: squareSize, height: squareSize)
                    }
                }
            }
        }
        // Height = 2 * (Width / 16)
        // Height = 2 * (Width / 16)
        .frame(height: (ScreenUtils.width * 0.8 / 16.0) * 2)
    }
}

// Helper for "Hole"
struct HeaderHole: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 18, height: 18) // Slightly bigger hole
            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
    }
}

struct ItineraryPlanView: View {
    let trip: Trip
    let allDays: [ItineraryDay]
    var isScrollable: Bool = true
    
    var durationString: String {
        "\(allDays.count)天\(max(0, allDays.count - 1))夜"
    }
    
    // Header Height Calculation for Hole Offset
    var headerHeight: CGFloat {
        (ScreenUtils.width * 0.8 / 16.0) * 2
    }
    
    var body: some View {
        if isScrollable {
            ScrollView(showsIndicators: false) {
                mainContent
            }
        } else {
            mainContent
        }
    }
    
    var mainContent: some View {
        VStack {
                // Phone Frame Simulation
                ZStack {
                    // Start of Card Content
                    VStack(spacing: 0) {
                        // Header Pattern
                        CheckeredHeader()
                        
                        // Main Content Area
                        VStack(spacing: 24) {
                            // Trip Info Header
                            VStack(spacing: 8) {
                                // Hole - centered in header vertically
                                // Header height ~56. Half is 28.
                                // Content starts below header.
                                // Offset -28 moves it to middle of header.
                                HeaderHole()
                                    .offset(y: -(headerHeight / 2) - 16) // Move up more to center
                                    .padding(.bottom, -(headerHeight / 2) - 16)
                                
                                Text(trip.title)

                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(PuboColors.red) // Use orange/red
                                
                                Text(durationString)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.white) // White background for pill
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(PuboColors.navy, lineWidth: 1.5)
                                    )
                            }
                            .padding(.top, 10)
                            
                            // Day List inside Orange Border
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(Array(allDays.enumerated()), id: \.offset) { index, day in
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Row 1: Day Tag & Count
                                        HStack {
                                            Text("第\(chineseNumber(index + 1))天")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(PuboColors.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.white)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(PuboColors.red, lineWidth: 1)
                                                )
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(PuboColors.red)
                                                    .frame(width: 6, height: 6)
                                                Text("\(day.spots.count)個行程")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        // Row 2: Timeline & Spots
                                        HStack(alignment: .top, spacing: 16) {
                                            // Timeline Line (Centered under Day Tag approx width)
                                            // Day Tag width ~ 60?
                                            // Let's assume line is indented
                                            Rectangle() // Dotted Line simulation
                                                .fill(Color.clear)
                                                .frame(width: 1)
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                        .foregroundColor(Color.gray.opacity(0.3))
                                                )
                                                .padding(.leading, 24) // Indent to align with pill center approx
                                            
                                            // Spots List
                                            VStack(alignment: .leading, spacing: 12) {
                                                if day.spots.isEmpty {
                                                    Text("尚未安排行程")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray.opacity(0.4))
                                                } else {
                                                    ForEach(day.spots) { spot in
                                                        HStack(alignment: .bottom, spacing: 6) {
                                                            Text(spot.name)
                                                                .font(.system(size: 13, weight: .bold)) // Reduced to 13pt
                                                                .foregroundColor(PuboColors.navy)
                                                            
                                                            // Logic to show ONLY duration (minutes/hours) and ignore "Opening Hours"
                                                            let durationText = getStayDuration(spot)
                                                            if !durationText.isEmpty {
                                                                Text(durationText)
                                                                    .font(.system(size: 11))
                                                                    .foregroundColor(.gray)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            // Orange Border Container
                            .padding(24)
                            .background(Color.white) // White background!
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(PuboColors.red, lineWidth: 2)
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        }
                    }
                    .background(Color(hex: "FFF9E1")) // Card Background (Cream/Beige)
                    .cornerRadius(40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(Color.black, lineWidth: 3)
                    )
                }
                .frame(width: ScreenUtils.width * 0.8)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            }
            .padding(.vertical, 20)
            .padding(.bottom, 40)
        }
    func chineseNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
    
    func getStayDuration(_ spot: ItinerarySpot) -> String {
        // Prioritize subLabel if it looks like duration
        if let sub = spot.subLabel, (sub.contains("分") || sub.contains("時")) {
            return sub
        }
        // Fallback to duration if it's NOT opening hours
        if !spot.duration.contains("營業") && (spot.duration.contains("分") || spot.duration.contains("時")) {
            return spot.duration
        }
        return "" 
    }
}

struct RouteMapView: View {
    let trip: Trip
    let allDays: [ItineraryDay]
    var isScrollable: Bool = true
    
    var allSpots: [ItinerarySpot] {
        allDays.flatMap { $0.spots }
    }
    
    @State private var position: MapCameraPosition = .automatic
    // Duration Helper
    var durationString: String {
        "\(allDays.count)天\(max(0, allDays.count - 1))夜"
    }
    
    // Header Height Calculation for Hole Offset
    var headerHeight: CGFloat {
        (ScreenUtils.width * 0.8 / 16.0) * 2
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                ZStack {
                    // Card Container
                    VStack(spacing: 0) {
                        // Header Pattern
                        CheckeredHeader()
                        
                        // Main Content
                        VStack(spacing: 24) {
                            // Header Info
                            VStack(spacing: 8) {
                                HeaderHole()
                                    .offset(y: -(headerHeight / 2) - 20) // Moved up further
                                    .padding(.bottom, -(headerHeight / 2) - 20)
                                
                                Text(trip.title)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(PuboColors.red)
                                
                                Text(durationString)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 1.5))
                            }
                            .padding(.top, 10)
                            
                            // Map Content Container
                            // Does this need white background too? Screenshot 2 map seems to be inside orange border white box too? 
                            // Yes, map is inside orange border.
                            ZStack {
                                Map(position: $position) {
                                    // Draw Polyline connecting all spots
                                    let coordinates = allSpots.compactMap { $0.coordinate.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.long) } }
                                    if !coordinates.isEmpty {
                                        MapPolyline(coordinates: coordinates)
                                            .stroke(PuboColors.navy, lineWidth: 3)
                                    }
                                    
                                    ForEach(Array(allSpots.enumerated()), id: \.offset) { index, spot in
                                        if let coordinate = spot.coordinate {
                                            Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.long)) {
                                                ZStack {
                                                    Circle()
                                                        .fill(PuboColors.red)
                                                        .frame(width: 24, height: 24)
                                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                    }
                                }
                                .mapStyle(.standard)
                                .cornerRadius(20)
                            }
                            .frame(height: 400)
                            .padding(24) // Padding inside white box
                            .background(Color.white) // White background
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(PuboColors.red, lineWidth: 2)
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        }
                    }
                    .background(Color(hex: "FFF9E1"))
                    .cornerRadius(40)
                    .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.black, lineWidth: 3))
                }
                .frame(width: ScreenUtils.width * 0.8)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            }
            .padding(.vertical, 20)
        }
    }
}

struct LuggageListView: View {
    let trip: Trip
    let allDays: [ItineraryDay]
    var isScrollable: Bool = true
    
    let items = [
        "護照", "日幣現金", "行動電源", "充電線", "日本網卡", "換洗衣物", "藥品"
    ]
    
    var durationString: String {
        "\(allDays.count)天\(max(0, allDays.count - 1))夜"
    }
    
    // Header Height Calculation for Hole Offset
    var headerHeight: CGFloat {
        (ScreenUtils.width * 0.8 / 16.0) * 2
    }
    
    var body: some View {
        if isScrollable {
            ScrollView(showsIndicators: false) {
                mainContent
            }
        } else {
            mainContent
        }
    }
    
    var mainContent: some View {
            VStack {
                ZStack {
                    VStack(spacing: 0) {
                        // Header Pattern
                        CheckeredHeader()
                        
                        VStack(spacing: 24) {
                            // Header Info
                            VStack(spacing: 8) {
                                HeaderHole()
                                    .offset(y: -(headerHeight / 2) - 20) // Moved up further
                                    .padding(.bottom, -(headerHeight / 2) - 20)
                                
                                Text(trip.title)
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(PuboColors.red)
                                
                                Text(durationString)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(PuboColors.navy, lineWidth: 1.5))
                            }
                            .padding(.top, 10)
                            
                            // Luggage List Container
                            VStack(alignment: .leading, spacing: 16) {
                                Text("必備物品")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(PuboColors.navy)
                                    .padding(.bottom, 8)
                                    
                                ForEach(items, id: \.self) { item in
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            .frame(width: 20, height: 20)
                                        
                                        Text(item)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    if item != items.last {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white) // White background
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PuboColors.red, lineWidth: 2))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        }
                    }
                    .background(Color(hex: "FFF9E1"))
                    .cornerRadius(40)
                    .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.black, lineWidth: 3))
                }
                .frame(width: ScreenUtils.width * 0.8)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            }
            .padding(.vertical, 20)
    }
    }
}

// Image Saver Helper
class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}

// Custom Export Card
struct ExportCard: View {
    let onSaveToPhotos: () -> Void
    let onSaveToFiles: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            HStack(spacing: 40) {
                exportButton(title: "儲存到相簿", icon: "photo.on.rectangle", action: onSaveToPhotos)
                exportButton(title: "儲存到檔案", icon: "folder", action: onSaveToFiles)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity) // Full Width
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }
    
    func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(PuboColors.navy)
                    .frame(width: 64, height: 64)
                    .background(Color(hex: "F5F5F5"))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(PuboColors.navy)
            }
        }
    }
}



struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
