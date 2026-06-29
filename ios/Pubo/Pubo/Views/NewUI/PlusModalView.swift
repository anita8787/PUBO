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
    
    // Keyboard State
    @State private var keyboardHeight: CGFloat = 0
    
    private var isURL: Bool {
        linkText.lowercased().hasPrefix("http")
    }
    
    // Selection state
    @State private var parsedContent: Content? = nil
    @State private var discoveredPlaces: [ContentPlaceInfo] = []
    @State private var selectedPlaceIds: Set<String> = []
    
    // Timer State
    @State private var elapsedSeconds: Double = 0.0
    @State private var timerSubscription: Timer? = nil
    
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
                                            Text(String(format: "識別中 (%.1fs) %d%%", elapsedSeconds, Int(dataService.linkProgress * 100)))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text("開始識別")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
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
                .padding(.bottom, 24 + keyboardHeight)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardRectangle = keyboardFrame.cgRectValue
                withAnimation(.easeOut(duration: 0.25)) {
                    self.keyboardHeight = keyboardRectangle.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = 0
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
        .onChange(of: dataService.isProcessingLink) { _, isProcessing in
            if isProcessing {
                elapsedSeconds = 0.0
                timerSubscription?.invalidate()
                timerSubscription = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    elapsedSeconds += 0.1
                }
            } else {
                timerSubscription?.invalidate()
                timerSubscription = nil
            }
        }
        .onDisappear {
            timerSubscription?.invalidate()
            timerSubscription = nil
        }
    }
    
    private func handleSmartImport() {
        guard !linkText.isEmpty else { return }

        let urls = DataService.shared.extractURLs(from: linkText)
        
        if urls.count > 1 {
            // 多個連結：直接啟動多連結分析，並關閉輸入面板，由懸浮佇列管理！
            errorMessage = nil
            DataService.shared.startSmartImport(url: linkText)
            withAnimation {
                isPresented = false
            }
        } else if urls.count == 1 {
            // 單一連結
            let singleUrl = urls[0]
            if DataService.shared.isPostCollected(url: singleUrl) {
                errorMessage = "✅ 這則貼文已在你的收藏庫中，不需要重複收藏。"
                return
            }
            errorMessage = nil
            DataService.shared.startSmartImport(url: linkText)
            withAnimation {
                isPresented = false
            }
        } else {
            // 無連結：純文字列表輸入
            errorMessage = nil
            DataService.shared.startSmartImport(url: linkText)
            withAnimation {
                isPresented = false
            }
        }
    }
}
