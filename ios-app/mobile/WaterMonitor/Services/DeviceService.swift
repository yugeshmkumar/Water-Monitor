import Foundation

/// Protocol for device communication services (WiFi, BLE, etc.)
protocol DeviceService: AnyObject {
    var liveStatus: DeviceStatus? { get }
    var deviceConfig: DeviceConfig? { get }
    var isConnected: Bool { get }
    var lastError: Error? { get }
    
    var onLiveReading: ((DeviceStatus) -> Void)? { get set }
    var onConfigReceived: ((DeviceConfig) -> Void)? { get set }
    var onConnectionStateChanged: ((Bool) -> Void)? { get set }
    
    func connect() async throws
    func disconnect()
    func fetchStatus() async throws -> DeviceStatus
    func fetchConfig() async throws -> DeviceConfig
    func patchConfig(_ patch: [String: Any]) async throws
    func sendCommand(_ cmd: [String: Any]) async throws -> String
}

/// Default implementations
extension DeviceService {
    var onConnectionStateChanged: ((Bool) -> Void)? {
        get { nil }
        set { }
    }
}
