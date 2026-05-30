import Foundation
import SwiftData

/**
 * DataPruner — Auto-cleanup of expired readings
 *
 * Removes readings older than retention window (30 days by default).
 * Bounds local database size while preserving recent history for analysis.
 *
 * Why Separate?
 * Pruning is maintenance logic unrelated to persistence or import.
 * Separating it allows:
 * - Running on different schedule (e.g., weekly vs on every save)
 * - Testing without affecting read/write logic
 * - Easier to adjust retention policy
 *
 * Retention Policy:
 * • Default window: 30 days
 * • Typical usage: ~100 readings per day (poll every 15 minutes)
 * • 30 days = ~3000 readings = ~1.5 MB on device
 *
 * Future Enhancement:
 * Could implement tiered retention (keep 1 entry/hour beyond 7 days)
 * to preserve longer-term trends while reducing storage.
 */
final class DataPruner {
    private weak var modelContext: ModelContext?

    // Default retention window (seconds)
    private let retentionWindow: TimeInterval = 30 * 24 * 3600  // 30 days

    /**
     * Initialize pruner with SwiftData context.
     *
     * Parameters:
     *   modelContext - ModelContext for querying and deleting readings
     */
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /**
     * Remove all readings older than retention window.
     * Called periodically to prevent unbounded database growth.
     *
     * Thread Safety: Safe to call from any thread; runs synchronously.
     * Performance: Typically <100ms for 10K entries on modern devices.
     *
     * Returns: Count of entries removed
     */
    @discardableResult
    func pruneOldEntries() -> Int {
        guard let context = modelContext else { return 0 }

        let cutoff = Date().addingTimeInterval(-retentionWindow)
        var removed = 0

        do {
            let predicate = #Predicate<DeviceReading> { $0.timestamp < cutoff }
            let desc = FetchDescriptor(predicate: predicate)

            // Fetch entries to delete (needed to get count for logging)
            let entriesToDelete = try context.fetch(desc)
            removed = entriesToDelete.count

            // Delete via predicate (more efficient than deleting individually)
            try context.delete(model: DeviceReading.self, where: predicate)

            if removed > 0 {
                print("[DataPruner] Removed \(removed) entries older than \(Int(retentionWindow / 86400)) days")
            }
        } catch {
            print("[DataPruner] Failed to prune old entries: \(error.localizedDescription)")
        }

        return removed
    }

    /**
     * Remove readings older than specific date.
     * Allows custom retention policies beyond default window.
     *
     * Parameters:
     *   cutoffDate - Entries older than this are deleted
     *
     * Returns: Count of entries removed
     */
    @discardableResult
    func pruneOlderThan(_ cutoffDate: Date) -> Int {
        guard let context = modelContext else { return 0 }

        var removed = 0
        do {
            let predicate = #Predicate<DeviceReading> { $0.timestamp < cutoffDate }
            let desc = FetchDescriptor(predicate: predicate)
            let entriesToDelete = try context.fetch(desc)
            removed = entriesToDelete.count

            try context.delete(model: DeviceReading.self, where: predicate)

            if removed > 0 {
                print("[DataPruner] Removed \(removed) entries older than \(cutoffDate.formatted())")
            }
        } catch {
            print("[DataPruner] Failed to prune entries: \(error.localizedDescription)")
        }

        return removed
    }

    /**
     * Get count of entries that would be deleted (without deleting).
     * Used for diagnostics or UI display.
     *
     * Returns: Count of entries older than retention window
     */
    func countExpiredEntries() -> Int {
        guard let context = modelContext else { return 0 }

        let cutoff = Date().addingTimeInterval(-retentionWindow)
        let predicate = #Predicate<DeviceReading> { $0.timestamp < cutoff }
        let desc = FetchDescriptor(predicate: predicate)

        return (try? context.fetchCount(desc)) ?? 0
    }
}
