import SwiftUI
import Combine
import PhotosUI

struct PlusModalView: View {
    @Binding var isPresented: Bool
    var onAdd: (String) -> Void
    var onOpenLibrary: () -> Void
    var onCustom: () -> Void
    
    @State private var linkText = ""
    @State private var isProcessing = false
    @State private var isExpanded = false
    @State private var errorMessage: String? = nil
    
    // Photo Picker State
    @State private var selectedItem: PhotosPickerItem? = nil
    
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
                    
                    // 1. 連結識別卡片
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
                            TextField("貼上社群貼文或影片連結，即可幫你辨識出文章所提及的景點等", text: $linkText, axis: .vertical)
                                .font(.system(size: 13))
                                .lineLimit(3...5)
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
                                        if isProcessing {
                                            ProgressView().tint(.white).padding(.trailing, 2)
                                        }
                                        Text(isProcessing ? "識別中..." : "開始識別")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(linkText.isEmpty ? Color.gray : PuboColors.navy)
                                    .cornerRadius(16)
                                }
                                .disabled(isProcessing || linkText.isEmpty)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    
                    // 2. 截圖識別卡片
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("截圖識別")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(20)
                        .background(Color(hex: "E5F0FF")) // 淺藍色背景
                        .cornerRadius(24)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        if newItem != nil {
                            // TODO: Call API for Image OCR when backend is ready!
                            errorMessage = "截圖辨識功能即將推出！"
                            selectedItem = nil // Reset picking state
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
    }
    
    private func handleSmartImport() {
        guard !linkText.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let taskId = try await DataService.shared.submitShareTask(url: linkText)
                
                guard let result = await DataService.shared.pollTaskResult(taskId: taskId) else {
                    await MainActor.run {
                        self.errorMessage = "識別超時或失敗，請檢查連結"
                        self.isProcessing = false
                    }
                    return
                }
                
                // Save directly to the user's Library (Collections)
                DataService.shared.saveContent(result.0, relatedPlaces: result.1)
                
                await MainActor.run {
                    self.isProcessing = false
                    self.linkText = ""
                    // Dismiss on success
                    withAnimation { isPresented = false }
                    // Notice: Users can now see this in their collection library!
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "解析錯誤: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}
