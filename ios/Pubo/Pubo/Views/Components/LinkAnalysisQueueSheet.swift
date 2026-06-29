import SwiftUI

struct LinkAnalysisQueueSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataService = DataService.shared
    
    @State private var selectedImportTask: LinkAnalysisTask? = nil
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !dataService.activeLinkTasks.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Text("💡")
                            .font(.system(size: 14))
                        
                        Text("提示：")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        + Text("每篇貼文因內容長度分析時間不同。您可以先關閉彈窗繼續使用其他功能，貼文會陸續在背景分析完成！")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color(hex: "F2F2F7"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, 16)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        if dataService.activeLinkTasks.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 80)
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("目前沒有分析中的貼文")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                                Text("您可以至「連結識別」輸入多個網址，即可在此即時掌控分析狀態。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Spacer()
                            }
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(dataService.activeLinkTasks) { task in
                                    QueueTaskCard(task: task) {
                                        if task.status == .completed && !task.isImported {
                                            selectedImportTask = task
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .background(PuboColors.background.opacity(0.5))
            }
            .navigationTitle("分析中的貼文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                }
                
                if !dataService.activeLinkTasks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("清除已完成") {
                            withAnimation {
                                dataService.clearCompletedTasks()
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $selectedImportTask) { task in
                if let content = task.content {
                    ImportView(
                        content: content,
                        suggestedPlaces: task.places,
                        onConfirm: { selectedPlaces in
                            Task {
                                DataService.shared.saveContent(content, relatedPlaces: selectedPlaces)
                                // 標記為已匯入
                                if let index = DataService.shared.activeLinkTasks.firstIndex(where: { $0.id == task.id }) {
                                    DataService.shared.activeLinkTasks[index].isImported = true
                                    let copy = DataService.shared.activeLinkTasks
                                    DataService.shared.activeLinkTasks = copy
                                }
                                selectedImportTask = nil
                            }
                        },
                        onCancel: {
                            selectedImportTask = nil
                        }
                    )
                }
            }
        }
    }
}

struct QueueTaskCard: View {
    let task: LinkAnalysisTask
    let onTap: () -> Void
    @ObservedObject var dataService = DataService.shared
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                cardBody
                
                // 右上角狀態角標
                if task.status == .completed {
                    if task.isImported {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("已收藏")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(6)
                        .padding(6)
                        .shadow(radius: 1)
                    } else {
                        Button(action: onTap) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("待確認")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PuboColors.navy)
                            .cornerRadius(6)
                            .padding(6)
                            .shadow(radius: 1)
                        }
                    }
                }
            }
            .onTapGesture {
                if task.status == .completed && !task.isImported {
                    onTap()
                }
            }
            
            // 下方文字資訊
            infoArea
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
        .onLongPressGesture {
            showDeleteAlert = true
        }
        .alert("確定要清除此篇貼文嗎？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                withAnimation {
                    dataService.deleteTask(id: task.id)
                }
            }
        } message: {
            Text("清除後將無法復原，需重新分析。")
        }
    }
    
    @ViewBuilder
    private var cardBody: some View {
        switch task.status {
        case .pending, .analyzing:
            pendingOrAnalyzingView
        case .failed:
            failedView
        case .completed:
            completedView
        }
    }
    
    @ViewBuilder
    private var pendingOrAnalyzingView: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(PuboColors.navy)
                
                VStack(spacing: 4) {
                    Text(task.status == .pending ? "排隊中..." : "分析中...")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(PuboColors.navy)
                    
                    if task.progress > 0 {
                        Text("\(Int(task.progress * 100))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(PuboColors.navy.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
        )
    }
    
    @ViewBuilder
    private var failedView: some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.03))
            
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red.opacity(0.7))
                
                Text(task.errorMessage ?? "分析失敗")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.red.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(3)
                
                HStack(spacing: 12) {
                    Button(action: {
                        dataService.retryTask(id: task.id)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(PuboColors.navy))
                    }
                    
                    Button(action: {
                        dataService.deleteTask(id: task.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.gray))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.2), lineWidth: 1.5)
        )
    }
    
    @ViewBuilder
    private var completedView: some View {
        if let content = task.content {
            ZStack {
                if let urlStr = content.previewThumbnailUrl, !urlStr.isEmpty {
                    CachedAsyncImage(url: URL(string: urlStr)) { img in
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
                            .clipped()
                    } placeholder: {
                        ZStack {
                            Rectangle().fill(Color.gray.opacity(0.08))
                            ProgressView()
                        }
                    }
                } else {
                    ZStack {
                        Color(hex: "F9F9F9")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(content.text ?? "筆記內容")
                                .font(.system(size: 9))
                                .foregroundColor(.gray.opacity(0.8))
                                .lineLimit(6)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(10)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        } else {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.05))
                Text("無內容")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200)
            .cornerRadius(14)
        }
    }
    
    @ViewBuilder
    private var infoArea: some View {
        if task.status == .completed, let content = task.content {
            VStack(alignment: .leading, spacing: 4) {
                // 標題
                Text(content.title ?? "未命名")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 6) {
                    // 平台 Icon
                    getPlatformIcon(source: content.sourceType.rawValue)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    
                    // 作者名稱
                    if let author = content.authorName, !author.isEmpty {
                        Text(author)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 相對時間
                    Text(timeAgo(from: task.createdAt))
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(.horizontal, 4)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.url)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func getPlatformIcon(source: String) -> Image {
        switch source.lowercased() {
        case "youtube": return Image("platform-youtube")
        case "instagram": return Image("platform-instagram")
        case "threads": return Image("platform-threads")
        case "plain_text": return Image(systemName: "doc.text.fill")
        default: return Image(systemName: "link.circle.fill")
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
