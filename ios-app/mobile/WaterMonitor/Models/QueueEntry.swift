import Foundation

struct QueueEntry: Decodable {
    let seq: UInt32
    let ts: UInt32        // seconds since device boot
    let distanceCM: Double
    let levelPct: Int
    let sensorOk: Int     // 0 or 1

    enum CodingKeys: String, CodingKey {
        case seq, ts
        case distanceCM = "distance_cm"
        case levelPct   = "level_pct"
        case sensorOk   = "sensor_ok"
    }
}
