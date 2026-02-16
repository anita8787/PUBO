import SwiftUI

struct ProfileView: View {
    var onBack: () -> Void
    
    var body: some View {
        ZStack {
            PuboColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top spacing — push content below back button
                    Spacer().frame(height: 56)
                    
                    // Avatar + Name + Followers
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Nita")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("123 粉絲  100 追蹤")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    // Stats Card — yellow border + L-shaped retro shadow
                    ZStack {
                        // Shadow layer — offset yellow rectangle behind
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PuboColors.yellow)
                            .offset(x: 3, y: 3)
                        
                        // Card layer
                        HStack(spacing: 0) {
                            VStack(spacing: 4) {
                                Text("56")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                Text("個徽章")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 32)
                            
                            VStack(spacing: 4) {
                                Text("4")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                Text("個行程")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(PuboColors.yellow, lineWidth: 2)
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                    
                    // Quick Actions — circular white bg, yellow border, yellow shadow
                    HStack(spacing: 0) {
                        quickAction(icon: "newspaper", label: "旅行命運")
                        quickAction(icon: "mappin.circle", label: "旅行足跡")
                        quickAction(icon: "bookmark", label: "收藏地點")
                    }
                    .padding(.horizontal, 24)
                    
                    // Settings List
                    VStack(spacing: 0) {
                        settingsRow(icon: "bubble.left", label: "意見回饋")
                        Divider().padding(.horizontal, 16)
                        settingsRow(icon: "flag", label: "貼文管理")
                        Divider().padding(.horizontal, 16)
                        settingsRow(icon: "bubble.left", label: "意見回饋")
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    
                    // Step Counter — arc opens DOWNWARD
                    VStack(spacing: 8) {
                        ZStack {
                            // Background arc — opening faces down
                            // trim(0.15, 0.85) = 70% arc, gap centered at 0.0 (right)
                            // rotate 90° → gap moves to bottom
                            Circle()
                                .trim(from: 0.15, to: 0.85)
                                .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(90))
                            
                            // Progress arc — same rotation
                            Circle()
                                .trim(from: 0.15, to: 0.55)
                                .stroke(
                                    LinearGradient(
                                        colors: [PuboColors.yellow, Color(hex: "F5A623")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(90))
                            
                            // Dot at end of progress (0.55 turn + 90° offset)
                            Circle()
                                .fill(Color(hex: "E74C3C"))
                                .frame(width: 12, height: 12)
                                .offset(y: -90)
                                .rotationEffect(.degrees(90 + 0.55 * 360))
                            
                            // Step count text
                            VStack(spacing: 2) {
                                Text("2,241步")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundColor(PuboColors.navy)
                                
                                Text("今日活力值")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PuboColors.yellow)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(
            // Back Button
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(PuboColors.navy)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PuboColors.navy, lineWidth: 1.5))
            }
            .padding(.leading, 24)
            .padding(.top, 8),
            alignment: .topLeading
        )
    }
    
    // Quick action — circular white bg, yellow border, yellow shadow
    func quickAction(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(PuboColors.navy)
                .frame(width: 52, height: 52)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(PuboColors.yellow, lineWidth: 2)
                )
                .shadow(color: PuboColors.yellow.opacity(0.4), radius: 0, x: 2, y: 2)
            
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(PuboColors.navy)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Settings row
    func settingsRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.gray)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
