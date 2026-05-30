/**
 * Persistent Queue Store — Offline Reading Buffer
 *
 * OVERVIEW:
 * QueueStore provides a circular buffer for sensor readings when the device
 * is offline or unable to reach the cloud. Readings are persisted to LittleFS
 * (ESP32 flash storage) and sent to the app when WiFi/BLE reconnects.
 *
 * STORAGE STRATEGY:
 * • Binary format: Each QueueEntry is exactly 16 bytes (packed struct)
 * • Circular buffer in LittleFS: up to 2000 entries × 16 bytes = 32 KB max
 * • Metadata: head, tail, count, seq number (persisted separately)
 * • Durability: Each write() commits the entry and metadata to flash
 *
 * BUFFER LIFECYCLE:
 * 1. Device reads sensor → write(distance, pct) → entry stored in flash
 * 2. WiFi connects → /api/queue/flush endpoint called via REST
 * 3. App fetches batch of unsent entries (marked sent=0)
 * 4. App acknowledges receipt → /api/queue/ack {seq_up_to: N}
 * 5. Entries marked sent=1, marked for deletion via processPending()
 * 6. If buffer full → oldest unsent entries rolled off (FIFO)
 *
 * ACKNOWLEDGMENT FLOW:
 * Due to async context (REST runs on async_tcp task), acks are handled
 * in two phases to avoid flash writes from interrupt context:
 * • Phase 1: REST /api/queue/ack calls setPendingAck() (non-blocking)
 * • Phase 2: commsTask calls processPending() (blocks on flash I/O)
 *
 * SEQUENCE NUMBERS:
 * Each entry gets a monotonically increasing seq number (1, 2, 3, ...).
 * Used by app to detect gaps and order readings correctly.
 * Seq persists across reboots via metadata file.
 *
 * THREAD SAFETY:
 * • write() and getUnsent() are safe to call from sensorTask
 * • processPending() must be called from commsTask (non-interrupt)
 * • setPendingAck() is async-safe; only sets volatile _pendingAck
 *
 * FLASH WEAR CONSIDERATIONS:
 * Each write() and processPending() performs a flash erase/write cycle.
 * ESP32 flash is rated for ~100,000 cycles per block (1-2 year lifespan typical).
 * Impact analysis:
 *   • 1 reading/min = 1440 writes/day × 365 = 525,600 writes/year
 *   • At 100K cycle limit per 32KB block: ~0.19 years = ~70 days
 * Mitigation: Implement wear leveling across multiple files (future enhancement),
 * or use RTC + cloud sync to reduce queue writes when online.
 * Current design assumes WiFi connectivity ~1-2 hours/day, so write rate is low.
 *
 * TYPICAL USAGE:
 *   // Firmware (sensorTask)
 *   queueStore.write(distance, level_pct);
 *
 *   // App (via REST)
 *   GET /api/queue/flush → returns getUnsent(50)
 *
 *   // App acknowledges
 *   POST /api/queue/ack {"seq_up_to": 42}
 *     → calls setPendingAck(42)
 *
 *   // Firmware (commsTask)
 *   queueStore.processPending()  // marks seq 1-42 as sent
 */

#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>

/**
 * QueueEntry — Single Buffered Reading
 *
 * Exactly 16 bytes (packed) to fit nicely in flash blocks.
 * Each entry stores one sensor reading with timestamp and metadata.
 *
 * Fields:
 *   seq         - Sequence number (1, 2, 3, ...); unique per entry
 *   ts          - Seconds since device boot (when reading was taken)
 *   distance_cm - Measured distance in centimeters
 *   level_pct   - Calculated tank level (0-100%)
 *   sensor_ok   - 1 if reading passed validation, 0 if error
 *   sent        - 1 if app has acknowledged, 0 if pending
 *   _pad        - Unused byte for struct alignment (always 0)
 */
struct __attribute__((packed)) QueueEntry {
    uint32_t seq;              // Monotonic sequence number
    uint32_t ts;               // Seconds since device boot
    float    distance_cm;      // Distance reading in cm
    uint8_t  level_pct;        // Calculated fill percentage (0-100)
    uint8_t  sensor_ok;        // 1=valid reading, 0=sensor error
    uint8_t  sent;             // 1=app ack'd, 0=pending
    uint8_t  _pad;             // Alignment padding (unused)
};
// Compile-time check: struct must be exactly 16 bytes
static_assert(sizeof(QueueEntry) == 16, "QueueEntry must be 16 bytes");

/**
 * QueueStore — Persistent Circular Buffer for Offline Readings
 *
 * Manages a fixed-size (2000 entry) circular buffer on LittleFS (flash).
 * Entries persist across power loss and are sent to app on reconnection.
 */
class QueueStore {
public:
    /**
     * Initialize queue from LittleFS.
     * Loads metadata (head, tail, seq counter) and validates integrity.
     * Creates file if it doesn't exist.
     * Called from setup() once during boot.
     */
    void begin();

    /**
     * Store a new sensor reading in the queue.
     * Assigns next sequence number and marks sent=0.
     * Returns immediately (synchronous flash write).
     * If buffer is full, oldest unsent entry is overwritten.
     *
     * Parameters:
     *   dist - Distance reading (centimeters)
     *   pct  - Tank level percentage (0-100)
     *
     * Thread-safe: Call from sensorTask.
     */
    void write(float dist, uint8_t pct);

    /**
     * Get count of entries pending acknowledgment.
     * Used to display "X readings queued" in app UI.
     * Returns number of entries with sent=0.
     */
    uint16_t pendingCount();

    /**
     * Fetch batch of unacknowledged entries as JSON.
     * Populates JsonArray with up to max entries (default 50).
     * Format: [{"seq": 1, "ts": 123, "distance_cm": 45.2, ...}, ...]
     * Used by /api/queue/flush endpoint.
     *
     * Parameters:
     *   out - JsonArray to populate
     *   max - Max entries to return (default 50 to limit JSON payload)
     *
     * Thread-safe: Call from commsTask.
     */
    void getUnsent(JsonArray out, uint16_t max = 50);

    /**
     * Mark entries as acknowledged (seq 1 through seq_n).
     * Sets entries with seq <= seq_n to sent=1, marking them for deletion.
     * Does NOT delete immediately (see processPending).
     * This is the final processing step; processPending() is called separately.
     *
     * Parameters:
     *   seq - Highest sequence number that was acknowledged
     *
     * Example:
     *   App says "I got readings up to seq 42" → call ackUpTo(42)
     *   All entries with seq <= 42 marked sent=1.
     *
     * Not currently used; processPending() handles the workflow instead.
     */
    void ackUpTo(uint32_t seq);

    /**
     * Record pending acknowledgment (async-safe).
     * Called from async_tcp REST handler (/api/queue/ack endpoint).
     * Just sets a volatile flag; actual flash update happens in processPending().
     * Returns immediately (no blocking I/O).
     *
     * Parameters:
     *   seq - Highest sequence number to acknowledge (from request body)
     *
     * Thread-safe: Call from async context (interrupt-safe).
     *
     * Usage:
     *   POST /api/queue/ack {"seq_up_to": 42}
     *     → calls setPendingAck(42)
     */
    void setPendingAck(uint32_t seq);

    /**
     * Process pending acknowledgments (non-async).
     * Reads _pendingAck flag set by setPendingAck() and deletes entries.
     * Blocks while writing to flash; must be called from commsTask (not async).
     * Called periodically from main loop.
     *
     * Thread-safe: Call from commsTask only.
     * Safe to call repeatedly; no-op if no pending acks.
     */
    void processPending();

    /**
     * Clear all queue entries and reset seq counter.
     * Used for factory reset or explicit user action.
     * Warning: Loses all pending readings.
     */
    void clear();

private:
    // Configuration
    static const uint16_t MAX_ENTRIES = 2000;  // Capacity limit
    static const char*    FILE_PATH;           // LittleFS file path

    // State
    uint32_t _nextSeq      = 1;      // Next sequence number to assign
    uint16_t _count        = 0;      // Current entries in buffer
    uint16_t _pending      = 0;      // Entries pending ack
    uint16_t _head         = 0;      // Write pointer (next entry index)
    uint16_t _tail         = 0;      // Read pointer (oldest entry index)
    volatile uint32_t _pendingAck = 0;  // Ack to process (set by async, read by task)

    // Private helpers
    void _loadMeta();                      // Load head/tail/seq from metadata file
    void _saveMeta();                      // Save head/tail/seq to metadata file
    void _ensureFile();                    // Create file if it doesn't exist
    bool _readEntry(uint16_t idx, QueueEntry& e);   // Read entry at index
    void _writeEntry(uint16_t idx, const QueueEntry& e);  // Write entry at index
};

// Global QueueStore instance
extern QueueStore queueStore;
