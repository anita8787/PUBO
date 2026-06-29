import SwiftUI
import UIKit

struct ScrollTarget: Equatable {
    let id: String
    let trigger = UUID()
}

struct ReorderableViewWrapper<Content: View>: View {
    let content: Content
    let item: ItinerarySpot
    @Binding var items: [ItinerarySpot]
    @Binding var draggingItem: ItinerarySpot?
    @Binding var scrollTarget: ScrollTarget?
    let onMove: (IndexSet, Int) -> Void
    
    @State private var dragOffset: CGFloat = 0.0
    @State private var isLongPressing: Bool = false
    @State private var dragStartBase: CGFloat = 0.0
    @GestureState private var isGestureActive: Bool = false
    
    @State private var autoscrollTimer: Timer? = nil
    @State private var latestTotalDrag: CGFloat = 0.0
    
    var body: some View {
        let isDragging = (draggingItem?.id == item.id)
        
        let gesture = LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($isGestureActive) { value, state, transaction in
                state = true
            }
            .onChanged { value in
                switch value {
                case .second(_, let drag):
                    if draggingItem == nil {
                        draggingItem = item
                        isLongPressing = false
                        dragStartBase = 0.0
                        latestTotalDrag = 0.0
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    if let drag = drag {
                        let totalDrag: CGFloat = drag.translation.height
                        latestTotalDrag = totalDrag
                        dragOffset = totalDrag - dragStartBase
                        
                        // Check for boundaries to trigger autoscroll
                        checkAutoscroll(dragLocation: drag.location)
                        
                        let direction: CGFloat = dragOffset > 0.0 ? 1.0 : -1.0
                        if let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
                            let targetIndex = currentIndex + Int(direction)
                            if targetIndex >= 0 && targetIndex < items.count {
                                let targetItem = items[targetIndex]
                                let isTargetLast = (targetIndex == items.count - 1)
                                let targetHeight = targetItem.estimatedHeight(isLast: isTargetLast)
                                
                                if abs(dragOffset) > targetHeight * 0.6 {
                                    let moveToIndex = direction > 0.0 ? targetIndex + 1 : targetIndex
                                    dragStartBase += direction * targetHeight
                                    dragOffset = totalDrag - dragStartBase
                                    onMove(IndexSet(integer: currentIndex), moveToIndex)
                                    
                                    // Trigger parent scrolling
                                    scrollTarget = ScrollTarget(id: item.id)
                                    
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                resetState()
            }
            
        return content
            .offset(y: isDragging ? dragOffset : 0.0)
            .scaleEffect(isDragging ? 0.90 : 1.0)
            .zIndex(isDragging ? 1000.0 : 0.0)
            .shadow(color: isDragging ? Color.black.opacity(0.15) : Color.clear, radius: 10.0, y: 5.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDragging)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dragOffset)
            .gesture(gesture)
            .onChange(of: isGestureActive) { _, newValue in
                if !newValue && draggingItem?.id == item.id {
                    resetState()
                }
            }
    }
    
    private func resetState() {
        stopAutoscroll()
        if draggingItem?.id == item.id {
            draggingItem = nil
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            dragOffset = 0.0
        }
        dragStartBase = 0.0
        latestTotalDrag = 0.0
        isLongPressing = false
    }
    
    private func checkAutoscroll(dragLocation: CGPoint) {
        let screenHeight = UIScreen.main.bounds.height
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        let safeAreaTop = keyWindow?.safeAreaInsets.top ?? 47.0
        let safeAreaBottom = keyWindow?.safeAreaInsets.bottom ?? 34.0
        
        let topThreshold = safeAreaTop + 220.0
        let bottomThreshold = screenHeight - safeAreaBottom - 80.0
        
        if dragLocation.y < topThreshold {
            startAutoscroll(direction: -1)
        } else if dragLocation.y > bottomThreshold {
            startAutoscroll(direction: 1)
        } else {
            stopAutoscroll()
        }
    }
    
    private func startAutoscroll(direction: Int) {
        guard autoscrollTimer == nil else { return }
        
        autoscrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
            
            let targetIndex = currentIndex + direction
            if targetIndex >= 0 && targetIndex < items.count {
                let targetSpot = items[targetIndex]
                let isTargetLast = (targetIndex == items.count - 1)
                let targetHeight = targetSpot.estimatedHeight(isLast: isTargetLast)
                
                let moveToIndex = direction > 0 ? targetIndex + 1 : targetIndex
                dragStartBase += CGFloat(direction) * targetHeight
                dragOffset = latestTotalDrag - dragStartBase
                onMove(IndexSet(integer: currentIndex), moveToIndex)
                
                scrollTarget = ScrollTarget(id: item.id)
                
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                stopAutoscroll()
            }
        }
    }
    
    private func stopAutoscroll() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
    }
}

extension ItinerarySpot {
    func estimatedHeight(isLast: Bool) -> CGFloat {
        var h: CGFloat = 115.0
        if !isLast {
            h += 12.0 // Gap between card and gap content
            
            var gapHeight: CGFloat = 0.0
            if let notes = notes, !notes.isEmpty {
                gapHeight += 50.0 // Estimated notes height
            }
            gapHeight += 56.0 // Transport button height (32 height + 12 * 2 padding)
            
            h += max(gapHeight, 40.0) // minHeight: 40
            h += 24.0 // VStack spacing
        }
        return h
    }
}

extension View {
    func customReorderable(
        item: ItinerarySpot,
        items: Binding<[ItinerarySpot]>,
        draggingItem: Binding<ItinerarySpot?>,
        scrollTarget: Binding<ScrollTarget?>,
        onMove: @escaping (IndexSet, Int) -> Void
    ) -> some View {
        ReorderableViewWrapper(
            content: self,
            item: item,
            items: items,
            draggingItem: draggingItem,
            scrollTarget: scrollTarget,
            onMove: onMove
        )
    }
}
