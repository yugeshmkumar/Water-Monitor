import Foundation
import Combine

@Observable
final class WiFiService: DeviceService {
    var liveStatus: DeviceStatus?
    var deviceConfig: DeviceConfig?
    var isConnected: Bool = false {
        didSet {
            if oldValue != isConnected {
                onConnectionStateChanged?(isConnected)
            }
        }
    }
    var host: String?
    var lastError: Error?
    var autoReconnect: Bool = true
    var commandResult: String?
    
    // DeviceService callbacks
    var onLiveReading: ((DeviceStatus) -> Void)?
    var onConfigReceived: ((DeviceConfig) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    private let session: URLSession
    private let wsSession: URLSession
    private var wsTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    
    // Connection state tracking
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 5
    private var reconnectTask: Task<Void, Never>?
    private var isConnecting: Bool = false
    private var isReconnecting: Bool = false

    init() {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = NetworkConstants.wifiTimeout
        sessionConfig.timeoutIntervalForResource = NetworkConstants.wifiResourceTimeout
        sessionConfig.waitsForConnectivity = false
        sessionConfig.connectionProxyDictionary = [:]
        
        self.session = URLSession(configuration: sessionConfig)
        
        let wsConfig = URLSessionConfiguration.default
        wsConfig.timeoutIntervalForRequest = NetworkConstants.webSocketTimeout
        wsConfig.timeoutIntervalForResource = NetworkConstants.webSocketResourceTimeout
        wsConfig.waitsForConnectivity = false
        wsConfig.connectionProxyDictionary = [:]
        
        self.wsSession = URLSession(configuration: wsConfig)
    }

    func configure(host: String) {
        self.host = host
        reconnectAttempts = 0
        autoReconnect = true
    }
    
    // MARK: - DeviceService Protocol
    
    func connect() async throws {
        guard host != nil else {
            throw AppError.connectionFailed(host: "unknown", reason: "No host configured")
        }
        
        let status = try await fetchStatus()
        let config = try await fetchConfig()
        
        liveStatus = status
        deviceConfig = config
        
        connectWebSocket()
    }
    
    func disconnect() {
        disconnectWebSocket()
    }

    // MARK: - REST

    func fetchStatus() async throws -> DeviceStatus {
        do {
            let status = try await get(path: "/api/status", as: DeviceStatus.self)
            liveStatus = status
            lastError = nil
            return status
        } catch {
            lastError = error
            // ✅ Only log meaningful errors, not every timeout
            if !isTimeoutError(error) {
                print("[WiFi] fetchStatus failed: \(error.localizedDescription)")
            }
            throw error
        }
    }

    func fetchConfig() async throws -> DeviceConfig {
        do {
            let cfg = try await get(path: "/api/config", as: DeviceConfig.self)
            deviceConfig = cfg
            lastError = nil
            return cfg
        } catch {
            lastError = error
            if !isTimeoutError(error) {
                print("[WiFi] fetchConfig failed: \(error.localizedDescription)")
            }
            throw error
        }
    }

    func fetchDiagnostics() async throws -> DeviceDiagnostics {
        do {
            let diag = try await get(path: "/api/diagnostics", as: DeviceDiagnostics.self)
            lastError = nil
            return diag
        } catch {
            lastError = error
            if !isTimeoutError(error) {
                print("[WiFi] fetchDiagnostics failed: \(error.localizedDescription)")
            }
            throw error
        }
    }

    func patchConfig(_ patch: [String: Any]) async throws {
        do {
            try await post(path: "/api/config", body: patch)
            lastError = nil

            // Only fetch if WebSocket is disconnected (otherwise it will push update)
            if !isConnected {
                print("[WiFi] Config patched, fetching updated config...")
                do {
                    _ = try await fetchConfig()
                    print("[WiFi] Config refreshed successfully")
                } catch {
                    print("[WiFi] Warning: Failed to refresh config after patch: \(error)")
                }
            } else {
                print("[WiFi] Config patched, waiting for WebSocket update...")
            }
        } catch {
            lastError = error
            throw error
        }
    }

    func sendCommand(_ cmd: [String: Any]) async throws -> String {
        do {
            let data = try await post(path: "/api/command", body: cmd)
            lastError = nil
            // Parse response as string
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            lastError = error
            throw error
        }
    }

    func startOTA(url firmwareURL: String) {
        Task { try? await post(path: "/api/ota/start", body: ["url": firmwareURL]) }
    }

    // MARK: - WebSocket

    func connectWebSocket() {
        guard !isConnecting && !isConnected else {
            print("[WiFi] WebSocket already connected or connecting")
            return
        }
        
        guard let url = wsURL else {
            print("[WiFi] Cannot connect: invalid WebSocket URL")
            return
        }
        
        isConnecting = true
        wsTask = wsSession.webSocketTask(with: url)
        wsTask?.resume()
        
        print("[WiFi] WebSocket connecting to \(url)")
        receiveNext()
        startPingTimer()
    }

    func disconnectWebSocket() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        
        pingTask?.cancel()
        pingTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
        isConnecting = false
        
        print("[WiFi] WebSocket disconnected")
    }

    private func receiveNext() {
        guard let task = wsTask else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.wsTask != nil else { return }
                switch result {
                case .success(let msg):
                    // ✅ Set connected ONLY after first successful message
                    if !self.isConnected {
                        self.isConnected = true
                        self.isConnecting = false
                        self.reconnectAttempts = 0
                        print("[WiFi] WebSocket connected successfully")
                    }
                    
                    if case .string(let text) = msg,
                       let data = text.data(using: .utf8),
                       let s = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
                        self.liveStatus = s
                        self.onLiveReading?(s)
                        print("[WiFi] Received live reading: \(s.levelPct)% @ \(s.distanceCM)cm")
                    } else if case .string(let text) = msg {
                        print("[WiFi] Received non-status message: \(text)")
                    }
                    self.receiveNext()
                case .failure(let error):
                    print("[WiFi] WebSocket error: \(error.localizedDescription)")
                    self.lastError = error
                    self.isConnected = false
                    self.isConnecting = false
                    
                    // Exponential backoff with max attempts
                    if self.autoReconnect && !Task.isCancelled && !self.isReconnecting {
                        guard self.reconnectAttempts < self.maxReconnectAttempts else {
                            print("[WiFi] Max reconnection attempts reached, giving up")
                            self.autoReconnect = false
                            return
                        }
                        
                        self.isReconnecting = true
                        self.reconnectAttempts += 1
                        
                        let delay = min(pow(2.0, Double(self.reconnectAttempts)), 32.0)
                        print("[WiFi] WebSocket reconnecting in \(Int(delay))s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))...")
                        
                        self.reconnectTask?.cancel()
                        self.reconnectTask = Task { [weak self] in
                            try? await Task.sleep(for: .seconds(delay))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                self?.isReconnecting = false
                                self?.connectWebSocket()
                            }
                        }
                    }
                }
            }
        }
    }

    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while let self, self.wsTask != nil, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(NetworkConstants.webSocketPingInterval))
                guard !Task.isCancelled else { break }
                self.wsTask?.sendPing { _ in }
            }
        }
    }

    // MARK: - Queue flush

    func fetchQueue() async throws -> [[String: Any]] {
        guard let url = baseURL?.appending(path: "/api/queue/flush") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let (data, _) = try await session.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    func ackQueue(upTo seq: UInt32) async throws {
        try await post(path: "/api/queue/ack", body: ["seq_up_to": seq])
    }

    // MARK: - Helpers

    private var baseURL: URL? {
        host.flatMap { URL(string: "http://\($0)") }
    }

    private var wsURL: URL? {
        guard let h = host else { return nil }
        return URL(string: "ws://\(h)/live")
    }
    
    private func isTimeoutError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func get<T: Decodable>(path: String, as: T.Type) async throws -> T {
        guard let url = baseURL?.appending(path: path) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func post(path: String, body: [String: Any]) async throws -> Data {
        guard let url = baseURL?.appending(path: path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
