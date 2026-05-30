import Foundation

enum Transport {
    case none, ble, wifi
}

@Observable
final class ConnectionManager {
    let ble = BLEService()
    let wifi = WiFiService()

    var transport: Transport = .none
    var saveStatus: String?
    var testMode: Bool = false
    var isDrainingQueue: Bool = false
    // The host (IP or mDNS) that WiFi actually connected on — used to update SavedDevice.lastIP
    private(set) var connectedWiFiHost: String = ""

    // UI State Management
    var isLoadingWiFi: Bool = false
    var wifiError: String?
    var configError: String?

    private var dataCache: DataCache?
    private var deviceBootTime: Date?  // Used to reconstruct timestamps from queued readings
    private var lastWiFiAttempt: [String: Date] = [:]  // Track recent WiFi attempts by host
    var onDeviceActivity: ((String) -> Void)?  // Called when device sends a reading (nodeID)

    var status: DeviceStatus? { wifi.liveStatus ?? ble.liveStatus }
    var config: DeviceConfig? { wifi.deviceConfig ?? ble.deviceConfig }
    var commandResult: String? { wifi.commandResult ?? ble.commandResult }
    
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
                do {
                    try await Task.sleep(for: .milliseconds(1500))
                    self?.flushQueueViaREST()
                } catch {
                    print("[ConnectionManager] Task cancelled during queue flush delay: \(error)")
                }
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

    // Try a specific host over WiFi (used by ContentView on launch for known saved devices)
    func tryWiFi(host: String) {
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
        wifi.configure(host: host)
        Task {
            isLoadingWiFi = true
            wifiError = nil
            print("[ConnectionManager] Trying WiFi: \(host)")
            do {
                _ = try await wifi.fetchStatus()
                print("[ConnectionManager] WiFi connected: \(host)")
                isLoadingWiFi = false
            } catch {
                let errorMsg = "WiFi failed: \(host) - \(error.localizedDescription)"
                print("[ConnectionManager] \(errorMsg)")
                wifiError = errorMsg
                isLoadingWiFi = false
                return
            }
            connectedWiFiHost = host
            // Disconnect any existing WiFi connection to prevent duplicate clients
            if transport == .wifi {
                wifi.disconnectWebSocket()
            }
            // Stop BLE — ESP32 runs out of TCP sockets if BLE + WebSocket + flush all run at once
            ble.stopScan()
            ble.disconnect()
            transport = .wifi
            Task {
                do {
                    let cfg = try await wifi.fetchConfig()
                    self.dataCache?.currentNodeID = cfg.nodeID
                    self.dataCache?.testModeEnabled = cfg.testingMode
                    self.configError = nil
                    await MainActor.run {
                        self.onUpdateDevice?(cfg.nodeID)
                    }
                } catch {
                    let errorMsg = "Failed to fetch config: \(error.localizedDescription)"
                    print("[ConnectionManager] \(errorMsg)")
                    self.configError = errorMsg
                }
            }
            // Drain the on-device queue BEFORE opening WebSocket — ESP32 can only handle one
            // persistent connection at a time alongside bulk HTTP requests
            await drainQueue()
            // Give ESP32 a moment to recover after queue flush
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                print("[ConnectionManager] Task cancelled during recovery delay: \(error)")
            }
            // Queue is empty — now open WebSocket for live streaming
            print("[ConnectionManager] Opening WebSocket for live data...")
            wifi.connectWebSocket()
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
        if let ip = preferredIP, !ip.isEmpty, !ip.hasPrefix("0.0.0.0") {
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
            do {
                try await Task.sleep(for: .seconds(2))
                if isConnected { return }
            } catch {
                print("[ConnectionManager] Task cancelled during WiFi connection wait: \(error)")
            }
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
