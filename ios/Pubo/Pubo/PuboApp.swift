//
//  PuboApp.swift
//  Pubo
//
//  Created by 陳采葳 on 2026/2/8.
//

import SwiftUI
import SwiftData

@main
struct PuboApp: App {
    let container: ModelContainer
    @State private var pendingImport: PendingImport?
    
    init() {
        do {
            container = try ModelContainer(for: SDContent.self, SDPlace.self)
        } catch {
            fatalError("Failed to ModelContainer: \(error)")
        }
    }
    
    @StateObject private var tripManager = TripManager()

    var body: some Scene {
        WindowGroup {
            NewHomeView()
                .environmentObject(tripManager)
                .modelContainer(container)
                .onAppear {
                    DataService.shared.setContext(container.mainContext)
                }
                .onOpenURL { url in
                    print("🔗 Open URL: \(url)")
                    if url.scheme == "pubo", let host = url.host, host == "task" {
                        let taskId = url.lastPathComponent
                        print("📥 Received Task ID: \(taskId)")
                        
                        // 呼叫 DataService 抓取資料 (Polling)
                        Task {
                            if let (content, places) = await DataService.shared.pollTaskResult(taskId: taskId) {
                                // 成功抓取後，設定 pendingImport 以觸發 Sheet
                                await MainActor.run {
                                    self.pendingImport = PendingImport(content: content, places: places)
                                }
                            }
                        }
                    }
                }
                .sheet(item: $pendingImport) { data in
                    ImportView(
                        content: data.content,
                        suggestedPlaces: data.places,
                        onConfirm: { selectedPlaces in
                            // 使用者確認匯入
                            Task {
                                DataService.shared.saveContent(data.content, relatedPlaces: selectedPlaces)
                                self.pendingImport = nil
                            }
                        },
                        onCancel: {
                            // 使用者取消
                            self.pendingImport = nil
                        }
                    )
                }
        }
    }
}

// 用於 Sheet 顯示的 Wrapper
struct PendingImport: Identifiable {
    let id = UUID()
    let content: Content
    let places: [ContentPlaceInfo]
}
