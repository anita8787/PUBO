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
            container = try ModelContainer(for: 
                SDContent.self, 
                SDPlace.self,
                SDTrip.self,
                SDItineraryDay.self,
                SDItinerarySpot.self
            )
        } catch {
            fatalError("Failed to ModelContainer: \(error)")
        }
    }
    
    @StateObject private var tripManager = TripManager()
    
    // Floating Inbox States
    @State private var isProcessing: Bool = false
    @State private var readyImport: PendingImport?

    var body: some Scene {
        WindowGroup {
            ZStack {
                NewHomeView()
                    .environmentObject(tripManager)
                    .modelContainer(container)
                    .onAppear {
                        DataService.shared.setContext(container.mainContext)
                        tripManager.modelContext = container.mainContext
                        // Initial sync check if trips already exist in manager
                        tripManager.refreshTrips()
                    }
                    .onOpenURL { url in
                        print("🔗 Open URL: \(url)")
                        if url.scheme == "pubo", let host = url.host, host == "task" {
                            let taskId = url.lastPathComponent
                            print("📥 Received Task ID: \(taskId)")
                            
                            // 顯示懸浮處理 Box
                            isProcessing = true
                            readyImport = nil
                            
                            // 呼叫 DataService 抓取資料 (Polling)
                            Task {
                                if let (content, places) = await DataService.shared.pollTaskResult(taskId: taskId) {
                                    // 成功抓取後，設定為 Ready 狀態，等待使用者點擊
                                    await MainActor.run {
                                        self.isProcessing = false
                                        self.readyImport = PendingImport(content: content, places: places)
                                    }
                                } else {
                                    // 失敗或超時
                                    await MainActor.run {
                                        self.isProcessing = false
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
                
                // 懸浮任務收件匣
                if isProcessing || readyImport != nil {
                    FloatingTaskInbox(
                        isProcessing: isProcessing,
                        hasResult: readyImport != nil,
                        onTap: {
                            if let ready = readyImport {
                                pendingImport = ready
                                readyImport = nil
                            }
                        }
                    )
                    .zIndex(100) // 確保在最上層
                }
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
