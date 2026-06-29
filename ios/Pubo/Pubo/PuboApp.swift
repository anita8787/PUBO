//
//  PuboApp.swift
//  Pubo
//
//  Created by 陳采葳 on 2026/2/8.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase 連線成功")
        return true
    }
}
@main
struct PuboApp: App {
    let container: ModelContainer
    @State private var pendingImport: PendingImport?
    @State private var showTaskQueue: Bool = false
    @State private var showLinkQueueSheet: Bool = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() {
        do {
            let schema = Schema([
                SDContent.self,
                SDPlace.self,
                SDTrip.self,
                SDItineraryDay.self,
                SDItinerarySpot.self,
                SDOfflineTask.self
            ])
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.anita.Pubo")!
            let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            
            // 確保資料夾存在，否則實體機會報錯 (Sandbox access to file-write-create denied)
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            
            // 輕量級 Migration：新增欄位有預設値，不需要資料転移
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to ModelContainer: \(error)")
        }
    }
    
    @StateObject private var tripManager = TripManager()
    @StateObject private var dataService = DataService.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var pendingJoinCode: String? = nil
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isSignedIn {
                    NewHomeView()
                    .environmentObject(tripManager)
                    .environmentObject(dataService)
                    .environmentObject(locationManager)
                    .environmentObject(networkMonitor)
                    .environmentObject(backgroundTaskManager)
                    .modelContainer(container)
                    .onAppear {
                        DataService.shared.setContext(container.mainContext)
                        networkMonitor.setContext(container.mainContext)
                        backgroundTaskManager.updateQueueStatus(context: container.mainContext)
                        tripManager.modelContext = container.mainContext
                        tripManager.refreshTrips()
                        locationManager.requestPermission()
                        
                        // Sync App Group Data on first launch
                        dataService.syncPendingPlaceActions(tripManager: tripManager)
                        dataService.syncTripsToAppGroup()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            DataService.shared.processPendingShareTasks()
                            DataService.shared.syncPendingPlaceActions(tripManager: tripManager)
                            DataService.shared.syncTripsToAppGroup()
                        }
                    }
                    .onOpenURL { url in
                        guard url.scheme == "pubo", let host = url.host else { return }
                        if host == "task" {
                            let taskId = url.lastPathComponent
                            dataService.resumeTask(taskId: taskId)
                        } else if host == "join" {
                            // pubo://join?code=738291
                            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                                pendingJoinCode = code
                            }
                        }
                    }
                    .sheet(item: $dataService.pendingImport) { data in
                        ImportView(
                            content: data.content,
                            suggestedPlaces: data.places,
                            onConfirm: { selectedPlaces in
                                Task {
                                    DataService.shared.saveContent(data.content, relatedPlaces: selectedPlaces)
                                    dataService.pendingImport = nil
                                }
                            },
                            onCancel: {
                                dataService.pendingImport = nil
                            }
                        )
                    }
                    .sheet(isPresented: $showTaskQueue) {
                        TaskQueueSheet()
                    }
                    .sheet(isPresented: $showLinkQueueSheet) {
                        LinkAnalysisQueueSheet()
                    }
                } else {
                    LoginView()
                }
                
                // 懸浮任務收件匣
                let hasOfflineTasks = backgroundTaskManager.pendingTaskCount > 0 || backgroundTaskManager.activeTaskCount > 0
                let hasActiveLinkTasks = dataService.activeLinkTasks.contains { $0.status == .pending || $0.status == .analyzing }
                let hasUnimportedTasks = dataService.activeLinkTasks.contains { $0.status == .completed && !$0.isImported }
                let hasFailedTasks = dataService.activeLinkTasks.contains { $0.status == .failed }
                
                let showFloating = dataService.isProcessingLink || hasActiveLinkTasks || hasUnimportedTasks || hasFailedTasks || dataService.readyImport != nil || hasOfflineTasks
                
                if showFloating {
                    FloatingTaskInbox(
                        isProcessing: dataService.isProcessingLink || hasActiveLinkTasks || backgroundTaskManager.activeTaskCount > 0,
                        progress: CGFloat(dataService.linkProgress),
                        hasResult: dataService.readyImport != nil || hasUnimportedTasks || hasFailedTasks,
                        pendingOfflineCount: backgroundTaskManager.pendingTaskCount + dataService.activeLinkTasks.filter { $0.status == .completed && !$0.isImported }.count,
                        onTap: {
                            showLinkQueueSheet = true
                        }
                    )
                    .zIndex(100)
                }
                
                // 網路恢復 Toast
                if networkMonitor.showRestoredToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "wifi")
                            Text("網路已恢復，正在背景分析離線任務...")
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: networkMonitor.showRestoredToast)
                    .zIndex(200)
                }
            }
        }
    }
}
