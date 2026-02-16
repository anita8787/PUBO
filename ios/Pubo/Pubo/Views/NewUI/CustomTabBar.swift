import SwiftUI

struct CustomTabBar: View {
    @Binding var activeTab: Int // 0: Map, 1: Home/Add, 2: Itinerary
    var onAddClick: () -> Void
    
    var body: some View {
        ZStack {
            // Background Container
            HStack(spacing: 0) {
                // Left: Map
                Button(action: { activeTab = 0 }) {
                    Image(systemName: "map")
                        .font(.system(size: 24))
                        .foregroundColor(activeTab == 0 ? PuboColors.navy : .gray)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer().frame(width: 80) // Space for the center button
                
                // Right: Itinerary
                Button(action: { activeTab = 2 }) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 24))
                        .foregroundColor(activeTab == 2 ? PuboColors.cardOrange : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 220, height: 64)
            .background(Color.white)
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.black, lineWidth: 2)
            )
            .retroShadow(color: .black.opacity(0.2))
            
            // Center: Plus Button
            Button(action: onAddClick) {
                ZStack {
                    Circle()
                        .fill(PuboColors.yellow)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .retroShadow(color: .black.opacity(0.2))
                    
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .offset(y: -20) // Protrude upwards
        }
        .padding(.bottom, 32)
    }
}

// Preview
struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        CustomTabBar(activeTab: .constant(1), onAddClick: {})
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
