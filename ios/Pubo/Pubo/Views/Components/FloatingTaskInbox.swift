import SwiftUI

struct FloatingTaskInbox: View {
    var isProcessing: Bool
    var hasResult: Bool
    var onTap: () -> Void
    
    @State private var dragAmount: CGSize = .zero
    @State private var position: CGSize = CGSize(width: UIScreen.main.bounds.width / 2 - 40, height: -100) // Default top right
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        Button(action: {
            if hasResult {
                onTap()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // Main Circle
                ZStack {
                    Circle()
                        .fill(Color(hex: "FDFAEE"))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    
                    // Inbox Icon
                    Image(systemName: "tray.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "023B7E")) // PuboColors.navy
                    
                    // Progress Spinner Layer
                    if isProcessing {
                        Circle()
                            .trim(from: 0.1, to: 0.9)
                            .stroke(Color(hex: "FFC649"), style: StrokeStyle(lineWidth: 3, lineCap: .round)) // PuboColors.yellow
                            .frame(width: 62, height: 62)
                            .rotationEffect(Angle(degrees: rotationAngle))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360.0
                                }
                            }
                    }
                    
                    // Full Ring when done
                    if hasResult {
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 62, height: 62)
                    }
                }
                
                // Red Dot Notification
                if hasResult {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: position.width + dragAmount.width, y: position.height + dragAmount.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragAmount = value.translation
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        position.width += dragAmount.width
                        position.height += dragAmount.height
                        dragAmount = .zero
                        
                        // Limit dragging within screen bounds
                        let screenWidth = UIScreen.main.bounds.width
                        let screenHeight = UIScreen.main.bounds.height
                        
                        if position.width > screenWidth / 2 - 30 { position.width = screenWidth / 2 - 30 }
                        if position.width < -screenWidth / 2 + 30 { position.width = -screenWidth / 2 + 30 }
                        if position.height > screenHeight / 2 - 30 { position.height = screenHeight / 2 - 30 }
                        if position.height < -screenHeight / 2 + 30 { position.height = -screenHeight / 2 + 30 }
                    }
                }
        )
    }
}
