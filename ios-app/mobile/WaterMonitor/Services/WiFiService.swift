import Foundation

@Observable
final class WiFiService {
    var liveStatus: DeviceStatus?
    var deviceConfig: DeviceConfig?
    var isConnected: Bool = false
    var host: String?
    var lastError: Error?
    var autoReconnect: Bool = true
    var commandResult: String?
    var onLiveReading: ((DeviceStatus) -> Void)?  // Callback when live data arrives (WiFi equivalent of BLE)

    private let session: URLSession
    private let wsSession: URLSession
    private var wsTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    
    // ✅ Best Practice: Exponential backoff for reconnection
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 5
    private var reconnectTask: Task<Void, Never>?
    
    // ✅ Best Practice: Connection state tracking to prevent duplicates
    private var isConnecting: Bool = false
    private var isReconnecting: Bool = false

    init() {
        // Regular session for REST calls with timeout
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 8  // ✅ Reduced from 10s - fail faster
        sessionConfig.timeoutIntervalForResource = 20  // ✅ Reduced from 30s
        sessionConfig.waitsForConnectivity = false  // ✅ Don't wait indefinitely
        
        // ✅ Disable proxy for local network connections
        sessionConfig.connectionProxyDictionary = [:]
        
        self.session = URLSession(configuration: sessionConfig)
        
        // Separate session for WebSocket with appropriate timeout
        let wsConfig = URLSessionConfiguration.default
        wsConfig.timeoutIntervalForRequest = 30  // ✅ Reduced from 60s
        wsConfig.timeoutIntervalForResource = 180  // ✅ Reduced from 300s
        wsConfig.waitsForConnectivity = false
        
        // ✅ Disable proxy to allow direct local network connections
        wsConfig.connectionProxyDictionary = [:]
        
        self.wsSession = URLSession(configuration: wsConfig)
    }

    func configure(host: String) {
        self.host = host
        // ✅ Reset reconnection state when reconfiguring
        reconnectAttempts = 0
        autoReconnect = true
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

    func patchConfig(_ patch: [String: Any]) async throws {
        do {
            try await post(path: "/api/config", body: patch)
            lastError = nil
            // Fetch updated config after successful patch
            print("[WiFi] Config patched, fetching updated config...")
            do {
                _ = try await fetchConfig()
                print("[WiFi] Config refreshed successfully")
            } catch {
                print("[WiFi] Warning: Failed to refresh config after patch: \(error)")
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
        // ✅ Best Practice: Prevent duplicate connection attempts
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
        isConnected = true
        isConnecting = false
        reconnectAttempts = 0  // ✅ Reset on successful connection
        print("[WiFi] WebSocket connecting to \(url)")
        receiveNext()
        startPingTimer()
    }

    func disconnectWebSocket() {
        // ✅ Best Practice: Cancel all reconnection attempts
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
                    if case .string(let text) = msg,
                       let data = text.data(using: .utf8),
                       let s = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
                        self.liveStatus = s
                        self.onLiveReading?(s)  // Notify observers (like ConnectionManager) of new data
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
                    
                    // ✅ Best Practice: Exponential backoff with max attempts
                    if self.autoReconnect && !Task.isCancelled && !self.isReconnecting {
                        guard self.reconnectAttempts < self.maxReconnectAttempts else {
                            print("[WiFi] Max reconnection attempts reached, giving up")
                            self.autoReconnect = false
                            return
                        }
                        
                        self.isReconnecting = true
                        self.reconnectAttempts += 1
                        
                        // Exponential backoff: 2^attempts seconds (2s, 4s, 8s, 16s, 32s)
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
                try? await Task.sleep(for: .seconds(30))
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
    
    // ✅ Best Practice: Identify timeout errors to reduce log noise
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
