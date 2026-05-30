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
    var onDeviceActivity: ((String) -> Void)?  // Called when device sends a reading (nodeID)

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
            print("[ConnectionManager] Skipping WiFi \(host) - invalid IP")
            return
        }

        // Skip if we tried this host recently (15s for IPs, 30s for hostnames)
        let minInterval: TimeInterval = host.contains(".") && !host.contains(":") ? 15 : 30
        if let lastAttempt = lastWiFiAttempt[host],
           Date().timeIntervalSince(lastAttempt) < minInterval {
            print("[ConnectionManager] Skipping WiFi \(host) - tried recently")
            return
        }
        
        lastWiFiAttempt[host] = Date()
        
        Task {
            print("[ConnectionManager] Trying WiFi: \(host)")
            
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
                return
            }
            
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
    
    func setTestMode(_ enabled: Bool) async {
        testMode = enabled
        dataCache?.testModeEnabled = enabled
        await writeConfig(["testing_mode": enabled])
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
