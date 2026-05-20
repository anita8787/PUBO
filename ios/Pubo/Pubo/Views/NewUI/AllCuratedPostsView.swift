import SwiftUI

struct AllCuratedPostsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataService: DataService
    @Binding var selectedCuratedPost: CuratedPost?
    
    // Split the posts into two columns for the waterfall effect
    var leftColumnPosts: [CuratedPost] {
        stride(from: 0, to: dataService.curatedPosts.count, by: 2).map { dataService.curatedPosts[$0] }
    }
    
    var rightColumnPosts: [CuratedPost] {
        stride(from: 1, to: dataService.curatedPosts.count, by: 2).map { dataService.curatedPosts[$0] }
    }
    
    var body: some View {
        ZStack {
            PuboColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .retroShadow(color: .black.opacity(0.15), offset: 2.5)
                    }
                    
                    Spacer()
                    
                    Text("推薦行程")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(PuboColors.navy)
                    
                    Spacer()
                    
                    // Empty spacer to balance the back button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Waterfall Content
                ScrollView(showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        // Left Column
                        VStack(spacing: 12) {
                            ForEach(leftColumnPosts) { post in
                                RecommendationCard(post: post, isFullWidth: true)
                                    .onTapGesture {
                                        selectedCuratedPost = post
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right Column
                        VStack(spacing: 12) {
                            ForEach(rightColumnPosts) { post in
                                RecommendationCard(post: post, isFullWidth: true)
                                    .onTapGesture {
                                        selectedCuratedPost = post
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}
