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
            }
            
            // Main content
            content()
                .background(Color(hex: "FDFAEE"))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
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
                            let translation = value.translation.width
                            withAnimation(.easeOut(duration: 0.2)) {
                                if translation < -fullSwipeThreshold {
                                    // Full swipe — delete immediately
                                    offset = -1000
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onDelete()
                                    }
                                } else if translation < -40 {
                                    // Partial swipe — reveal delete button
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
