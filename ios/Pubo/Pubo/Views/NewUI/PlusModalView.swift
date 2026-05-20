import SwiftUI
import Combine
import PhotosUI

struct PlusModalView: View {
    @Binding var isPresented: Bool
    var onAdd: (String) -> Void
    var onOpenLibrary: () -> Void
    var onCustom: () -> Void
    
    @ObservedObject var dataService = DataService.shared
    
    @State private var linkText = ""
    @State private var isExpanded = false
    @State private var errorMessage: String? = nil
    
    private var isURL: Bool {
        linkText.lowercased().hasPrefix("http")
    }
    
    // Selection state
    @State private var parsedContent: Content? = nil
    @State private var discoveredPlaces: [ContentPlaceInfo] = []
    @State private var selectedPlaceIds: Set<String> = []
    
    // Photo Picker State
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isProcessingScreenshot = false
    
    var body: some View {
        ZStack {
            // === 全螢幕半透明遮罩 ===
            Color.black.opacity(0.4)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            
            // === 底部功能面板 ===
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // 1. 連結識別卡片 (支持連結與文本)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Image(systemName: "link")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.top, 2)
                            
                            Text("連結識別")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        
                        // 輸入框與按鈕
                        VStack(spacing: 12) {
                            TextField("貼上社群貼文、影片連結，或直接輸入景點清單/文章文本，即可幫你辨識景點...", text: $linkText, axis: .vertical)
                                .font(.system(size: 13))
                                .lineLimit(3...8)
                                .padding(12)
                                .frame(minHeight: 80, alignment: .topLeading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Narrow Button at bottom right
                            HStack {
                                Spacer()
                                Button(action: handleSmartImport) {
                                    HStack {
                                        if dataService.isProcessingLink {
                                            ProgressView().tint(.white).padding(.trailing, 2)
                                        }
                                        Text(dataService.isProcessingLink ? "識別中... \(Int(dataService.linkProgress * 100))%" : "開始識別")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(linkText.isEmpty || dataService.isProcessingLink ? Color.gray : PuboColors.navy)
                                    .cornerRadius(16)
                                }
                                .disabled(dataService.isProcessingLink || linkText.isEmpty)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    
                    // 2. 截圖識別卡片
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 12) {
                            if isProcessingScreenshot {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            
                            Text(isProcessingScreenshot ? "圖片辨識中..." : "截圖識別")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(20)
                        .background(Color(hex: "E5F0FF")) // 淺藍色背景
                        .cornerRadius(24)
                    }
                    .disabled(isProcessingScreenshot)
                    .onChange(of: selectedItem) { _, newItem in
                        if let newItem = newItem {
                            handleScreenshotUpload(item: newItem)
                        }
                    }
                    
                    // 3. 關閉按鈕
                    Button(action: {
                        withAnimation { isPresented = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(PuboColors.navy)
                            .frame(width: 50, height: 50)
                            .background(Color(hex: "E5E5EA"))
                            .clipShape(Circle())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: dataService.readyImport != nil) { _, hasResult in
            if hasResult {
                withAnimation {
                    isPresented = false
                }
                if let ready = dataService.readyImport {
                    dataService.pendingImport = ready
                    dataService.readyImport = nil
                }
            }
        }
    }
    
    private func handleSmartImport() {
        guard !linkText.isEmpty else { return }

        // 先查收藏庫：若連結已收藏，直接顯示提示，不觸發後端 AI 分析
        if DataService.shared.isPostCollected(url: linkText) {
            errorMessage = "✅ 這則貼文已在你的收藏庫中，不需要重複收藏。"
            return
        }

        errorMessage = nil
        DataService.shared.startSmartImport(url: linkText)
    }
    
    private func handleScreenshotUpload(item: PhotosPickerItem) {
        isProcessingScreenshot = true
        errorMessage = nil
        
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "PuboError", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法讀取照片資料"])
                }
                
                let result = try await DataService.shared.analyzeScreenshot(imageData: data)
                
                await MainActor.run {
                    self.isProcessingScreenshot = false
                    self.selectedItem = nil
                    DataService.shared.readyImport = PendingImport(content: result.0, places: result.1)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "截圖辨識錯誤: \(error.localizedDescription)"
                    self.isProcessingScreenshot = false
                    self.selectedItem = nil
                }
            }
        }
    }
}
