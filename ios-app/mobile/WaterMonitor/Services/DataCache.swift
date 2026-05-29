import Foundation
import SwiftData

final class DataCache {
    private let context: ModelContext
    var currentNodeID: String = ""  // set by ConnectionManager when device connects
    var testModeEnabled: Bool = false  // set by ConnectionManager when device config received

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ status: DeviceStatus) {
        guard status.sensorOk else { return }
        let reading = DeviceReading(
            timestamp: Date(),
            nodeID: currentNodeID,
            levelPct: status.levelPct,
            distanceCM: status.distanceCM,
            sensorOk: status.sensorOk,
            isTest: testModeEnabled
        )
        context.insert(reading)
        try? context.save()
        pruneOldEntries()
    }

    func saveQueueEntries(_ entries: [[String: Any]], bootTime: Date) {
        for entry in entries {
            guard let sensorOk = entry["sensor_ok"] as? Int, sensorOk == 1,
                  let ts         = entry["ts"]          as? Int,
                  let levelPct   = entry["level_pct"]   as? Int,
                  let distanceCM = entry["distance_cm"] as? Double else { continue }

            let timestamp = bootTime.addingTimeInterval(TimeInterval(ts))
            guard !hasDuplicate(near: timestamp) else { continue }

            context.insert(DeviceReading(
                timestamp: timestamp,
                nodeID: currentNodeID,
                levelPct: levelPct,
                distanceCM: distanceCM,
                sensorOk: true,
                isTest: testModeEnabled
            ))
        }
        try? context.save()
        pruneOldEntries()
    }

    func readings(since date: Date, nodeID: String? = nil, includeTest: Bool = false) -> [DeviceReading] {
        // Fetch all readings since date, then filter by nodeID and test mode
        let predicate = #Predicate<DeviceReading> { $0.timestamp >= date }
        var desc = FetchDescriptor<DeviceReading>(predicate: predicate,
                                                   sortBy: [SortDescriptor(\.timestamp)])
        desc.fetchLimit = 2000
        let all = (try? context.fetch(desc)) ?? []

        return all.filter { r in
            // If nodeID specified and not empty, match exact device; otherwise accept all
            let matchesNode = if let id = nodeID, !id.isEmpty {
                r.nodeID == id
            } else {
                true  // no device filter—fetch from all devices
            }
            // Filter out test readings unless explicitly included
            let matchesTestMode = includeTest || !r.isTest
            return matchesNode && matchesTestMode
        }
    }

    private func hasDuplicate(near timestamp: Date) -> Bool {
        let lo = timestamp.addingTimeInterval(-1.0)
        let hi = timestamp.addingTimeInterval(1.0)
        let pred = #Predicate<DeviceReading> { $0.timestamp >= lo && $0.timestamp <= hi }
        var desc = FetchDescriptor<DeviceReading>(predicate: pred)
        desc.fetchLimit = 1
        return (try? context.fetch(desc))?.isEmpty == false
    }

    private func pruneOldEntries() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)  // keep 30 days
        try? context.delete(model: DeviceReading.self,
                            where: #Predicate { $0.timestamp < cutoff })
    }
}
