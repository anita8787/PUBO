import SwiftUI

struct ExploreCardView: View {
    let imageUrl: String
    let tag: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            AsyncImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 120, height: 160)
            .clipped()
            
            // Gradient Overlay
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            
            // Tag Text
            Text(tag)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 120, height: 160)
        .cornerRadius(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.black, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Preview
struct ExploreCardView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreCardView(
            imageUrl: "https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?q=80&w=1740&auto=format&fit=crop",
            tag: "富士山"
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
