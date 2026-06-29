import SwiftUI

struct ShareTripModal: View {
    @Binding var isPresented: Bool
    let trip: Trip?
    var onGenerateImage: (() -> Void)? = nil
    var onCollaborate: (() -> Void)? = nil
    
    @State private var showCopyToast = false
    
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
                    HStack(spacing: 24) {
                        ShareOptionItem(icon: "link", label: "複製連結") {
                            copyInviteLink()
                        }
                        .overlay(alignment: .top) {
                            if showCopyToast {
                                Text("複製成功")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(8)
                                    .offset(y: -40)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        
                        ShareOptionItem(icon: "envelope", label: "Email") {
                            sendEmail()
                        }
                        
                        ShareOptionItem(icon: "LINE_CUSTOM", label: "LINE") {
                            shareToLine()
                        }
                        
                        ShareOptionItem(icon: "ellipsis", label: "更多") {
                            showSystemShareSheet()
                        }
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
    
    private func copyInviteLink() {
        let textToCopy: String
        if let trip = trip, let inviteCode = trip.inviteCode, !inviteCode.isEmpty {
            textToCopy = "快來和我一起在 Pubo 規劃「\(trip.title)」！\n點擊跳轉加入：pubo://join?code=\(inviteCode)\n或輸入邀請碼：\(inviteCode)"
        } else if let trip = trip {
            textToCopy = "快來和我一起在 Pubo 規劃「\(trip.title)」！"
        } else {
            textToCopy = "快來和我一起在 Pubo 規劃行程！"
        }
        UIPasteboard.general.string = textToCopy
        withAnimation {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
    
    private func sendEmail() {
        guard let trip = trip else { return }
        let subject = "快來和我一起在 Pubo 規劃「\(trip.title)」！"
        let body: String
        if let inviteCode = trip.inviteCode, !inviteCode.isEmpty {
            body = "我正在使用 Pubo App 規劃旅行，快點加入我吧！\n\n行程名稱：\(trip.title)\n點擊跳轉加入：pubo://join?code=\(inviteCode)\n或輸入邀請碼：\(inviteCode)"
        } else {
            body = "我正在使用 Pubo App 規劃旅行，快點加入我吧！\n\n行程名稱：\(trip.title)"
        }
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareToLine() {
        guard let trip = trip else { return }
        let text: String
        if let inviteCode = trip.inviteCode, !inviteCode.isEmpty {
            text = "快來和我一起在 Pubo 規劃「\(trip.title)」！\n點擊跳轉加入：pubo://join?code=\(inviteCode)\n或輸入邀請碼：\(inviteCode)"
        } else {
            text = "快來和我一起在 Pubo 規劃「\(trip.title)」！"
        }
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let appURL = URL(string: "line://msg/text/\(encodedText)")
        let webURL = URL(string: "https://line.me/R/msg/text/?\(encodedText)")
        
        if let appURL = appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = webURL {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func showSystemShareSheet() {
        guard let trip = trip else { return }
        let text: String
        if let inviteCode = trip.inviteCode, !inviteCode.isEmpty {
            text = "快來和我一起在 Pubo 規劃「\(trip.title)」！\n點擊跳轉加入：pubo://join?code=\(inviteCode)\n或輸入邀請碼：\(inviteCode)"
        } else {
            text = "快來和我一起在 Pubo 規劃「\(trip.title)」！"
        }
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            if let popoverController = av.popoverPresentationController {
                popoverController.sourceView = topVC.view
                popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            topVC.present(av, animated: true)
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
            .clipped() // Ensure image doesn't bleed out
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2))
        }
    }
}
struct ShareOptionItem: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    if icon == "LINE_CUSTOM" {
                        Text("LINE")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color(hex: "06C755")) // Official LINE Green
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.white))
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(PuboColors.navy)
                    }
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(.plain)
    }
}
