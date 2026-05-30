import Foundation

/**
 * WebSocketManager — Real-time sensor streaming via WebSocket
 *
 * Manages WebSocket connection at /live endpoint, receives sensor readings,
 * maintains connection health with ping/pong, and auto-reconnects on failure.
 *
 * Thread Safety: Updates to liveStatus and isConnected are dispatched to MainActor.
 * Auto-Reconnect: Waits 5 seconds after disconnect before attempting reconnection.
 * Keepalive: Sends ping every 30 seconds to detect stale connections.
 */
@MainActor
final class WebSocketManager: NSObject {
    var liveStatus: DeviceStatus?
    var isConnected: Bool = false
    var autoReconnect: Bool = true
    var lastError: Error?
    var onLiveReading: ((DeviceStatus) -> Void)?  // Called when new status arrives

    private let wsSession: URLSession
    private let host: String
    private var wsTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?

    /**
     * Initialize WebSocket manager for a specific host.
     *
     * Parameters:
     *   host - IP address or mDNS hostname (e.g., "192.168.1.100" or "sensor-a.local")
     */
    init(host: String) {
        self.host = host

        // WebSocket session: longer timeouts (connection is long-lived)
        let wsConfig = URLSessionConfiguration.default
        wsConfig.timeoutIntervalForRequest = 60
        wsConfig.timeoutIntervalForResource = 300
        self.wsSession = URLSession(configuration: wsConfig)

        super.init()
    }

    /**
     * Open WebSocket connection to device.
     * Starts receiving loop and keepalive ping timer.
     */
    func connect() {
        guard let url = wsURL else { return }
        wsTask = wsSession.webSocketTask(with: url)
        wsTask?.resume()
        isConnected = true
        print("[WebSocket] Connecting to \(url)")
        receiveNext()
        startPingTimer()
    }

    /**
     * Close WebSocket connection gracefully.
     * Cancels ping timer and websocket task.
     */
    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
    }

    // MARK: - Private: Receive Loop

    /**
     * Continuously receive and process messages from WebSocket.
     * Decodes incoming JSON as DeviceStatus.
     * On error: logs message, updates connection state, optionally auto-reconnects.
     */
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
                        self.onLiveReading?(s)
                        print("[WebSocket] Received reading: \(s.levelPct)% @ \(s.distanceCM)cm")
                    } else if case .string(let text) = msg {
                        print("[WebSocket] Received non-status message: \(text)")
                    }
                    self.receiveNext()
                case .failure(let error):
                    print("[WebSocket] Error: \(error.localizedDescription)")
                    self.lastError = error
                    self.isConnected = false
                    if self.autoReconnect, !Task.isCancelled {
                        print("[WebSocket] Auto-reconnecting in 5 seconds...")
                        Task {
                            try? await Task.sleep(for: .seconds(5))
                            self.connect()
                        }
                    }
                }
            }
        }
    }

    /**
     * Send periodic pings to keep connection alive.
     * Runs every 30 seconds until connection closes.
     */
    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task {
            while let self, self.wsTask != nil, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                self.wsTask?.sendPing { _ in }
            }
        }
    }

    // MARK: - Private: URL Construction

    private var wsURL: URL? {
        URL(string: "ws://\(host)/live")
    }
}
