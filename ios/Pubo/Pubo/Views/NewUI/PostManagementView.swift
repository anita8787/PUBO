import SwiftUI

struct PostManagementView: View {
    @Environment(\.dismiss) var dismiss
    // In the future, this will be populated from the user's uploaded curated posts
    // For now, we read from UserDefaults the list of post IDs the user shared
    @State private var uploadedPostIds: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("貼文管理").font(.system(size: 18, weight: .black)).foregroundColor(PuboColors.navy)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                            .frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)

            // Empty state
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "flag.slash")
                    .font(.system(size: 48)).foregroundColor(.gray.opacity(0.4))
                Text("您尚未分享任何行程靈感")
                    .font(.system(size: 18, weight: .black)).foregroundColor(PuboColors.navy)
                Text("當您將貼文分享到推薦區塊後，\n可在此管理或下架您的貼文。")
                    .font(.system(size: 14)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(PuboColors.background)
        }
        .background(PuboColors.background)
    }
}
