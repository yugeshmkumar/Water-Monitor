import UIKit
import BackgroundTasks

/// Manages background refresh tasks for device monitoring
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private let taskIdentifier = "com.watermonitor.refresh"
    private weak var connectionManager: ConnectionManager?
    
    private init() {}
    
    func configure(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        registerBackgroundTask()
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: HealthConstants.backgroundPollInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[Background] Scheduled refresh in \(Int(HealthConstants.backgroundPollInterval))s")
        } catch {
            print("[Background] Failed to schedule: \(error)")
        }
    }
    
    func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("[Background] Cancelled background refresh")
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()  // Schedule next refresh
        
        task.expirationHandler = {
            print("[Background] Task expired")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await refreshAllDevices()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func refreshAllDevices() async {
        guard let cm = connectionManager else { return }
        
        print("[Background] Refreshing all devices...")
        
        let nodeIDs = Array(cm.connectedDevicesSet)
        
        for nodeID in nodeIDs {
            do {
                if let service = cm.getService(for: nodeID) {
                    _ = try await service.fetchStatus()
                    print("[Background] Fetched status for \(nodeID)")
                }
            } catch {
                print("[Background] Failed to fetch status for \(nodeID): \(error)")
            }
        }
        
        print("[Background] Refresh complete")
    }
}
