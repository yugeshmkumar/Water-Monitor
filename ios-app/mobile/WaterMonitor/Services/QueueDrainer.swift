import Foundation

/**
 * QueueDrainer — Coordinate device queue flushing to mobile app
 *
 * Fetches readings queued on device (via /api/queue/flush), reconstructs
 * timestamps using device boot time, imports to DataCache, and acknowledges
 * successful receipt back to device.
 *
 * Workflow:
 * 1. Fetch batch of up to 50 queue entries from device
 * 2. Reconstruct timestamps using device boot time
 * 3. Save to DataCache (deduplicates with live readings)
 * 4. Acknowledge receipt (with 3-attempt retry)
 * 5. Repeat until queue empty or error
 *
 * Extracted from ConnectionManager to isolate offline queue management.
 */
final class QueueDrainer {
    var isDrainingQueue: Bool = false
    private var deviceBootTime: Date?

    private weak var wifi: WiFiService?
    private weak var dataCache: DataCache?

    /**
     * Initialize queue drainer with required services.
     *
     * Parameters:
     *   wifi      - WiFiService for REST queue operations
     *   dataCache - DataCache for storing imported readings
     */
    init(wifi: WiFiService, dataCache: DataCache) {
        self.wifi = wifi
        self.dataCache = dataCache
    }

    /**
     * Manually trigger queue flush if conditions are met.
     * Called from BLE config notification or manual UI action.
     *
     * Guards prevent redundant drains (only one at a time).
     */
    func flushQueueViaREST() {
        guard !isDrainingQueue else { return }
        guard let wifi = wifi, wifi.isConnected else { return }

        Task { await drainQueue() }
    }

    /**
     * Execute queue drain loop.
     * Fetches batches from device, imports to cache, acknowledges.
     * Automatically stops when queue is empty or error occurs.
     *
     * Thread Safety: Runs on calling task's executor (typically main).
     * Async: May sleep between retries (up to 2s between ACK attempts).
     */
    func drainQueue() async {
        guard !isDrainingQueue else { return }
        isDrainingQueue = true
        defer { isDrainingQueue = false }

        guard let wifi = wifi, let dataCache = dataCache else { return }

        // Reconstruct device boot time from latest sensor reading
        // This allows converting queue timestamps (seconds since boot) to absolute times
        let latestTs = (wifi.liveStatus?.ts ?? 0)
        let bootTime = latestTs > 0
            ? Date().addingTimeInterval(-TimeInterval(latestTs))
            : Date().addingTimeInterval(-300)  // fallback: assume boot ~5 min ago
        self.deviceBootTime = bootTime

        var totalFlushed = 0

        // Loop until queue is empty or error
        while true {
            do {
                // Fetch next batch (up to 50 entries)
                let entries = try await wifi.fetchQueue()
                guard !entries.isEmpty else {
                    print("[QueueDrainer] Queue empty, drain complete")
                    break
                }

                // Import entries to local history with timestamp reconstruction
                dataCache.saveQueueEntries(entries, bootTime: bootTime)

                // Extract max sequence number for acknowledgment
                guard let maxSeq = entries.compactMap({ $0["seq"] as? Int }).max().map({ UInt32($0) }) else {
                    break
                }

                // Acknowledge receipt with 3 retries (transient timeout shouldn't lose batch)
                var acked = false
                for attempt in 1...3 {
                    do {
                        try await wifi.ackQueue(upTo: maxSeq)
                        acked = true
                        break
                    } catch {
                        print("[QueueDrainer] ACK attempt \(attempt) failed: \(error.localizedDescription)")
                        if attempt < 3 {
                            try? await Task.sleep(for: .seconds(2))
                        }
                    }
                }

                guard acked else {
                    print("[QueueDrainer] Failed to acknowledge after 3 attempts, stopping drain")
                    break
                }

                totalFlushed += entries.count
                print("[QueueDrainer] Batch \(entries.count) entries acked to seq \(maxSeq)")

                // Stop if batch was smaller than max (indicates end of queue)
                if entries.count < 50 {
                    break
                }
            } catch {
                print("[QueueDrainer] Flush error: \(error.localizedDescription)")
                break
            }
        }

        if totalFlushed > 0 {
            print("[QueueDrainer] Flush complete — \(totalFlushed) entries imported to history")
        }
    }
}
