import SwiftUI

struct ReorderableVStack<Item: Identifiable & Equatable, Content: View>: View {
    @Binding var items: [Item]
    let content: (Item) -> Content
    
    @State private var draggingItem: Item?
    @State private var hasStartedDragging = false
    
    var body: some View {
        VStack(spacing: 24) {
            ForEach(items) { item in
                content(item)
                    .opacity(draggingItem == item ? 0.0 : 1.0)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    // Could track frames here if needed
                                }
                        }
                    )
            }
        }
    }
}
