import Foundation

enum Transport {
    case none, ble, wifi
}

@Observable
final class ConnectionManager {
    let ble = BLEService()
    
    // NEW: Store individual WiFi connections per device
    private var wifiConnections: [String: WiFiService] = [:]  // nodeID -> WiFiService
    
    // ✅ Observable state tracking for SwiftUI
    private(set) var deviceConnectionStates: [String: Bool] = [:]  // nodeID -> isConnected
    private(set) var lastUpdateTrigger = Date()  // Force UI updates
    
    // Legacy single WiFi service for backwards compatibility
    let wifi = WiFiService()

    var transport: Transport = .none
    var saveStatus: String?
    var testMode: Bool = false
    var isDrainingQueue: Bool = false
    // The host (IP or mDNS) that WiFi actually connected on — used to update SavedDevice.lastIP
    private(set) var connectedWiFiHost: String = ""

    private var dataCache: DataCache?
    private var deviceBootTime: Date?  // Used to reconstruct timestamps from queued readings
    private var lastWiFiAttempt: [String: Date] = [:]  // Track recent WiFi attempts by host
    
    // ✅ Best Practice: Adaptive polling for offline devices (like Home Assistant, Nest, etc.)
    private var deviceHealthState: [String: DeviceHealth] = [:]  // host -> health tracking
    private var healthCheckTasks: [String: Task<Void, Never>] = [:]  // Background health monitors
    
    var onDeviceActivity: ((String) -> Void)?  // Called when device sends a reading (nodeID)
    
    // Health tracking for each device
    private struct DeviceHealth {
        var consecutiveFailures: Int = 0
        var lastSuccessfulContact: Date?
        var isHealthy: Bool = true
        var currentPollInterval: TimeInterval = 15  // Start with 15s
        
        // Adaptive polling intervals based on health
        static let healthyInterval: TimeInterval = 15      // When device is responsive
        static let degradedInterval: TimeInterval = 60     // After 1-2 failures
        static let unhealthyInterval: TimeInterval = 300   // After 3+ failures (5 min)
        static let maxFailuresBeforeSlow: Int = 3
    }

    // Legacy properties - return first connected device for backwards compatibility
    var status: DeviceStatus? { 
        // Try to get from any connected WiFi device first
        if let firstConnected = wifiConnections.values.first(where: { $0.isConnected }) {
            return firstConnected.liveStatus
        }
        return wifi.liveStatus ?? ble.liveStatus
    }
    var config: DeviceConfig? {
        if let firstConnected = wifiConnections.values.first(where: { $0.isConnected }) {
            return firstConnected.deviceConfig
        }
        return wifi.deviceConfig ?? ble.deviceConfig
    }
    var commandResult: String? { wifi.commandResult ?? ble.commandResult }
    
    // NEW: Get status for a specific device  
    func getStatus(for nodeID: String) -> DeviceStatus? {
        let status = wifiConnections[nodeID]?.liveStatus
        // Trigger update to force UI refresh
        _ = lastUpdateTrigger
        return status
    }
    
    // NEW: Get config for a specific device
    func getConfig(for nodeID: String) -> DeviceConfig? {
        let config = wifiConnections[nodeID]?.deviceConfig
        _ = lastUpdateTrigger
        return config
    }
    
    // ✅ NEW: Get health status for a device
    func getDeviceHealth(for host: String) -> (isHealthy: Bool, pollInterval: TimeInterval, failures: Int)? {
        guard let health = deviceHealthState[host] else { return nil }
        return (health.isHealthy, health.currentPollInterval, health.consecutiveFailures)
    }
    
    // NEW: Check if a specific device is connected
    func isConnected(nodeID: String) -> Bool {
        // ✅ Use the synced state (which is observable)
        let connected = deviceConnectionStates[nodeID] ?? false
        // Trigger update to force UI refresh
        _ = lastUpdateTrigger
        return connected
    }
    
    // NEW: Get all connected device node IDs
    var connectedDevices: [String] {
        wifiConnections.filter { $0.value.isConnected }.map { $0.key }
    }
    
    // Last valid reading (when sensor was OK)
    private(set) var lastValidStatus: DeviceStatus?
    
    // Current or last valid reading
    var displayStatus: DeviceStatus? {
        if let current = status, current.sensorOk {
            lastValidStatus = current
            return current
        }
        return lastValidStatus
    }
    
    init() {
        ble.onLiveReading = { [weak self] status in
            self?.dataCache?.save(status)
            if let nodeID = self?.ble.deviceConfig?.nodeID, !nodeID.isEmpty {
                self?.onDeviceActivity?(nodeID)
            }
        }
        ble.onConfigReceived = { [weak self] cfg in
            self?.dataCache?.currentNodeID = cfg.nodeID
            self?.dataCache?.testModeEnabled = cfg.testingMode
            self?.onDeviceActivity?(cfg.nodeID)
            DispatchQueue.main.async {
                self?.onUpdateDevice?(cfg.nodeID)
                // Update device IP if provided in config
                if !cfg.ip.isEmpty && cfg.ip != "0.0.0.0" {
                    self?.onDeviceIPUpdated?(cfg.nodeID, cfg.ip)
                }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                self?.flushQueueViaREST()
            }
        }

        // WiFi live readings callback (same as BLE)
        wifi.onLiveReading = { [weak self] status in
            self?.dataCache?.save(status)
            if let nodeID = self?.wifi.deviceConfig?.nodeID, !nodeID.isEmpty {
                self?.onDeviceActivity?(nodeID)
            }
            print("[ConnectionManager] WiFi: saved reading \(status.levelPct)%")
        }
        
        // ✅ Start periodic state sync to trigger UI updates
        startPeriodicStateSync()
    }
    
    // ✅ Periodically sync connection states to trigger SwiftUI updates
    private func startPeriodicStateSync() {
        Task { @MainActor in
            while true {
                // Update connection states from actual WiFiService states
                for (nodeID, service) in wifiConnections {
                    deviceConnectionStates[nodeID] = service.isConnected
                }
                // Trigger UI refresh
                lastUpdateTrigger = Date()
                
                // Wait 1 second before next update
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // Called from ble.onConfigReceived — only runs if drainQueue from tryWiFi hasn't started yet
    func flushQueueViaREST() {
        guard !isDrainingQueue, transport == .wifi, wifi.isConnected else { return }
        Task { await drainQueue() }
    }

    // Async drain loop — called directly from tryWiFi so WebSocket opens AFTER queue is empty
    private func drainQueue() async {
        guard !isDrainingQueue else { return }
        isDrainingQueue = true
        defer { isDrainingQueue = false }

        let latestTs = ble.liveStatus?.ts ?? 0
        let bootTime = latestTs > 0
            ? Date().addingTimeInterval(-TimeInterval(latestTs))
            : Date().addingTimeInterval(-300)
        deviceBootTime = bootTime

        var totalFlushed = 0
        while true {
            do {
                let entries = try await wifi.fetchQueue()
                guard !entries.isEmpty else { break }
                dataCache?.saveQueueEntries(entries, bootTime: bootTime)
                guard let maxSeq = entries.compactMap({ $0["seq"] as? Int }).max().map({ UInt32($0) }) else { break }
                // Retry ACK — transient timeout after a successful flush should not lose the batch
                var acked = false
                for attempt in 1...3 {
                    do {
                        try await wifi.ackQueue(upTo: maxSeq)
                        acked = true
                        break
                    } catch {
                        print("[Queue] ACK attempt \(attempt) failed: \(error.localizedDescription)")
                        if attempt < 3 { try? await Task.sleep(for: .seconds(2)) }
                    }
                }
                guard acked else { break }
                totalFlushed += entries.count
                print("[Queue] batch \(entries.count) acked to seq \(maxSeq)")
                if entries.count < 50 { break }
            } catch {
                print("[Queue] flush error: \(error.localizedDescription)")
                break
            }
        }
        if totalFlushed > 0 {
            print("[Queue] flush complete — \(totalFlushed) entries saved to history")
        }
    }
    
    var onUpdateDevice: ((String) -> Void)?  // Called when device connects (nodeID)
    var onDeviceIPUpdated: ((String, String) -> Void)?  // Called when device IP is known (nodeID, ip)

    func configure(dataCache: DataCache) {
        self.dataCache = dataCache
    }

    // Try a specific host over WiFi - NOW SUPPORTS MULTIPLE CONCURRENT CONNECTIONS
    func tryWiFi(host: String, nodeID: String? = nil) {
        // Skip invalid/placeholder IPs
        guard !host.isEmpty && host != "0.0.0.0" && !host.hasPrefix("0.0.0.0:") else {
            return
        }
        
        // ✅ Best Practice: Adaptive throttling based on device health
        let health = deviceHealthState[host] ?? DeviceHealth()
        let minInterval = health.currentPollInterval
        
        if let lastAttempt = lastWiFiAttempt[host],
           Date().timeIntervalSince(lastAttempt) < minInterval {
            // Don't spam - respect the adaptive interval
            return
        }
        
        lastWiFiAttempt[host] = Date()
        
        Task {
            print("[ConnectionManager] Trying WiFi: \(host) (poll interval: \(Int(health.currentPollInterval))s)")
            
            // Create or get WiFi service for this connection
            let wifiService: WiFiService
            if let nodeID = nodeID, let existing = wifiConnections[nodeID] {
                wifiService = existing
            } else {
                wifiService = WiFiService()
            }
            
            wifiService.configure(host: host)
            
            // Test connection
            guard (try? await wifiService.fetchStatus()) != nil else {
                print("[ConnectionManager] WiFi failed: \(host)")
                self.recordDeviceFailure(for: host)
                return
            }
            
            // ✅ Success - mark device as healthy
            self.recordDeviceSuccess(for: host)
            
            print("[ConnectionManager] WiFi connected: \(host)")
            connectedWiFiHost = host
            
            // Fetch config to get nodeID
            guard let cfg = try? await wifiService.fetchConfig() else {
                print("[ConnectionManager] Failed to fetch config from \(host)")
                return
            }
            
            let deviceNodeID = nodeID ?? cfg.nodeID
            
            // Store this connection
            wifiConnections[deviceNodeID] = wifiService
            
            // Set up callback for live readings
            wifiService.onLiveReading = { [weak self] status in
                self?.dataCache?.save(status)
                self?.onDeviceActivity?(deviceNodeID)
            }
            
            // Update data cache
            self.dataCache?.currentNodeID = cfg.nodeID
            self.dataCache?.testModeEnabled = cfg.testingMode
            
            await MainActor.run {
                self.onUpdateDevice?(cfg.nodeID)
                if transport == .none {
                    transport = .wifi
                }
            }
            
            // Open WebSocket for live streaming
            print("[ConnectionManager] Opening WebSocket for \(deviceNodeID)...")
            wifiService.connectWebSocket()
        }
    }

    // Upgrade from BLE to WiFi once we know the device is on the LAN
    func upgradeToWiFi(preferredIP: String? = nil) {
        // Don't upgrade if already on WiFi
        guard transport != .wifi else {
            print("[ConnectionManager] Already on WiFi, skipping upgrade")
            return
        }
        
        let nodeID = ble.deviceConfig?.nodeID ?? "waterlevel-a"
        
        // Try preferred IP first if provided, otherwise fall back to mDNS
        if let ip = preferredIP, !ip.isEmpty {
            print("[ConnectionManager] Upgrading to WiFi using saved IP: \(ip)")
            tryWiFi(host: ip)
        } else {
            print("[ConnectionManager] Upgrading to WiFi using mDNS: \(nodeID).local")
            tryWiFi(host: "\(nodeID).local")
        }
    }

    func startBLEScan() {
        transport = .ble
        ble.startScan()
    }
    
    // ✅ NEW: Write config to a specific device
    func writeConfig(_ patch: [String: Any], for nodeID: String) async {
        saveStatus = nil
        
        // Try to write to the specific device's WiFi connection
        if let wifiService = wifiConnections[nodeID] {
            do {
                try await wifiService.patchConfig(patch)
                saveStatus = "✓ Settings saved"
                print("[ConnectionManager] Config saved to \(nodeID): \(patch)")
            } catch {
                saveStatus = "✗ Failed to save"
                print("[ConnectionManager] Failed to save config to \(nodeID): \(error)")
            }
        } else {
            // Fall back to legacy writeConfig if device not found
            await writeConfig(patch)
        }
    }
    
    // Legacy writeConfig (kept for backward compatibility)
    func writeConfig(_ patch: [String: Any]) async {
        saveStatus = nil
        switch transport {
        case .wifi:
            do {
                try await wifi.patchConfig(patch)
                saveStatus = "✓ Settings saved"
            } catch {
                saveStatus = "✗ Failed to save"
            }
        case .ble:
            ble.writeConfig(patch)
            // BLE write is async — AA03 (config response) arrives asynchronously.
            // Wait briefly for the device to echo back the new config via AA03.
            try? await Task.sleep(for: .milliseconds(800))
            saveStatus = "✓ Settings saved"
        case .none:
            saveStatus = "✗ Not connected"
        }
    }
    
    // ✅ NEW: Set test mode for a specific device
    func setTestMode(_ enabled: Bool, for nodeID: String) async {
        testMode = enabled
        dataCache?.testModeEnabled = enabled
        // Always send both testing_mode AND test_poll_interval_s together
        let interval = config?.testPollIntervalS ?? 3
        print("[ConnectionManager] Setting test mode: enabled=\(enabled), interval=\(interval)s")
        await writeConfig(["testing_mode": enabled, "test_poll_interval_s": interval], for: nodeID)
    }
    
    // Legacy setTestMode (kept for backward compatibility)
    func setTestMode(_ enabled: Bool) async {
        testMode = enabled
        dataCache?.testModeEnabled = enabled
        let interval = config?.testPollIntervalS ?? 3
        print("[ConnectionManager] Setting test mode (legacy): enabled=\(enabled), interval=\(interval)s")
        await writeConfig(["testing_mode": enabled, "test_poll_interval_s": interval])
    }

    func sendCommand(_ cmd: [String: Any]) {
        // Clear previous results
        ble.commandResult = nil
        wifi.commandResult = nil
        
        switch transport {
        case .wifi:
            Task {
                do {
                    let result = try await wifi.sendCommand(cmd)
                    wifi.commandResult = result
                    print("[WiFi] Command result: \(result)")
                } catch {
                    wifi.commandResult = "error: \(error.localizedDescription)"
                    print("[WiFi] Command error: \(error)")
                }
            }
        case .ble:
            ble.sendCommand(cmd)
        case .none:
            break
        }
    }
    
    // MARK: - Device Health Tracking (Adaptive Polling)
    
    /// ✅ Best Practice: Record device success and restore healthy polling
    @MainActor
    private func recordDeviceSuccess(for host: String) {
        var health = deviceHealthState[host] ?? DeviceHealth()
        health.consecutiveFailures = 0
        health.lastSuccessfulContact = Date()
        health.isHealthy = true
        health.currentPollInterval = DeviceHealth.healthyInterval
        deviceHealthState[host] = health
        
        print("[ConnectionManager] ✅ Device \(host) is healthy (polling every \(Int(health.currentPollInterval))s)")
    }
    
    /// ✅ Best Practice: Record device failure and adapt polling interval
    @MainActor
    private func recordDeviceFailure(for host: String) {
        var health = deviceHealthState[host] ?? DeviceHealth()
        health.consecutiveFailures += 1
        
        // Adaptive polling based on failure count (like Nest, Hue, UniFi apps)
        switch health.consecutiveFailures {
        case 1...2:
            // First few failures - might be temporary, slow down a bit
            health.currentPollInterval = DeviceHealth.degradedInterval
            health.isHealthy = false
            print("[ConnectionManager] ⚠️ Device \(host) degraded (polling every \(Int(health.currentPollInterval))s)")
            
        case DeviceHealth.maxFailuresBeforeSlow...:
            // Multiple failures - device likely offline, check infrequently
            health.currentPollInterval = DeviceHealth.unhealthyInterval
            health.isHealthy = false
            print("[ConnectionManager] 🔴 Device \(host) appears offline (polling every \(Int(health.currentPollInterval))s)")
            
        default:
            break
        }
        
        deviceHealthState[host] = health
    }
    
    /// ✅ Start background health check for a device (continuous monitoring)
    func startHealthMonitoring(for host: String, nodeID: String) {
        // Cancel existing task if any
        healthCheckTasks[host]?.cancel()
        
        healthCheckTasks[host] = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                
                // Get current health state
                let health = self.deviceHealthState[host] ?? DeviceHealth()
                
                // Wait for the adaptive interval
                try? await Task.sleep(for: .seconds(health.currentPollInterval))
                guard !Task.isCancelled else { break }
                
                // Try to connect/reconnect
                self.tryWiFi(host: host, nodeID: nodeID)
            }
        }
        
        print("[ConnectionManager] Started health monitoring for \(host)")
    }
    
    /// Stop health monitoring for a device
    func stopHealthMonitoring(for host: String) {
        healthCheckTasks[host]?.cancel()
        healthCheckTasks.removeValue(forKey: host)
        print("[ConnectionManager] Stopped health monitoring for \(host)")
    }

    var isOnline: Bool {
        // Check if ANY device is connected (multi-connection support)
        if !wifiConnections.isEmpty && wifiConnections.values.contains(where: { $0.isConnected }) {
            return true
        }
        
        // Fall back to legacy check
        switch transport {
        case .wifi:
            return wifi.isConnected
        case .ble:
            return ble.bleState == .connected
        case .none:
            return false
        }
    }

    var isConnected: Bool {
        // Check if ANY device is connected
        if !wifiConnections.isEmpty && wifiConnections.values.contains(where: { $0.isConnected }) {
            return true
        }
        
        // Fall back to legacy check
        switch transport {
        case .wifi: return wifi.isConnected
        case .ble: return ble.bleState == .connected
        case .none: return false
        }
    }

    var isConnecting: Bool {
        switch transport {
        case .wifi: return false
        case .ble: return ble.bleState == .connecting
        case .none: return false
        }
    }

    var isBLEConnected: Bool {
        ble.bleState == .connected
    }

    func connectToDevice(_ device: SavedDevice) async {
        // Try WiFi first if IP is known
        if let ip = device.lastIP, !ip.isEmpty {
            print("[ConnectionManager] Attempting WiFi connection to \(ip)")
            tryWiFi(host: ip)
            try? await Task.sleep(for: .seconds(2))
            if isConnected { return }
        }

        // Fall back to BLE scan
        print("[ConnectionManager] Starting BLE scan for \(device.nodeID)")
        startBLEScan()
    }

    func testDeviceConnection() async throws -> DeviceStatus {
        let timeout: TimeInterval = 5
        let start = Date()

        switch transport {
        case .wifi:
            // Fetch fresh status from device
            do {
                let status = try await wifi.fetchStatus()
                return status
            } catch {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device not responding over WiFi"])
            }

        case .ble:
            // Wait for a fresh BLE reading (up to timeout)
            while Date().timeIntervalSince(start) < timeout {
                if let status = ble.liveStatus {
                    return status
                }
                try await Task.sleep(for: .milliseconds(500))
            }
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No BLE readings received from device"])

        case .none:
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to device"])
        }
    }
}
