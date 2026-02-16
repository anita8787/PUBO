import SwiftUI

struct TripCardView: View {
    let title: String
    let date: String
    let spotsCount: Int
    let color: String
    
    // 映射顏色字串到由 DesignSystem 定義的顏色
    private var bgColor: Color {
        switch color {
        case "yellow": return Color(hex: "FFD54F")   // Light warm yellow
        case "orange": return Color(hex: "F5A623")   // Deep golden orange
        case "red": return Color(hex: "E74C3C")      // Vivid red
        case "blue": return PuboColors.navy           // Dark navy
        default: return PuboColors.yellow
        }
    }
    
    // Text color — title always white
    private var textColor: Color {
        return .white
    }
    
    private var subTextColor: Color {
        switch color {
        case "blue", "red": return .white.opacity(0.7)
        default: return .black.opacity(0.6)
        }
    }
    
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // Shadow Layer
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.black)
                .offset(x: 5, y: 5)
            
            // Main Card Layer
            VStack(spacing: 0) {
                // Handle Decoration
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 48, height: 4)
                    .padding(.top, 12)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(textColor)
                            .textCase(.uppercase)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(date)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(subTextColor)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(subTextColor)
                                Text("\(spotsCount) 個景點")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(subTextColor)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    // Share Button — triggers iOS share sheet
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.2), radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                
                Spacer().frame(height: 30) // Taller card so overlap shows info
            }
            .background(bgColor)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["看看我的旅程：\(title) \(date)"])
        }
    }
}

