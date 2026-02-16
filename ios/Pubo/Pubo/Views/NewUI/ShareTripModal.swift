import SwiftUI

struct ShareTripModal: View {
    @Binding var isPresented: Bool
    var onGenerateImage: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
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
                    
                    // Main Actions
                    HStack(spacing: 16) {
                        // Collaborate Button
                        Button(action: {}) {
                            VStack(alignment: .leading) {
                                Text("共同編輯")
                                    .font(.system(size: 20, weight: .black))
                                Text("邀請你的旅遊夥伴✨")
                                    .font(.system(size: 12))
                                    .opacity(0.8)
                                Spacer()
                                // Illustration placeholder or icons
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Spacer()
                                }
                            }
                            .foregroundColor(PuboColors.navy)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .background(PuboColors.yellow)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2))
                        }
                        
                        // Export Image Button
                        Button(action: {
                            onGenerateImage?()
                        }) {
                            VStack(alignment: .leading) {
                                Text("生成長圖")
                                    .font(.system(size: 20, weight: .black))
                                Text("匯出完整的行程表")
                                    .font(.system(size: 12))
                                    .opacity(0.8)
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "printer.fill")
                                        .font(.system(size: 30))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .background(PuboColors.navy)
                            .cornerRadius(24)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black, lineWidth: 2))
                        }
                    }
                    .padding(.horizontal, 24)
                    
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
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
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
