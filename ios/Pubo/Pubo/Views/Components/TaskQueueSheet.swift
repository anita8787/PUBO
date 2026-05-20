import SwiftUI
import SwiftData

struct TaskQueueSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @Query(sort: \SDOfflineTask.createdAt, order: .reverse)
    var offlineTasks: [SDOfflineTask]
    
    var body: some View {
        NavigationStack {
            List {
                if offlineTasks.isEmpty {
                    Text("目前沒有背景任務")
                        .foregroundColor(.gray)
                } else {
                    ForEach(offlineTasks) { task in
                        HStack(spacing: 12) {
                            if task.taskType == "link_import" {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.purple)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(task.taskType == "link_import" ? "貼文連結分析" : "截圖智能辨識")
                                    .font(.headline)
                                
                                if let error = task.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .lineLimit(2)
                                } else if let payload = task.payload {
                                    Text(payload)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if task.status == "processing" {
                                ProgressView()
                            } else if task.status == "completed" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if task.status == "failed" {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
            .navigationTitle("背景任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
                
                if !offlineTasks.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("清除已完成") {
                            clearCompleted()
                        }
                    }
                }
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        for index in offsets {
            let task = offlineTasks[index]
            context.delete(task)
            // If it was a screenshot, try deleting the cached file
            if task.taskType == "screenshot_upload", let path = task.payload {
                let url = URL(fileURLWithPath: path)
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? context.save()
        BackgroundTaskManager.shared.updateQueueStatus(context: context)
    }
    
    private func clearCompleted() {
        for task in offlineTasks where task.status == "completed" {
            context.delete(task)
        }
        try? context.save()
        BackgroundTaskManager.shared.updateQueueStatus(context: context)
    }
}
