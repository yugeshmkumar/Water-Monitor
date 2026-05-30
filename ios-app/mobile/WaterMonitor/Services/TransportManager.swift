import Foundation

/**
 * TransportManager — Coordinate WiFi vs BLE transport selection
 *
 * Manages active transport (WiFi or BLE) and switching between them.
 * Decides which service (WiFiService or BLEService) is currently active
 * based on availability and user preference.
 *
 * Priority: WiFi > BLE (upgrade to WiFi when device IP becomes known)
 * Startup: Begin with BLE scan; upgrade to WiFi when available.
 *
 * Extracted from ConnectionManager to isolate transport selection logic.
 */
@Observable
final class TransportManager {
    enum Transport {
        case none, ble, wifi
    }

    var transport: Transport = .none

    private let ble: BLEService
    private let wifi: WiFiService
    private var lastWiFiAttempt: [String: Date] = [:]

    /**
     * Initialize transport manager with BLE and WiFi services.
     *
     * Parameters:
     *   ble  - BLEService instance for Bluetooth transport
     *   wifi - WiFiService instance for WiFi transport
     */
    init(ble: BLEService, wifi: WiFiService) {
        self.ble = ble
        self.wifi = wifi
    }

    /**
     * Start BLE scanning for nearby devices.
     * Sets transport to .ble and initiates device discovery.
     */
    func startBLEScan() {
        transport = .ble
        ble.startScan()
    }

    /**
     * Upgrade from current transport to WiFi.
     * Attempts connection to device at preferred IP or mDNS hostname.
     * Stops BLE scanning and closes any active WebSocket before upgrading.
     *
     * Parameters:
     *   preferredIP - Optional IP address (e.g., from SavedDevice.lastIP)
     *   onTryWiFi   - Callback to initiate WiFi connection attempt
     */
    func upgradeToWiFi(
        preferredIP: String? = nil,
        nodeID: String? = nil,
        onTryWiFi: (String) -> Void
    ) {
        // Don't upgrade if already on WiFi
        guard transport != .wifi else {
            print("[TransportManager] Already on WiFi, skipping upgrade")
            return
        }

        // Stop BLE activity
        ble.stopScan()
        ble.disconnect()

        let targetID = nodeID ?? "waterlevel-a"

        // Try preferred IP first if provided, otherwise fall back to mDNS
        if let ip = preferredIP, !ip.isEmpty, !ip.hasPrefix("0.0.0.0") {
            print("[TransportManager] Upgrading to WiFi using saved IP: \(ip)")
            onTryWiFi(ip)
        } else {
            print("[TransportManager] Upgrading to WiFi using mDNS: \(targetID).local")
            onTryWiFi("\(targetID).local")
        }
    }

    /**
     * Track recent WiFi connection attempts to avoid retry spam.
     * Prevents rapid successive connection attempts to the same host.
     *
     * Parameters:
     *   host - IP address or hostname
     *
     * Returns: true if enough time has passed since last attempt
     */
    func canAttemptWiFi(host: String) -> Bool {
        // Skip invalid/placeholder IPs
        guard !host.isEmpty && host != "0.0.0.0" && !host.hasPrefix("0.0.0.0:") else {
            return false
        }

        // Skip if we tried this host recently (15s for IPs, 30s for hostnames)
        let minInterval: TimeInterval = host.contains(".") && !host.contains(":") ? 15 : 30
        if let lastAttempt = lastWiFiAttempt[host],
           Date().timeIntervalSince(lastAttempt) < minInterval {
            return false
        }

        lastWiFiAttempt[host] = Date()
        return true
    }

    /**
     * Check if device is connected via any transport.
     * Used for UI state and health checks.
     */
    var isConnected: Bool {
        switch transport {
        case .wifi: return wifi.isConnected
        case .ble: return ble.bleState == .connected
        case .none: return false
        }
    }

    /**
     * Check if device is currently connecting (BLE only).
     */
    var isConnecting: Bool {
        ble.bleState == .connecting
    }

    /**
     * Check if BLE is currently connected.
     * Used by UI to show BLE-specific options.
     */
    var isBLEConnected: Bool {
        ble.bleState == .connected
    }
}
