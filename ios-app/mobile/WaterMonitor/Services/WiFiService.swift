import Foundation

/**
 * WiFiService — HTTP and WebSocket coordination for WiFi-connected device
 *
 * Delegates to RestClient (HTTP/REST) and WebSocketManager (WebSocket streaming).
 * Provides unified interface for ConnectionManager.
 *
 * REFACTORING NOTE: Phase 3a extracted RestClient and WebSocketManager.
 * WiFiService is now a thin coordinator (11 lines of delegation vs 200+ of implementation).
 */
@Observable
final class WiFiService {
    var liveStatus: DeviceStatus? {
        didSet {
            if liveStatus != nil {
                wsManager?.liveStatus = liveStatus
            }
        }
    }
    var deviceConfig: DeviceConfig?
    var isConnected: Bool = false
    var host: String? {
        didSet {
            if let h = host {
                restClient = RestClient(host: h)
                wsManager = WebSocketManager(host: h)
            }
        }
    }
    var lastError: Error?
    var autoReconnect: Bool = true {
        didSet { wsManager?.autoReconnect = autoReconnect }
    }
    var commandResult: String?
    var onLiveReading: ((DeviceStatus) -> Void)? {
        didSet { wsManager?.onLiveReading = onLiveReading }
    }

    private var restClient: RestClient?
    private var wsManager: WebSocketManager?

    func configure(host: String) {
        self.host = host
    }

    // MARK: - REST (delegated to RestClient)

    func fetchStatus() async throws -> DeviceStatus {
        guard let client = restClient else { throw URLError(.badURL) }
        do {
            let status = try await client.fetchStatus()
            liveStatus = status
            lastError = nil
            return status
        } catch {
            lastError = error
            throw error
        }
    }

    func fetchConfig() async throws -> DeviceConfig {
        guard let client = restClient else { throw URLError(.badURL) }
        do {
            let cfg = try await client.fetchConfig()
            deviceConfig = cfg
            lastError = nil
            return cfg
        } catch {
            lastError = error
            throw error
        }
    }

    func patchConfig(_ patch: [String: Any]) async throws {
        guard let client = restClient else { throw URLError(.badURL) }
        do {
            try await client.patchConfig(patch)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    func sendCommand(_ cmd: [String: Any]) async throws -> String {
        guard let client = restClient else { throw URLError(.badURL) }
        do {
            let result = try await client.sendCommand(cmd)
            commandResult = result
            lastError = nil
            return result
        } catch {
            lastError = error
            throw error
        }
    }

    func startOTA(url firmwareURL: String) {
        Task { try? await restClient?.startOTA(url: firmwareURL) }
    }

    func fetchQueue() async throws -> [[String: Any]] {
        guard let client = restClient else { throw URLError(.badURL) }
        return try await client.fetchQueue()
    }

    func ackQueue(upTo seq: UInt32) async throws {
        guard let client = restClient else { throw URLError(.badURL) }
        try await client.ackQueue(upTo: seq)
    }

    // MARK: - WebSocket (delegated to WebSocketManager)

    func connectWebSocket() {
        guard let manager = wsManager else { return }
        isConnected = true
        manager.connect()
    }

    func disconnectWebSocket() {
        wsManager?.disconnect()
        isConnected = false
    }
}
