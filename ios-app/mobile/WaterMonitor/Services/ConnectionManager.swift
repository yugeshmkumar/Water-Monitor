import Foundation

/**
 * ConnectionManager — High-level device connection coordination
 *
 * Orchestrates WiFi/BLE transport selection, device discovery, configuration,
 * and callback routing. Delegates specific concerns to:
 * - TransportManager: WiFi vs BLE switching
 * - QueueDrainer: Offline queue flushing
 *
 * Refactoring Note: Phase 3c extracted TransportManager and QueueDrainer.
 * ConnectionManager now focuses on device lifecycle and callback coordination.
 */
@Observable
final class ConnectionManager {
    let ble = BLEService()
    let wifi = WiFiService()

    var transport: TransportManager.Transport {
        get { transportManager.transport }
        set { transportManager.transport = newValue }
    }
    var isDrainingQueue: Bool { queueDrainer.isDrainingQueue }

    var saveStatus: String?
    var testMode: Bool = false
    // The host (IP or mDNS) that WiFi actually connected on — used to update SavedDevice.lastIP
    private(set) var connectedWiFiHost: String = ""

    // UI State Management
    var isLoadingWiFi: Bool = false
    var wifiError: String?
    var configError: String?

    private var dataCache: DataCache?
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

    private let transportManager: TransportManager
    private let queueDrainer: QueueDrainer

    init() {
        self.transportManager = TransportManager(ble: ble, wifi: wifi)
        self.queueDrainer = QueueDrainer(wifi: wifi, dataCache: DataCache(context: ModelContext(ModelContainer(for: DeviceReading.self, inMemory: true))))

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
                    self?.queueDrainer.flushQueueViaREST()
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
    
    var onUpdateDevice: ((String) -> Void)?  // Called when device connects (nodeID)
    var onDeviceIPUpdated: ((String, String) -> Void)?  // Called when device IP is known (nodeID, ip)

    func configure(dataCache: DataCache) {
        self.dataCache = dataCache
        self.queueDrainer = QueueDrainer(wifi: wifi, dataCache: dataCache)
    }

    // Try a specific host over WiFi (used by ContentView on launch for known saved devices)
    func tryWiFi(host: String) {
        guard transportManager.canAttemptWiFi(host: host) else {
            print("[ConnectionManager] Skipping WiFi \(host) - invalid or recently tried")
            return
        }

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
            await queueDrainer.drainQueue()
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
        let nodeID = ble.deviceConfig?.nodeID ?? "waterlevel-a"
        transportManager.upgradeToWiFi(preferredIP: preferredIP, nodeID: nodeID) { [weak self] host in
            self?.tryWiFi(host: host)
        }
    }

    func startBLEScan() {
        transportManager.startBLEScan()
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
        transportManager.isConnected
    }

    var isConnected: Bool {
        transportManager.isConnected
    }

    var isConnecting: Bool {
        transportManager.isConnecting
    }

    var isBLEConnected: Bool {
        transportManager.isBLEConnected
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
