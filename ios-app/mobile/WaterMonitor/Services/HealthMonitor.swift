import Foundation

/// Manages device health tracking and adaptive polling
@Observable
final class HealthMonitor {
    private var deviceHealthState: [String: DeviceHealth] = [:]  // nodeID -> health
    private var healthCheckTasks: [String: Task<Void, Never>] = [:]
    
    weak var connectionManager: ConnectionManager?
    
    struct DeviceHealth {
        var consecutiveFailures: Int = 0
        var lastSuccessfulContact: Date?
        var isHealthy: Bool = true
        var currentPollInterval: TimeInterval = HealthConstants.healthyPollInterval
        var backgroundPollInterval: TimeInterval? = nil
        
        var effectivePollInterval: TimeInterval {
            backgroundPollInterval ?? currentPollInterval
        }
    }
    
    // MARK: - Health Tracking
    
    func recordSuccess(for nodeID: String) {
        var health = deviceHealthState[nodeID] ?? DeviceHealth()
        health.consecutiveFailures = 0
        health.lastSuccessfulContact = Date()
        health.isHealthy = true
        health.currentPollInterval = HealthConstants.healthyPollInterval
        deviceHealthState[nodeID] = health
        
        print("[HealthMonitor] ✅ Device \(nodeID) is healthy (polling every \(Int(health.currentPollInterval))s)")
    }
    
    func recordFailure(for nodeID: String) {
        var health = deviceHealthState[nodeID] ?? DeviceHealth()
        health.consecutiveFailures += 1
        
        switch health.consecutiveFailures {
        case 1...2:
            health.currentPollInterval = HealthConstants.degradedPollInterval
            health.isHealthy = false
            print("[HealthMonitor] ⚠️ Device \(nodeID) degraded (polling every \(Int(health.currentPollInterval))s)")
            
        case HealthConstants.maxFailuresBeforeSlow...:
            health.currentPollInterval = HealthConstants.unhealthyPollInterval
            health.isHealthy = false
            print("[HealthMonitor] 🔴 Device \(nodeID) appears offline (polling every \(Int(health.currentPollInterval))s)")
            
        default:
            break
        }
        
        deviceHealthState[nodeID] = health
    }
    
    func getHealth(for nodeID: String) -> (isHealthy: Bool, pollInterval: TimeInterval, failures: Int)? {
        guard let health = deviceHealthState[nodeID] else { return nil }
        return (health.isHealthy, health.currentPollInterval, health.consecutiveFailures)
    }
    
    // MARK: - Monitoring Tasks
    
    func startMonitoring(nodeID: String, host: String) {
        stopMonitoring(for: nodeID)
        
        healthCheckTasks[nodeID] = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                
                let interval = self.deviceHealthState[nodeID]?.effectivePollInterval 
                    ?? HealthConstants.healthyPollInterval
                
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                
                // Request connection manager to try connection
                self.connectionManager?.tryWiFi(nodeID: nodeID, host: host)
            }
        }
        
        print("[HealthMonitor] Started monitoring for \(nodeID)")
    }
    
    func stopMonitoring(for nodeID: String) {
        healthCheckTasks[nodeID]?.cancel()
        healthCheckTasks.removeValue(forKey: nodeID)
        print("[HealthMonitor] Stopped monitoring for \(nodeID)")
    }
    
    func stopAllMonitoring() {
        for (nodeID, task) in healthCheckTasks {
            task.cancel()
            print("[HealthMonitor] Stopped monitoring for \(nodeID)")
        }
        healthCheckTasks.removeAll()
    }
    
    // MARK: - Background Mode
    
    func pauseAllMonitoring() {
        print("[HealthMonitor] Pausing all monitoring (background mode)")
        for nodeID in deviceHealthState.keys {
            var health = deviceHealthState[nodeID] ?? DeviceHealth()
            health.backgroundPollInterval = HealthConstants.backgroundPollInterval
            deviceHealthState[nodeID] = health
        }
    }
    
    func resumeAllMonitoring() {
        print("[HealthMonitor] Resuming all monitoring (foreground mode)")
        for nodeID in deviceHealthState.keys {
            var health = deviceHealthState[nodeID] ?? DeviceHealth()
            health.backgroundPollInterval = nil
            deviceHealthState[nodeID] = health
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopAllMonitoring()
    }
}
