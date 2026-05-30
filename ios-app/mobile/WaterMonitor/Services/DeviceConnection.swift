import Foundation
import CoreBluetooth
import Observation

/// Manages connection to a single device (WiFi or BLE)
@Observable
final class DeviceConnection {
    let nodeID: String
    
    var transport: Transport = .none
    var status: DeviceStatus?
    var config: DeviceConfig?
    var isConnected: Bool = false
    var lastUpdateTime: Date?
    
    private let wifi = WiFiService()
    
    // Exclude from observation to avoid issues with CBPeripheral
    @ObservationIgnored
    private var blePeripheral: CBPeripheral?  // If using BLE
    
    init(nodeID: String) {
        self.nodeID = nodeID
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        wifi.onLiveReading = { [weak self] status in
            Task { @MainActor in
                self?.status = status
                self?.lastUpdateTime = Date()
            }
        }
    }
    
    // MARK: - Connection Management
    
    func connectViaWiFi(host: String) {
        print("[DeviceConnection] \(nodeID): Connecting to WiFi \(host)")
        wifi.configure(host: host)
        
        Task {
            do {
                // Test connection
                let status = try await wifi.fetchStatus()
                await MainActor.run {
                    self.status = status
                    self.transport = .wifi
                    self.isConnected = true
                    self.lastUpdateTime = Date()
                }
                
                // Fetch config
                if let config = try? await wifi.fetchConfig() {
                    await MainActor.run {
                        self.config = config
                    }
                }
                
                // Start WebSocket for live updates
                await MainActor.run {
                    self.wifi.connectWebSocket()
                }
                
                print("[DeviceConnection] \(nodeID): Connected successfully")
            } catch {
                print("[DeviceConnection] \(nodeID): Connection failed - \(error.localizedDescription)")
                await MainActor.run {
                    self.isConnected = false
                    self.transport = .none
                }
            }
        }
    }
    
    func disconnect() {
        wifi.disconnectWebSocket()
        isConnected = false
        transport = .none
    }
    
    // MARK: - Configuration
    
    func writeConfig(_ patch: [String: Any]) async throws {
        guard transport == .wifi else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected via WiFi"])
        }
        try await wifi.patchConfig(patch)
    }
    
    func sendCommand(_ cmd: [String: Any]) async throws -> String {
        guard transport == .wifi else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected via WiFi"])
        }
        return try await wifi.sendCommand(cmd)
    }
}
