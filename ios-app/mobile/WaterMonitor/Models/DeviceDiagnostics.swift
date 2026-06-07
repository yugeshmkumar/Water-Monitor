import Foundation

struct DeviceDiagnostics: Decodable {
    var sensor: SensorDiag?
    var wifi: WiFiDiag?
    var queue: QueueDiag?
    var system: SystemDiag?
    var config: ConfigSnapshot?

    struct SensorDiag: Decodable {
        var reads: Int
        var frameErrors: Int
        var timeouts: Int
        var lastRawCM: Double
        var lastFilteredCM: Double
        var errorRate: Double

        enum CodingKeys: String, CodingKey {
            case reads
            case frameErrors = "frame_errors"
            case timeouts
            case lastRawCM = "last_raw_cm"
            case lastFilteredCM = "last_filtered_cm"
            case errorRate = "error_rate_%"
        }
    }

    struct WiFiDiag: Decodable {
        var connected: Bool
        var rssiDBM: Int
        var ssid: String?

        enum CodingKeys: String, CodingKey {
            case connected
            case rssiDBM = "rssi_dbm"
            case ssid
        }
    }

    struct QueueDiag: Decodable {
        var pending: Int
    }

    struct SystemDiag: Decodable {
        var uptimeS: Int
        var heapFree: Int
        var heapTotal: Int
        var heapUsedPct: Double
        var psramFree: Int
        var fwVersion: String

        enum CodingKeys: String, CodingKey {
            case uptimeS = "uptime_s"
            case heapFree = "heap_free"
            case heapTotal = "heap_total"
            case heapUsedPct = "heap_used_%"
            case psramFree = "psram_free"
            case fwVersion = "fw_version"
        }
    }

    struct ConfigSnapshot: Decodable {
        var tankEmptyMM: Double
        var tankFullMM: Double
        var pollIntervalS: Int
        var testingMode: Bool

        enum CodingKeys: String, CodingKey {
            case tankEmptyMM = "tank_empty_cm"
            case tankFullMM = "tank_full_cm"
            case pollIntervalS = "poll_interval_s"
            case testingMode = "testing_mode"
        }
    }

    enum CodingKeys: String, CodingKey {
        case sensor, wifi, queue, config
    }
}
