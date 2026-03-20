import SwiftUI

struct FloatingTaskInbox: View {
    var isProcessing: Bool
    var hasResult: Bool
    var onTap: () -> Void
    
    @State private var dragAmount: CGSize = .zero
    @State private var position: CGSize = CGSize(width: 150, height: -100) // Default top right
    @State private var progress: CGFloat = 0.0

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
                        .fill(Color.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    
                    // Inbox Icon
                    Image(systemName: "tray.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "023B7E")) // PuboColors.navy
                        .overlay(
                            // Red Dot Notification attached directly to the icon
                            Group {
                                if hasResult {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8) // slightly smaller relative to the icon
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1.0))
                                        .offset(x: 4, y: -4) // pull it closer
                                }
                            },
                            alignment: .topTrailing
                        )
                    
                    // Progress Spinner Layer -> Loading bar fill
                    if isProcessing {
                        Circle()
                            .trim(from: 0.0, to: progress)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 62, height: 62)
                            .rotationEffect(Angle(degrees: -90))
                            .onAppear {
                                progress = 0.0
                                withAnimation(Animation.easeInOut(duration: 8.0)) {
                                    progress = 0.95
                                }
                            }
                    }
                    
                    // Full Ring when done -> Red border
                    if hasResult {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 62, height: 62)
                    }
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
                        
                        // Limit dragging within screen bounds and snap to edges
                        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                        let screenRect = windowScene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 400, height: 800)
                        let screenWidth = screenRect.width
                        let screenHeight = screenRect.height
                        
                        // Snap logic
                        if position.width > 0 {
                            position.width = screenWidth / 2 - 40 // Snap right
                        } else {
                            position.width = -screenWidth / 2 + 40 // Snap left
                        }
                        
                        // Vertical constraint
                        if position.height > screenHeight / 2 - 50 { position.height = screenHeight / 2 - 50 }
                        if position.height < -screenHeight / 2 + 50 { position.height = -screenHeight / 2 + 50 }
                    }
                }
        )
    }
}
