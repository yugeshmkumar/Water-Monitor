import Foundation

struct DeviceStatus: Decodable, Equatable {
    var levelPct: Int = 0
    var distanceCM: Double = -1
    var ts: UInt32 = 0
    var sensorOk: Bool = false
    var wifiOk: Bool = false
    var rssi: Int = 0
    var queueDepth: Int = 0
    var firmwareVersion: String = "?"
    var localIP: String?  // Device's local IP address when connected to WiFi

    enum CodingKeys: String, CodingKey {
        case levelPct = "level_pct"
        case distanceCM = "distance_cm"
        case ts
        case sensorOk = "sensor_ok"
        case wifiOk = "wifi_ok"
        case rssi
        case queueDepth = "queue_depth"
        case firmwareVersion = "fw"
        case localIP = "local_ip"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        levelPct        = (try? c.decode(Int.self,    forKey: .levelPct))        ?? 0
        distanceCM      = (try? c.decode(Double.self, forKey: .distanceCM))      ?? -1
        ts              = (try? c.decode(UInt32.self, forKey: .ts))              ?? 0
        sensorOk        = (try? c.decode(Bool.self,   forKey: .sensorOk))        ?? false
        wifiOk          = (try? c.decode(Bool.self,   forKey: .wifiOk))          ?? false
        rssi            = (try? c.decode(Int.self,    forKey: .rssi))            ?? 0
        queueDepth      = (try? c.decode(Int.self,    forKey: .queueDepth))      ?? 0
        firmwareVersion = (try? c.decode(String.self, forKey: .firmwareVersion)) ?? "?"
        localIP         = try? c.decode(String.self,  forKey: .localIP)
    }
}
