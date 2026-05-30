import Foundation
import SwiftData

// DataCache — Persistent Storage for Device Readings
// ─────────────────────────────────────────────────────────────
// Uses SwiftData (iOS 17+) with on-device SQLite to persist
// water level readings and historical data across app launches.
//
// Persistence Strategy:
// • DeviceReading model: timestamp, nodeID, levelPct, distanceCM, sensorOk, isTest
// • Storage: Device-local SQLite database (not synced to iCloud)
// • Retention: Readings kept for 30 days; older entries auto-deleted
// • Deduplication: Avoids duplicates when importing queued readings from device
// • Test Mode: Marks readings with isTest flag; filtered in history by default
//
// Data Sources:
// 1. Live readings: saved immediately from BLE/WiFi in real-time
// 2. Device queue: bulk imported via /api/queue/flush on WiFi connection
//
// Usage:
//   dataCache.save(status)  // Save a live reading
//   dataCache.readings(since: date, nodeID: "sensor-a")  // Fetch history
//
// Thread Safety:
// Call from main thread only; SwiftData ModelContext is not thread-safe.
// ConnectionManager handles all data cache calls on main via MainActor.

final class DataCache {
    private let context: ModelContext
    var currentNodeID: String = ""  // set by ConnectionManager when device connects
    var testModeEnabled: Bool = false  // set by ConnectionManager when device config received

    init(context: ModelContext) {
        self.context = context
    }

    // save(_:)
    // ────────────────────────────────────────────────────────
    // Persists a live reading from the device to the local SQLite store.
    // Only saves readings with sensorOk=true to avoid noise from initialization
    // or sensor errors. Auto-prunes old entries after each save.
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
        do {
            try context.save()
        } catch {
            print("[DataCache] Failed to save reading: \(error.localizedDescription)")
        }
        pruneOldEntries()
    }

    // saveQueueEntries(_:bootTime:)
    // ────────────────────────────────────────────────────────
    // Imports a batch of readings from the device's on-board queue
    // (fetched via /api/queue/flush). Reconstructs absolute timestamps
    // using deviceBootTime since queued readings are stored as seconds
    // since device boot. Deduplicates to prevent duplicate imports if
    // queue flush is called multiple times.
    func saveQueueEntries(_ entries: [[String: Any]], bootTime: Date) {
        var imported = 0
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
            imported += 1
        }
        do {
            try context.save()
            if imported > 0 {
                print("[DataCache] Imported \(imported) queued readings")
            }
        } catch {
            print("[DataCache] Failed to save queue entries: \(error.localizedDescription)")
        }
        pruneOldEntries()
    }

    // readings(since:nodeID:includeTest:)
    // ────────────────────────────────────────────────────────
    // Fetches historical readings with flexible filtering:
    // • since: returns readings after this date
    // • nodeID: filters to a specific device (nil = all devices)
    // • includeTest: excludes test readings by default (false)
    //
    // Used by HistoryView for charts and graphs. Returns up to 2000 results.
    func readings(since date: Date, nodeID: String? = nil, includeTest: Bool = false) -> [DeviceReading] {
        let predicate = #Predicate<DeviceReading> { $0.timestamp >= date }
        var desc = FetchDescriptor<DeviceReading>(predicate: predicate,
                                                   sortBy: [SortDescriptor(\.timestamp)])
        desc.fetchLimit = 2000
        let all = (try? context.fetch(desc)) ?? []

        return all.filter { r in
            let matchesNode = if let id = nodeID, !id.isEmpty {
                r.nodeID == id
            } else {
                true
            }
            let matchesTestMode = includeTest || !r.isTest
            return matchesNode && matchesTestMode
        }
    }

    // hasDuplicate(near:)
    // ────────────────────────────────────────────────────────
    // Checks if a reading already exists within ±1 second of the given timestamp.
    // Used to deduplicate when importing from device queue to avoid double-counting
    // readings that were already saved from live stream.
    private func hasDuplicate(near timestamp: Date) -> Bool {
        let lo = timestamp.addingTimeInterval(-1.0)
        let hi = timestamp.addingTimeInterval(1.0)
        let pred = #Predicate<DeviceReading> { $0.timestamp >= lo && $0.timestamp <= hi }
        var desc = FetchDescriptor<DeviceReading>(predicate: pred)
        desc.fetchLimit = 1
        return (try? context.fetch(desc))?.isEmpty == false
    }

    // pruneOldEntries()
    // ────────────────────────────────────────────────────────
    // Removes readings older than 30 days to limit database size.
    // Called after each save to keep storage bounded. On typical water
    // level sensors (poll every 10-30 seconds), 30 days = ~30MB of data.
    private func pruneOldEntries() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        do {
            try context.delete(model: DeviceReading.self,
                              where: #Predicate { $0.timestamp < cutoff })
        } catch {
            print("[DataCache] Failed to prune old entries: \(error.localizedDescription)")
        }
    }
}
