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

    init() {
        // Regular session for REST calls
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        sessionConfig.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: sessionConfig)
        
        // Separate session for WebSocket with longer timeout
        let wsConfig = URLSessionConfiguration.default
        wsConfig.timeoutIntervalForRequest = 60  // WebSocket needs longer timeout
        wsConfig.timeoutIntervalForResource = 300
        self.wsSession = URLSession(configuration: wsConfig)
    }

    func configure(host: String) {
        self.host = host
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
            throw error
        }
    }

    func patchConfig(_ patch: [String: Any]) async throws {
        do {
            try await post(path: "/api/config", body: patch)
            lastError = nil
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
        guard let url = wsURL else { return }
        wsTask = wsSession.webSocketTask(with: url)  // Use wsSession with longer timeout
        wsTask?.resume()
        isConnected = true
        print("[WiFi] WebSocket connecting to \(url)")
        receiveNext()
        startPingTimer()
    }

    func disconnectWebSocket() {
        pingTask?.cancel()
        pingTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
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
                    // Optional: auto-reconnect after delay
                    if self.autoReconnect, !Task.isCancelled {
                        print("[WiFi] WebSocket reconnecting in 5 seconds...")
                        try? await Task.sleep(for: .seconds(5))
                        self.connectWebSocket()
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
