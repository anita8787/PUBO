import SwiftUI
import Combine

struct PlusModalView: View {
    @Binding var isPresented: Bool
    var onAdd: (String) -> Void
    var onOpenLibrary: () -> Void
    var onCustom: () -> Void
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        ZStack {
            // === 全螢幕半透明遮罩 ===
            Color.black.opacity(0.2)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    isSearchFocused = false
                    withAnimation(.easeOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            
            // === 底部功能面板（手動跟隨鍵盤）===
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    // 功能方塊區域（4 個按鈕橫排）
                    HStack(spacing: 10) {
                        PlusModalButton(
                            icon: "sparkles",
                            title: "智能導入",
                            borderColor: PuboColors.navy,
                            shadowColor: Color(hex: "023B7E"),
                            action: { }
                        )
                        
                        PlusModalButton(
                            icon: "bed.double",
                            title: "住宿",
                            borderColor: PuboColors.red,
                            shadowColor: Color(hex: "E84011"),
                            action: { }
                        )
                        
                        PlusModalButton(
                            icon: "star",
                            title: "收藏庫",
                            borderColor: PuboColors.red,
                            shadowColor: Color(hex: "E84011"),
                            action: {
                                onOpenLibrary()
                                withAnimation { isPresented = false }
                            }
                        )
                        
                        PlusModalButton(
                            icon: "doc.text",
                            title: "自定義",
                            borderColor: PuboColors.red,
                            shadowColor: Color(hex: "E84011"),
                            action: {
                                onCustom()
                                withAnimation { isPresented = false }
                            }
                        )
                    }
                    
                    // === 白色搜尋列 ===
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundColor(Color.gray.opacity(0.3))
                        
                        TextField("搜尋地點", text: $searchText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .focused($isSearchFocused)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isSearchFocused = true
                                }
                            }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 60)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, keyboardHeight > 0 ? max(keyboardHeight - 34, 10) : 20)
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onReceive(keyboardPublisher) { height in
            keyboardHeight = height
        }
    }
    
    // 鍵盤高度監聽
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .map { notification -> CGFloat in
                    (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ -> CGFloat in 0 }
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - 功能方塊按鈕元件
struct PlusModalButton: View {
    let icon: String
    let title: String
    let borderColor: Color
    let shadowColor: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // 圖示（左上）
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // 文字（左下）
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.black)
                    .tracking(-0.5)
            }
            .padding(12)
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            // L 型復古陰影
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(shadowColor)
                    .offset(x: 2.5, y: 2.5)
            )
        }
        .buttonStyle(PlusModalButtonStyle())
    }
}

// MARK: - 按壓效果
struct PlusModalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(
                x: configuration.isPressed ? 2 : 0,
                y: configuration.isPressed ? 2 : 0
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
