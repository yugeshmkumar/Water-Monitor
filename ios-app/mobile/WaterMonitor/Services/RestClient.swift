import Foundation

/**
 * RestClient — HTTP REST API operations for Water Monitor device
 *
 * Encapsulates all REST endpoint calls (status, config, commands, queue).
 * Handles URL construction, request serialization, response parsing, and error handling.
 * Separate from WebSocket for clean separation of concerns.
 *
 * Thread Safety: Safe to call from any thread (URLSession is thread-safe).
 * Error Handling: Throws URLError on network failures or bad responses.
 */
final class RestClient {
    private let session: URLSession
    private let host: String

    var lastError: Error?

    /**
     * Initialize REST client for a specific host.
     *
     * Parameters:
     *   host - IP address or mDNS hostname (e.g., "192.168.1.100" or "sensor-a.local")
     */
    init(host: String) {
        self.host = host

        // REST session: shorter timeouts (typical response <1s)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - GET Requests

    /**
     * Fetch current device status (sensor reading + WiFi + queue).
     * GET /api/status → DeviceStatus JSON
     */
    func fetchStatus() async throws -> DeviceStatus {
        do {
            let status = try await get(path: "/api/status", as: DeviceStatus.self)
            lastError = nil
            return status
        } catch {
            lastError = error
            throw error
        }
    }

    /**
     * Fetch complete device configuration.
     * GET /api/config → DeviceConfig JSON
     */
    func fetchConfig() async throws -> DeviceConfig {
        do {
            let cfg = try await get(path: "/api/config", as: DeviceConfig.self)
            lastError = nil
            return cfg
        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - POST Requests

    /**
     * Update device configuration (partial fields).
     * POST /api/config with JSON patch
     * Example: {"pin_trig": "D3", "poll_interval_s": 30}
     */
    func patchConfig(_ patch: [String: Any]) async throws {
        do {
            try await post(path: "/api/config", body: patch)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    /**
     * Send a command to the device and receive response.
     * POST /api/command with command dict
     * Example: {"cmd": "test_pin", "pin": "D1"}
     * Returns: JSON response as string
     */
    func sendCommand(_ cmd: [String: Any]) async throws -> String {
        do {
            let data = try await post(path: "/api/command", body: cmd)
            lastError = nil
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            lastError = error
            throw error
        }
    }

    /**
     * Trigger OTA firmware update from URL.
     * POST /api/ota/start with firmware URL
     */
    func startOTA(url firmwareURL: String) async throws {
        do {
            try await post(path: "/api/ota/start", body: ["url": firmwareURL])
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    /**
     * Fetch queued readings from device buffer.
     * POST /api/queue/flush → Array of queue entries
     * Each entry: {seq, ts, distance_cm, level_pct, sensor_ok}
     */
    func fetchQueue() async throws -> [[String: Any]] {
        guard let url = baseURL?.appending(path: "/api/queue/flush") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let (data, _) = try await session.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    /**
     * Acknowledge queue entries up to sequence number.
     * POST /api/queue/ack with seq_up_to
     */
    func ackQueue(upTo seq: UInt32) async throws {
        try await post(path: "/api/queue/ack", body: ["seq_up_to": seq])
    }

    // MARK: - Private Helpers

    private var baseURL: URL? {
        URL(string: "http://\(host)")
    }

    /**
     * Generic GET request with JSON decoding.
     * Throws URLError on network failure or bad status code.
     */
    private func get<T: Decodable>(path: String, as: T.Type) async throws -> T {
        guard let url = baseURL?.appending(path: path) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /**
     * Generic POST request with JSON body.
     * Throws URLError on network failure or bad status code.
     */
    @discardableResult
    private func post(path: String, body: [String: Any]) async throws -> Data {
        guard let url = baseURL?.appending(path: path) else {
            throw URLError(.badURL)
        }
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
