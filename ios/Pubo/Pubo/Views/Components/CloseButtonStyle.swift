import SwiftUI

/// Custom ButtonStyle for the close (X) button used in modals.
/// It displays the "x" image and changes to a red background with a white cross when pressed.
struct CloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if configuration.isPressed {
                // 按下的狀態：底色變紅，叉叉變白 (因為多色 SVG 無法直接改，所以按下時我們畫給它)
                ZStack {
                    Circle()
                        .fill(PuboColors.red)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                // 原本的狀態：完全顯示上傳的 "x.svg"，不套用 template
                Image("x")
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
            }
        }
        .frame(width: 32, height: 32)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
