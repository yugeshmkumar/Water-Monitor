import Foundation
import Observation

/// Manages concurrent connections to multiple devices
@Observable
final class MultiConnectionManager {
    // Map of nodeID -> DeviceConnection
    private(set) var connections: [String: DeviceConnection] = [:]
    
    // BLE service for discovery (shared across all devices)
    let ble = BLEService()
    
    var onDeviceActivity: ((String) -> Void)?
    var onDeviceConnected: ((String) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?
    
    init() {
        setupBLECallbacks()
    }
    
    // MARK: - Device Management
    
    /// Get or create a connection for a device
    func getConnection(for nodeID: String) -> DeviceConnection {
        if let existing = connections[nodeID] {
            return existing
        }
        
        let connection = DeviceConnection(nodeID: nodeID)
        connections[nodeID] = connection
        
        print("[MultiConnectionManager] Created connection for \(nodeID)")
        return connection
    }
    
    /// Connect to a device via WiFi
    func connectDevice(nodeID: String, host: String) {
        let connection = getConnection(for: nodeID)
        
        // Don't reconnect if already connected
        guard !connection.isConnected else {
            print("[MultiConnectionManager] Device \(nodeID) already connected")
            return
        }
        
        connection.connectViaWiFi(host: host)
    }
    
    /// Connect to multiple devices simultaneously
    func connectAllDevices(_ devices: [SavedDevice]) {
        print("[MultiConnectionManager] Connecting to \(devices.count) devices concurrently")
        
        for device in devices {
            let host = device.lastIP ?? device.lastHost
            connectDevice(nodeID: device.nodeID, host: host)
        }
    }
    
    /// Disconnect a specific device
    func disconnectDevice(nodeID: String) {
        connections[nodeID]?.disconnect()
        connections.removeValue(forKey: nodeID)
    }
    
    /// Disconnect all devices
    func disconnectAll() {
        for connection in connections.values {
            connection.disconnect()
        }
        connections.removeAll()
    }
    
    // MARK: - Data Access
    
    /// Get current status for a device
    func getStatus(for nodeID: String) -> DeviceStatus? {
        connections[nodeID]?.status
    }
    
    /// Get config for a device
    func getConfig(for nodeID: String) -> DeviceConfig? {
        connections[nodeID]?.config
    }
    
    /// Check if a device is connected
    func isConnected(nodeID: String) -> Bool {
        connections[nodeID]?.isConnected ?? false
    }
    
    /// Get all connected devices
    var connectedDevices: [String] {
        connections.filter { $0.value.isConnected }.map { $0.key }
    }
    
    /// Check if any device is connected
    var hasConnections: Bool {
        !connectedDevices.isEmpty
    }
    
    // MARK: - BLE Support
    
    private func setupBLECallbacks() {
        // BLE discovery can still be used for initial device setup
        ble.onConfigReceived = { [weak self] config in
            print("[MultiConnectionManager] BLE device discovered: \(config.nodeID)")
            self?.onDeviceConnected?(config.nodeID)
        }
    }
    
    func startBLEScan() {
        ble.startScan()
    }
    
    func stopBLEScan() {
        ble.stopScan()
    }
}
