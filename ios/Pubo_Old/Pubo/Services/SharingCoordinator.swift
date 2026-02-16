import Foundation

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
        // 略：實作 URLSession POST /api/v1/share
        // 為了展示邏輯，這裡回傳一個模擬 taskId
        return "mock_task_id"
    }
    
    private func pollTaskStatus(taskId: String) async throws -> ExtractionResponse {
        // 略：實作輪詢邏輯 (每一秒檢查一次 /api/v1/task/{id})
        // 模擬成功返回
        let mockContent = Content(id: 1, sourceType: .instagram, sourceUrl: "...", title: "模擬標籤", text: "...", authorName: "...", authorAvatarUrl: nil, previewThumbnailUrl: nil, publishedAt: nil, userTags: [])
        let mockSuggestions = [
            ContentPlaceInfo(place: Place(id: nil, placeId: "temp_1", name: "台北101", address: nil, latitude: 0, longitude: 0, category: nil), evidence_text: "提到台北101", confidenceScore: 0.9)
        ]
        return ExtractionResponse(content: mockContent, suggestedPlaces: mockSuggestions)
    }
}
