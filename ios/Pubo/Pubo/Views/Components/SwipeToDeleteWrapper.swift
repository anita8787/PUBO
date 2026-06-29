import SwiftUI

/// A reusable wrapper that adds swipe-to-reveal-delete functionality to any content.
/// Swipe left to reveal an "X" delete button; swipe far enough for full swipe delete.
struct SwipeToDeleteWrapper<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    private let deleteButtonWidth: CGFloat = 64
    private let fullSwipeThreshold: CGFloat = 160
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed behind the content
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(PuboColors.red)
                        .padding(.trailing, 24)
                }
                .opacity(offset < -5 ? 1 : 0)
            }
            
            // Main content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            // Prevent horizontal swipe trigger if the user is dragging vertically (e.g., reordering)
                            if !isSwiped && abs(value.translation.height) > abs(value.translation.width) { return }
                            
                            let translation = value.translation.width
                            if translation < 0 {
                                // Swiping left
                                offset = isSwiped ? -deleteButtonWidth + translation : translation
                            } else if isSwiped {
                                // Swiping right to close
                                offset = -deleteButtonWidth + translation
                                if offset > 0 { offset = 0 }
                            }
                        }
                        .onEnded { value in
                            let predictedOffset = offset + value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if predictedOffset < -40 {
                                    // Swipe enough to reveal delete button
                                    offset = -deleteButtonWidth
                                    isSwiped = true
                                } else {
                                    // Not enough — snap back
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
