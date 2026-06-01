import Foundation
import UIKit

enum Transport {
    case none, ble, wifi
}

/// Manages device connections, health monitoring, and data synchronization
@Observable
final class ConnectionManager {
    // MARK: - Services
    
    let ble = BLEService()
    private let healthMonitor = HealthMonitor()
    
    // Multi-device WiFi connections (nodeID -> WiFiService)
    private var wifiConnections: [String: WiFiService] = [:] {
        didSet { updateConnectionStates() }
    }
    
    // MARK: - Observable State
    
    private(set) var deviceConnectionStates: [String: Bool] = [:]
    private(set) var connectedDevicesSet: Set<String> = []
    
    // MARK: - Device Metadata
    
    private var deviceMetadata: [String: DeviceMetadata] = [:]  // nodeID -> metadata
    private var lastWiFiAttempt: [String: Date] = [:]  // nodeID -> last attempt time
    
    private struct DeviceMetadata {
        var currentHost: String  // IP or mDNS hostname
        var lastSuccessfulHost: String?
    }
    
    // MARK: - Legacy Compatibility
    
    let wifi = WiFiService()  // Single WiFi service for backward compatibility
    var transport: Transport = .none
    var saveStatus: String?
    var testMode: Bool = false
    var isDrainingQueue: Bool = false
    private(set) var connectedWiFiHost: String = ""
    
    // MARK: - Data Management
    
    private var dataCache: DataCache?
    private var deviceBootTime: Date?
    private(set) var lastValidStatus: DeviceStatus?
    
    // MARK: - Callbacks
    
    var onDeviceActivity: ((String) -> Void)?
    var onUpdateDevice: ((String) -> Void)?
    var onDeviceIPUpdated: ((String, String) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        healthMonitor.connectionManager = self
        setupBLECallbacks()
        setupWiFiCallbacks()
        setupAppStateObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupBLECallbacks() {
        ble.onLiveReading = { [weak self] status in
            self?.dataCache?.save(status)
            if let nodeID = self?.ble.deviceConfig?.nodeID, !nodeID.isEmpty {
                self?.onDeviceActivity?(nodeID)
                
                // ✅ Check tank level and trigger notifications
                if let config = self?.ble.deviceConfig {
                    NotificationService.shared.checkTankLevel(
                        nodeID: nodeID,
                        levelPct: status.levelPct,
                        alertLowPct: config.alertLowPct,
                        alertHighPct: config.alertHighPct,
                        motorName: nil
                    )
                }
            }
        }
        
        ble.onConfigReceived = { [weak self] cfg in
            self?.dataCache?.currentNodeID = cfg.nodeID
            self?.dataCache?.testModeEnabled = cfg.testingMode
            self?.onDeviceActivity?(cfg.nodeID)
            
            Task { @MainActor [weak self] in
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
    }
    
    private func setupWiFiCallbacks() {
        wifi.onLiveReading = { [weak self] status in
            self?.dataCache?.save(status)
            if let nodeID = self?.wifi.deviceConfig?.nodeID, !nodeID.isEmpty {
                self?.onDeviceActivity?(nodeID)
                
                // ✅ Check tank level and trigger notifications
                if let config = self?.wifi.deviceConfig {
                    NotificationService.shared.checkTankLevel(
                        nodeID: nodeID,
                        levelPct: status.levelPct,
                        alertLowPct: config.alertLowPct,
                        alertHighPct: config.alertHighPct,
                        motorName: nil
                    )
                }
            }
            print("[ConnectionManager] WiFi: saved reading \(status.levelPct)%")
        }
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    // MARK: - Connection State Management
    
    private func updateConnectionStates() {
        Task { @MainActor in
            for (nodeID, service) in wifiConnections {
                deviceConnectionStates[nodeID] = service.isConnected
            }
            
            connectedDevicesSet = Set(
                wifiConnections
                    .filter { $0.value.isConnected }
                    .map { $0.key }
            )
        }
    }
    
    // MARK: - Public Device Access
    
    func getService(for nodeID: String) -> WiFiService? {
        wifiConnections[nodeID]
    }
    
    func getStatus(for nodeID: String) -> DeviceStatus? {
        wifiConnections[nodeID]?.liveStatus
    }
    
    func getConfig(for nodeID: String) -> DeviceConfig? {
        wifiConnections[nodeID]?.deviceConfig
    }
    
    func isConnected(nodeID: String) -> Bool {
        connectedDevicesSet.contains(nodeID)
    }
    
    func getDeviceHealth(for nodeID: String) -> (isHealthy: Bool, pollInterval: TimeInterval, failures: Int)? {
        healthMonitor.getHealth(for: nodeID)
    }
    
    // MARK: - Legacy Computed Properties
    
    var status: DeviceStatus? {
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
    
    var commandResult: String? {
        wifi.commandResult ?? ble.commandResult
    }
    
    var displayStatus: DeviceStatus? {
        if let current = status, current.sensorOk {
            lastValidStatus = current
            return current
        }
        return lastValidStatus
    }
    
    var connectedDevices: [String] {
        Array(connectedDevicesSet)
    }
    
    var isOnline: Bool {
        if !connectedDevicesSet.isEmpty {
            return true
        }
        
        switch transport {
        case .wifi: return wifi.isConnected
        case .ble: return ble.bleState == .connected
        case .none: return false
        }
    }
    
    var isConnected: Bool {
        if !connectedDevicesSet.isEmpty {
            return true
        }
        
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
    
    // MARK: - Configuration
    
    func configure(dataCache: DataCache) {
        self.dataCache = dataCache
    }
    
    // MARK: - WiFi Connection (Primary Method - NodeID Based)
    
    func tryWiFi(nodeID: String, host: String? = nil) {
        let resolvedHost = host ?? deviceMetadata[nodeID]?.currentHost ?? "\(nodeID).local"
        
        // Skip invalid hosts
        guard !resolvedHost.isEmpty && resolvedHost != "0.0.0.0" && !resolvedHost.hasPrefix("0.0.0.0:") else {
            return
        }
        
        // Check device limit
        if wifiConnections.count >= DeviceLimits.maxTotalDevices && wifiConnections[nodeID] == nil {
            print("[ConnectionManager] Max device limit reached (\(DeviceLimits.maxTotalDevices))")
            return
        }
        
        // Adaptive throttling based on health
        let health = healthMonitor.getHealth(for: nodeID)
        let minInterval = health?.pollInterval ?? HealthConstants.healthyPollInterval
        
        if let lastAttempt = lastWiFiAttempt[nodeID],
           Date().timeIntervalSince(lastAttempt) < minInterval {
            return
        }
        
        lastWiFiAttempt[nodeID] = Date()
        
        Task { @MainActor in
            print("[ConnectionManager] Trying WiFi: \(resolvedHost) for \(nodeID)")
            
            // Get or create WiFi service
            let wifiService: WiFiService
            if let existing = wifiConnections[nodeID] {
                wifiService = existing
            } else {
                wifiService = WiFiService()
            }
            
            wifiService.configure(host: resolvedHost)
            
            // Test connection (off main actor for performance)
            let status = await Task.detached {
                try? await wifiService.fetchStatus()
            }.value
            
            guard status != nil else {
                print("[ConnectionManager] WiFi failed: \(resolvedHost)")
                self.healthMonitor.recordFailure(for: nodeID)
                return
            }
            
            // Success
            self.healthMonitor.recordSuccess(for: nodeID)
            print("[ConnectionManager] WiFi connected: \(resolvedHost)")
            self.connectedWiFiHost = resolvedHost
            
            // Fetch config
            guard let cfg = try? await wifiService.fetchConfig() else {
                print("[ConnectionManager] Failed to fetch config from \(resolvedHost)")
                return
            }
            
            // Store connection
            self.wifiConnections[nodeID] = wifiService
            
            // Update metadata
            var metadata = self.deviceMetadata[nodeID] ?? DeviceMetadata(currentHost: resolvedHost)
            metadata.lastSuccessfulHost = resolvedHost
            self.deviceMetadata[nodeID] = metadata
            
            // Setup callbacks
            wifiService.onLiveReading = { [weak self] status in
                self?.dataCache?.save(status)
                self?.onDeviceActivity?(nodeID)
                
                // ✅ Check tank level and trigger notifications for multi-device
                // Get config from ConnectionManager's stored connections
                if let config = self?.wifiConnections[nodeID]?.deviceConfig {
                    print("[ConnectionManager] Checking notifications for \(nodeID): level=\(status.levelPct)%, low=\(config.alertLowPct)%, high=\(config.alertHighPct)%")
                    NotificationService.shared.checkTankLevel(
                        nodeID: nodeID,
                        levelPct: status.levelPct,
                        alertLowPct: config.alertLowPct,
                        alertHighPct: config.alertHighPct,
                        motorName: nil
                    )
                } else {
                    print("[ConnectionManager] ⚠️ Cannot check notifications for \(nodeID) - config not loaded yet")
                }
            }
            
            wifiService.onConnectionStateChanged = { [weak self, nodeID] connected in
                Task { @MainActor in
                    self?.deviceConnectionStates[nodeID] = connected
                    self?.updateConnectionStates()
                }
            }
            
            // Update data cache
            self.dataCache?.currentNodeID = cfg.nodeID
            self.dataCache?.testModeEnabled = cfg.testingMode
            
            self.onUpdateDevice?(cfg.nodeID)
            
            if self.transport == .none {
                self.transport = .wifi
            }
            
            // Open WebSocket
            print("[ConnectionManager] Opening WebSocket for \(nodeID)...")
            wifiService.connectWebSocket()
        }
    }
    
    // Legacy method (host-based) for backward compatibility
    func tryWiFi(host: String, nodeID: String? = nil) {
        if let nodeID = nodeID {
            tryWiFi(nodeID: nodeID, host: host)
        } else {
            // Try to infer nodeID from host
            let inferredNodeID = host.replacingOccurrences(of: ".local", with: "")
                                     .replacingOccurrences(of: "http://", with: "")
                                     .replacingOccurrences(of: "https://", with: "")
                                     .components(separatedBy: ":").first ?? "unknown"
            tryWiFi(nodeID: inferredNodeID, host: host)
        }
    }
    
    // MARK: - BLE Connection
    
    func startBLEScan() {
        transport = .ble
        ble.startScan()
    }
    
    func upgradeToWiFi(preferredIP: String? = nil) {
        guard transport != .wifi else {
            print("[ConnectionManager] Already on WiFi, skipping upgrade")
            return
        }
        
        let nodeID = ble.deviceConfig?.nodeID ?? "waterlevel-a"
        
        if let ip = preferredIP, !ip.isEmpty {
            print("[ConnectionManager] Upgrading to WiFi using saved IP: \(ip)")
            tryWiFi(nodeID: nodeID, host: ip)
        } else {
            print("[ConnectionManager] Upgrading to WiFi using mDNS: \(nodeID).local")
            tryWiFi(nodeID: nodeID, host: "\(nodeID).local")
        }
    }
    
    func connectToDevice(_ device: SavedDevice) async {
        let nodeID = device.nodeID
        
        // Try WiFi first if IP is known
        if let ip = device.lastIP, !ip.isEmpty {
            print("[ConnectionManager] Attempting WiFi connection to \(ip)")
            tryWiFi(nodeID: nodeID, host: ip)
            try? await Task.sleep(for: .seconds(2))
            if isConnected(nodeID: nodeID) { return }
        }
        
        // Fall back to BLE scan
        print("[ConnectionManager] Starting BLE scan for \(nodeID)")
        startBLEScan()
    }
    
    // MARK: - Configuration Management
    
    func writeConfig(_ patch: [String: Any], for nodeID: String) async -> Result<Void, AppError> {
        saveStatus = nil
        
        guard let wifiService = wifiConnections[nodeID] else {
            // Fall back to legacy for BLE
            await legacyWriteConfig(patch)
            return .success(())
        }
        
        do {
            try await wifiService.patchConfig(patch)
            saveStatus = "✓ Settings saved"
            print("[ConnectionManager] Config saved to \(nodeID): \(patch)")
            return .success(())
        } catch {
            saveStatus = "✗ Failed to save"
            print("[ConnectionManager] Failed to save config to \(nodeID): \(error)")
            return .failure(.configurationFailed(reason: error.localizedDescription))
        }
    }
    
    // Legacy writeConfig (for backward compatibility)
    func writeConfig(_ patch: [String: Any]) async {
        await legacyWriteConfig(patch)
    }
    
    private func legacyWriteConfig(_ patch: [String: Any]) async {
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
            try? await Task.sleep(for: .milliseconds(Int(NetworkConstants.bleConfigWriteEchoDelay * 1000)))
            saveStatus = "✓ Settings saved"
        case .none:
            saveStatus = "✗ Not connected"
        }
    }
    
    func setTestMode(_ enabled: Bool, for nodeID: String) async {
        testMode = enabled
        dataCache?.testModeEnabled = enabled
        
        let interval = config?.testPollIntervalS ?? TestModeConstants.defaultInterval
        print("[ConnectionManager] Setting test mode: enabled=\(enabled), interval=\(interval)s for \(nodeID)")
        
        _ = await writeConfig([
            "testing_mode": enabled,
            "test_poll_interval_s": interval
        ], for: nodeID)
    }
    
    // Legacy setTestMode
    func setTestMode(_ enabled: Bool) async {
        testMode = enabled
        dataCache?.testModeEnabled = enabled
        
        let interval = config?.testPollIntervalS ?? TestModeConstants.defaultInterval
        print("[ConnectionManager] Setting test mode (legacy): enabled=\(enabled), interval=\(interval)s")
        
        await legacyWriteConfig([
            "testing_mode": enabled,
            "test_poll_interval_s": interval
        ])
    }
    
    // MARK: - Command Sending
    
    func sendCommand(_ cmd: [String: Any]) {
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
    
    // MARK: - Health Monitoring
    
    func startHealthMonitoring(for nodeID: String) {
        guard let host = deviceMetadata[nodeID]?.currentHost else {
            print("[ConnectionManager] No host found for \(nodeID)")
            return
        }
        
        healthMonitor.startMonitoring(nodeID: nodeID, host: host)
    }
    
    func stopHealthMonitoring(for nodeID: String) {
        healthMonitor.stopMonitoring(for: nodeID)
    }
    
    // MARK: - Device Removal
    
    func removeDevice(nodeID: String) {
        stopHealthMonitoring(for: nodeID)
        
        wifiConnections[nodeID]?.disconnectWebSocket()
        wifiConnections.removeValue(forKey: nodeID)
        deviceConnectionStates.removeValue(forKey: nodeID)
        deviceMetadata.removeValue(forKey: nodeID)
        lastWiFiAttempt.removeValue(forKey: nodeID)
        
        updateConnectionStates()
        
        print("[ConnectionManager] Removed device \(nodeID)")
    }
    
    // MARK: - Queue Management
    
    func flushQueueViaREST() {
        guard !isDrainingQueue, transport == .wifi, wifi.isConnected else { return }
        Task { await drainQueue() }
    }
    
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
                
                var acked = false
                for attempt in 1...NetworkConstants.maxConnectionRetries {
                    do {
                        try await wifi.ackQueue(upTo: maxSeq)
                        acked = true
                        break
                    } catch {
                        print("[Queue] ACK attempt \(attempt) failed: \(error.localizedDescription)")
                        if attempt < NetworkConstants.maxConnectionRetries {
                            try? await Task.sleep(for: .seconds(NetworkConstants.connectionRetryDelay))
                        }
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
    
    // MARK: - Testing
    
    func testDeviceConnection() async throws -> DeviceStatus {
        let timeout: TimeInterval = 5
        let start = Date()
        
        switch transport {
        case .wifi:
            do {
                let status = try await wifi.fetchStatus()
                return status
            } catch {
                throw AppError.connectionFailed(host: wifi.host ?? "unknown", reason: error.localizedDescription)
            }
            
        case .ble:
            while Date().timeIntervalSince(start) < timeout {
                if let status = ble.liveStatus {
                    return status
                }
                try await Task.sleep(for: .milliseconds(500))
            }
            throw AppError.timeout
            
        case .none:
            throw AppError.deviceNotFound(nodeID: "unknown")
        }
    }
    
    // MARK: - App State Handling
    
    @objc private func appDidEnterBackground() {
        print("[ConnectionManager] App entering background - adjusting monitoring")
        healthMonitor.pauseAllMonitoring()
        BackgroundTaskManager.shared.scheduleBackgroundRefresh()
    }
    
    @objc private func appWillEnterForeground() {
        print("[ConnectionManager] App entering foreground - resuming monitoring")
        healthMonitor.resumeAllMonitoring()
        
        // Force immediate refresh of all devices
        Task {
            for nodeID in connectedDevicesSet {
                if let host = deviceMetadata[nodeID]?.currentHost {
                    tryWiFi(nodeID: nodeID, host: host)
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        healthMonitor.stopAllMonitoring()
        
        for (_, service) in wifiConnections {
            service.disconnectWebSocket()
        }
        
        wifiConnections.removeAll()
        deviceConnectionStates.removeAll()
        connectedDevicesSet.removeAll()
        deviceMetadata.removeAll()
        lastWiFiAttempt.removeAll()
    }
}
