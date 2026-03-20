import SwiftUI

struct ShareTripModal: View {
    @Binding var isPresented: Bool
    var onGenerateImage: (() -> Void)? = nil
    var onCollaborate: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background Dimming Layer
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                    // Header Handle
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                    
                    Text("分享行程")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(PuboColors.navy)
                        .padding(.bottom, 8)
                    
                    // Main Actions Container - ensure responsive width
                    HStack(spacing: 16) {
                        // 1. Collaborate Button
                        ActionButton(
                            title: "共同編輯",
                            subtitle: "邀請您的旅遊夥伴",
                            illustration: "share-illustration",
                            bgColor: PuboColors.yellow,
                            textColor: PuboColors.navy,
                            imgWidth: 100,
                            imgOffset: CGPoint(x: 10, y: 10),
                            action: { onCollaborate?() }
                        )
                        
                        // 2. Export Image Button
                        ActionButton(
                            title: "匯出長圖",
                            subtitle: "邀請您的旅遊夥伴",
                            illustration: "picture-illustration",
                            bgColor: PuboColors.navy,
                            textColor: .white,
                            imgWidth: 100, // Enlarged
                            imgOffset: CGPoint(x: 10, y: 20), // Tweak offset to push it slighty downward
                            action: { onGenerateImage?() }
                        )
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 500) // Control max width for large screens
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Share Options
                    HStack(spacing: 30) {
                        ShareOptionItem(icon: "link", label: "複製連結")
                        ShareOptionItem(icon: "envelope", label: "Email")
                        ShareOptionItem(icon: "qrcode", label: "掃碼分享")
                        ShareOptionItem(icon: "ellipsis", label: "更多")
                    }
                    .padding(.bottom, 32)
                }
                .background(Color.white)
                .cornerRadius(32, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                .transition(.move(edge: .bottom))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Reusable Action Button
struct ActionButton: View {
    let title: String
    let subtitle: String
    let illustration: String
    let bgColor: Color
    let textColor: Color
    let imgWidth: CGFloat
    let imgOffset: CGPoint
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // Background Illustration - Layer 0
                Image(illustration)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imgWidth)
                    .offset(x: imgOffset.x, y: imgOffset.y)
                    .opacity(1.0)
                
                // Text Overlay - Layer 1
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .opacity(0.8)
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity) // EQUAL WIDTH
            .frame(height: 140)
            .background(bgColor)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2))
            .clipped() // Ensure image doesn't bleed out
        }
    }
}
struct ShareOptionItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(PuboColors.navy)
            }
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
        }
    }
}
