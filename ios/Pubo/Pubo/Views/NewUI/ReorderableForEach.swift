import SwiftUI

public struct ReorderableForEach<Item: Identifiable & Equatable, Content: View>: View {
    @Binding var items: [Item]
    let content: (Item) -> Content
    let onMove: (IndexSet, Int) -> Void
    
    @State private var draggingItem: Item?
    @State private var dragOffset: CGFloat = 0
    @State private var hoveredItem: Item?
    
    public init(
        items: Binding<[Item]>,
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._items = items
        self.onMove = onMove
        self.content = content
    }
    
    public var body: some View {
        LazyVStack(spacing: 24) {
            ForEach(items) { item in
                content(item)
                    .offset(y: draggingItem == item ? dragOffset : 0)
                    .zIndex(draggingItem == item ? 1000 : 0)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .sequenced(before: DragGesture(coordinateSpace: .global))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if draggingItem == nil {
                                        draggingItem = item
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                    if let drag = drag {
                                        dragOffset = drag.translation.height
                                        
                                        // Simple hit testing logic based on average height (approx 150)
                                        // It's better to just use onMove but we simulate it.
                                        let step: CGFloat = 150
                                        let offsetSlots = Int(round(drag.translation.height / step))
                                        
                                        if let currentIndex = items.firstIndex(of: item) {
                                            let newIndex = min(max(currentIndex + offsetSlots, 0), items.count - 1)
                                            if newIndex != currentIndex {
                                                withAnimation(.default) {
                                                    onMove(IndexSet(integer: currentIndex), newIndex > currentIndex ? newIndex + 1 : newIndex)
                                                }
                                                // Reset drag offset base so it doesn't jump
                                                // This is tricky, a simplified version is better.
                                            }
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in
                                withAnimation {
                                    draggingItem = nil
                                    dragOffset = 0
                                }
                            }
                    )
            }
        }
    }
}
