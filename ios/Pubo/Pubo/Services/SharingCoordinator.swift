import Foundation
import Combine
import SwiftUI

class SharingCoordinator: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var alignmentResults: [AutoAlignmentService.AlignedResult] = []
    @Published var error: String? = nil
    
    private let autoAligner = AutoAlignmentService()
    
    /// 啟動完整的分享與對齊流程
    func startSharingFlow(url: URL) async {
        DispatchQueue.main.async {
            self.isProcessing = true
            self.error = nil
            self.alignmentResults = []
        }
        
        do {
            // 1. 提交任務到後端
            print("📤 [AGENT_VERIFIED_SharingCoordinator] Submitting task...")
            let taskId = try await submitTask(url: url)
            
            // 2. 輪詢任務狀態
            let extractionResult = try await pollTaskStatus(taskId: taskId)
            
            // 3. 自動執行 MapKit 對齊落地
            let results = await autoAligner.alignPlaces(suggestions: extractionResult.suggestedPlaces)
            
            DispatchQueue.main.async {
                self.alignmentResults = results
                self.isProcessing = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isProcessing = false
            }
        }
    }
    
    // --- 私有輔助函數 ---
    
    private func submitTask(url: URL) async throws -> String {
        return try await DataService.shared.submitShareTask(url: url.absoluteString)
    }
    
    private func pollTaskStatus(taskId: String) async throws -> ExtractionResponse {
        // Use DataService to poll the real backend result
        guard let (content, suggestedPlaces) = await DataService.shared.pollTaskResult(taskId: taskId) else {
            throw NSError(domain: "PuboError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task failed or timed out"])
        }
        
        return ExtractionResponse(content: content, suggestedPlaces: suggestedPlaces)
    }
}

