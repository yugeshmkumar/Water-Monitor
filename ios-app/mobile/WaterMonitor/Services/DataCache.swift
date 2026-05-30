import Foundation
import SwiftData

/**
 * DataCache — Persistent Storage for Device Readings
 *
 * Persists water level readings to on-device SQLite via SwiftData.
 * Supports multiple data sources (live stream, device queue) and
 * provides flexible querying for historical analysis.
 *
 * REFACTORING NOTE: Phase 3d extracted QueueImporter and DataPruner.
 * DataCache now focuses on live reading persistence and history queries.
 *
 * Persistence Strategy:
 * • Live readings: Saved immediately from BLE/WiFi (via save())
 * • Queue readings: Bulk imported with timestamp reconstruction (via QueueImporter)
 * • Maintenance: Old entries auto-pruned by DataPruner (configurable retention)
 * • Deduplication: QueueImporter prevents double-counting
 * • Test Mode: Marks readings with isTest flag; filtered in history
 *
 * Usage:
 *   dataCache.save(status)  // Save live reading
 *   dataCache.readings(since: date, nodeID: "sensor-a")  // Query history
 *
 * Thread Safety: Call from main thread only (SwiftData requirement).
 */
final class DataCache {
    private let context: ModelContext
    private let queueImporter: QueueImporter
    private let dataPruner: DataPruner

    var currentNodeID: String = ""      // Device ID (set by ConnectionManager)
    var testModeEnabled: Bool = false   // Test mode flag (set by ConnectionManager)

    init(context: ModelContext) {
        self.context = context
        self.queueImporter = QueueImporter(modelContext: context)
        self.dataPruner = DataPruner(modelContext: context)
    }

    /**
     * Save a live sensor reading to persistent storage.
     * Only persists valid readings (sensorOk=true) to reduce noise.
     * Automatically prunes old entries to maintain storage bounds.
     *
     * Parameters:
     *   status - DeviceStatus from live BLE/WiFi stream
     */
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
        dataPruner.pruneOldEntries()
    }

    /**
     * Import batch of readings from device queue.
     * Reconstructs timestamps and deduplicates with live readings.
     * Delegates to QueueImporter for implementation.
     *
     * Parameters:
     *   entries  - Array from /api/queue/flush endpoint
     *   bootTime - Device boot timestamp (for reconstructing absolute times)
     */
    func saveQueueEntries(_ entries: [[String: Any]], bootTime: Date) {
        queueImporter.importQueueEntries(
            entries,
            bootTime: bootTime,
            nodeID: currentNodeID,
            testMode: testModeEnabled
        )
        dataPruner.pruneOldEntries()
    }

    /**
     * Fetch historical readings with flexible filtering.
     * Used by HistoryView for charts and trend analysis.
     *
     * Parameters:
     *   date        - Return readings after this date
     *   nodeID      - Filter to specific device (nil = all devices)
     *   includeTest - Include test readings (default: false)
     *
     * Returns: Array of DeviceReading (up to 2000 results)
     */
    func readings(since date: Date, nodeID: String? = nil, includeTest: Bool = false) -> [DeviceReading] {
        let predicate = #Predicate<DeviceReading> { $0.timestamp >= date }
        var desc = FetchDescriptor<DeviceReading>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
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
}
