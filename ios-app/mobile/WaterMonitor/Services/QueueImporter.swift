import Foundation
import SwiftData

/**
 * QueueImporter — Bulk import readings from device queue
 *
 * Fetches readings buffered on device (via /api/queue/flush), reconstructs
 * absolute timestamps using device boot time, and imports to DataCache while
 * deduplicating against live readings already saved.
 *
 * Why Separate?
 * Bulk import logic is complex (timestamp reconstruction, deduplication)
 * and unrelated to live reading persistence or history queries. Extracting
 * it improves maintainability and testability of DataCache.
 *
 * Deduplication Strategy:
 * Device sends readings with timestamp = seconds since boot.
 * App may have already saved these via live stream (timestamp = absolute).
 * Deduplicator checks for readings within ±1 second of queued entry
 * to prevent double-counting.
 */
final class QueueImporter {
    private weak var modelContext: ModelContext?

    /**
     * Initialize importer with SwiftData context.
     *
     * Parameters:
     *   modelContext - ModelContext for persisting DeviceReading entities
     */
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /**
     * Import batch of queued readings from device.
     * Reconstructs timestamps using device boot time and saves to cache
     * while deduplicating against live readings.
     *
     * Parameters:
     *   entries   - Array of queue entries from /api/queue/flush
     *   bootTime  - Timestamp when device booted (for timestamp reconstruction)
     *   nodeID    - Device node ID to associate with readings
     *   testMode  - Whether test readings should be marked
     *
     * Example Queue Entry:
     *   {"seq": 1, "ts": 300, "distance_cm": 45.5, "level_pct": 50, "sensor_ok": 1}
     *
     * Returns: Count of successfully imported entries
     */
    func importQueueEntries(
        _ entries: [[String: Any]],
        bootTime: Date,
        nodeID: String,
        testMode: Bool
    ) -> Int {
        guard let context = modelContext else { return 0 }

        var imported = 0

        for entry in entries {
            // Extract required fields
            guard let sensorOk = entry["sensor_ok"] as? Int, sensorOk == 1,
                  let ts = entry["ts"] as? Int,
                  let levelPct = entry["level_pct"] as? Int,
                  let distanceCM = entry["distance_cm"] as? Double else {
                continue
            }

            // Reconstruct absolute timestamp from device boot time
            let timestamp = bootTime.addingTimeInterval(TimeInterval(ts))

            // Skip if we already have this reading (live stream already saved it)
            guard !hasDuplicate(near: timestamp, in: context) else {
                continue
            }

            // Create and insert reading
            let reading = DeviceReading(
                timestamp: timestamp,
                nodeID: nodeID,
                levelPct: levelPct,
                distanceCM: distanceCM,
                sensorOk: true,
                isTest: testMode
            )
            context.insert(reading)
            imported += 1
        }

        // Commit batch
        do {
            try context.save()
            if imported > 0 {
                print("[QueueImporter] Imported \(imported) queued readings")
            }
        } catch {
            print("[QueueImporter] Failed to save queue entries: \(error.localizedDescription)")
        }

        return imported
    }

    // MARK: - Private: Deduplication

    /**
     * Check if reading already exists within ±1 second of given timestamp.
     * Used to prevent double-counting when same reading comes from both
     * live stream and device queue.
     *
     * Parameters:
     *   timestamp - Target timestamp to check
     *   context   - SwiftData context for querying
     *
     * Returns: true if duplicate found, false otherwise
     */
    private func hasDuplicate(near timestamp: Date, in context: ModelContext) -> Bool {
        let lo = timestamp.addingTimeInterval(-1.0)
        let hi = timestamp.addingTimeInterval(1.0)
        let pred = #Predicate<DeviceReading> { $0.timestamp >= lo && $0.timestamp <= hi }
        var desc = FetchDescriptor<DeviceReading>(predicate: pred)
        desc.fetchLimit = 1
        return (try? context.fetch(desc))?.isEmpty == false
    }
}
