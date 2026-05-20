import Foundation
import Network
import Combine
import SwiftData

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var isExpensive: Bool = false
    @Published var showRestoredToast: Bool = false
    
    private var modelContext: ModelContext?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let wasDisconnected = !self.isConnected
                let isNowConnected = path.status == .satisfied
                self.isConnected = isNowConnected
                self.isExpensive = path.isExpensive
                
                if wasDisconnected && isNowConnected {
                    self.showRestoredToast = true
                    self.triggerOfflineQueue()
                    
                    // Hide toast after 3 seconds
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self?.showRestoredToast = false
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func triggerOfflineQueue() {
        guard let context = modelContext else { return }
        
        Task {
            print("🔄 [NetworkMonitor] Connection restored. Triggering offline queue...")
            // Here we would call BackgroundTaskManager.shared.processQueue(context: context)
            BackgroundTaskManager.shared.processQueue(context: context)
        }
    }
}
