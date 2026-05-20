import Foundation
import SwiftData
import Combine

@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    @Published var activeTaskCount: Int = 0
    @Published var pendingTaskCount: Int = 0
    
    private init() {}
    
    /// 更新佇列狀態供 UI (紅點) 使用
    func updateQueueStatus(context: ModelContext) {
        let descriptor = FetchDescriptor<SDOfflineTask>(predicate: #Predicate { $0.status == "pending" || $0.status == "processing" })
        if let tasks = try? context.fetch(descriptor) {
            self.pendingTaskCount = tasks.filter { $0.status == "pending" }.count
            self.activeTaskCount = tasks.filter { $0.status == "processing" }.count
        }
    }
    
    /// 新增連結任務
    func addLinkTask(url: String, context: ModelContext) {
        let task = SDOfflineTask(taskType: "link_import", payload: url)
        context.insert(task)
        try? context.save()
        updateQueueStatus(context: context)
        
        // 如果有網路，直接觸發
        if NetworkMonitor.shared.isConnected {
            processQueue(context: context)
        }
    }
    
    /// 新增截圖任務 (需傳入已存入本地的圖片路徑)
    func addScreenshotTask(imagePath: String, context: ModelContext) {
        let task = SDOfflineTask(taskType: "screenshot_upload", payload: imagePath)
        context.insert(task)
        try? context.save()
        updateQueueStatus(context: context)
        
        if NetworkMonitor.shared.isConnected {
            processQueue(context: context)
        }
    }
    
    /// 處理佇列
    func processQueue(context: ModelContext) {
        guard NetworkMonitor.shared.isConnected else { return }
        
        let descriptor = FetchDescriptor<SDOfflineTask>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "failed" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        guard let tasks = try? context.fetch(descriptor), !tasks.isEmpty else { return }
        
        for task in tasks {
            task.status = "processing"
        }
        try? context.save()
        updateQueueStatus(context: context)
        
        Task {
            for offlineTask in tasks {
                do {
                    if offlineTask.taskType == "link_import", let url = offlineTask.payload {
                        // 呼叫 DataService 處理
                        print("📡 [BackgroundQueue] Processing Link Import: \(url)")
                        let taskId = try await DataService.shared.submitShareTask(url: url)
                        // 這裡可以選擇不 poll，或者 poll 到結果存入資料庫
                        if let (content, places) = await DataService.shared.pollTaskResult(taskId: taskId, maxRetries: 30) {
                            DataService.shared.saveContent(content, relatedPlaces: places)
                            offlineTask.status = "completed"
                        } else {
                            offlineTask.status = "failed"
                            offlineTask.errorMessage = "Polling timeout or failed"
                        }
                    } else if offlineTask.taskType == "screenshot_upload", let path = offlineTask.payload {
                        // 讀取圖片
                        let url = URL(fileURLWithPath: path)
                        if let data = try? Data(contentsOf: url) {
                            print("📡 [BackgroundQueue] Processing Screenshot Upload")
                            let result = try await DataService.shared.analyzeScreenshot(imageData: data)
                            DataService.shared.saveContent(result.0, relatedPlaces: result.1)
                            offlineTask.status = "completed"
                            // 刪除快取圖片
                            try? FileManager.default.removeItem(at: url)
                        } else {
                            offlineTask.status = "failed"
                            offlineTask.errorMessage = "File not found"
                        }
                    }
                } catch {
                    offlineTask.status = "failed"
                    offlineTask.errorMessage = error.localizedDescription
                }
                
                await MainActor.run {
                    try? context.save()
                    updateQueueStatus(context: context)
                }
            }
        }
    }
}
