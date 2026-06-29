import SwiftUI

struct PostManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataService = DataService.shared
    @State private var isDeletingId: String? = nil
    
    var myPosts: [CuratedPost] {
        let currentUserId = AuthManager.shared.currentUID
        return dataService.curatedPosts.filter { $0.uploaderId == currentUserId }
    }

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

            if myPosts.isEmpty {
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(myPosts) { post in
                            postRow(post)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(PuboColors.background)
        .onAppear {
            dataService.fetchCuratedPosts()
        }
    }
    
    private func postRow(_ post: CuratedPost) -> some View {
        HStack(spacing: 16) {
            if let cover = post.coverImageUrl, let url = URL(string: cover) {
                CachedAsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title).font(.system(size: 16, weight: .bold)).foregroundColor(.black).lineLimit(1)
                Text(post.author ?? "未知作者").font(.system(size: 12)).foregroundColor(.gray)
            }
            
            Spacer()
            
            Button {
                deletePost(post.id)
            } label: {
                if isDeletingId == post.id {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("下架")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .disabled(isDeletingId != nil)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private func deletePost(_ id: String) {
        isDeletingId = id
        Task {
            do {
                try await dataService.deleteCuratedPost(postId: id)
            } catch {
                print("Delete failed: \(error)")
            }
            await MainActor.run {
                isDeletingId = nil
            }
        }
    }
}
