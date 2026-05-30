/**
 * Global Runtime State & Synchronization
 *
 * ARCHITECTURE:
 * DeviceState is the single mutable state struct shared by FreeRTOS tasks.
 * It is protected by gStateMutex (binary semaphore) to prevent data races.
 *
 * TASKS THAT ACCESS gState:
 * • sensorTask   - Updates last_read_ts, distance_cm, level_pct, sensor_ok
 * • wifiTask     - Updates wifi_rssi, wifi_ok
 * • commsTask    - Reads all fields for REST/BLE broadcasts
 * • bleTask      - Reads all fields for BLE advertising
 *
 * SYNCHRONIZATION PATTERN:
 * FreeRTOS binary semaphore (mutex). All reads and writes must acquire lock:
 *
 *   if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
 *       gState.distance_cm = new_distance;  // Write
 *       float snap = gState.distance_cm;     // Read
 *       xSemaphoreGive(gStateMutex);
 *   } else {
 *       // timeout; state was held by another task
 *   }
 *
 * WHY MUTEX (NOT ATOMIC OR VOLATILE):
 * • Atomic operations can't protect multiple related fields (e.g., prevent
 *   distance and level from being out of sync if both are updated together)
 * • Volatile only suppresses compiler optimizations; doesn't provide ordering
 * • Mutex ensures all-or-nothing updates via FreeRTOS scheduler
 *
 * CRITICAL SECTIONS:
 * Lock timeout: 50ms (chosen to prevent high-priority tasks from starving)
 * If lock cannot be acquired, log error and skip update (never busy-wait)
 *
 * INITIALIZATION:
 * gStateMutex created in setup() via xSemaphoreCreateMutex()
 * gState initialized to defaults (distance=-1, level=0, sensor_ok=false)
 *
 * PERFORMANCE:
 * Semaphore operations on ESP32:
 * • xSemaphoreTake(): ~1-2 microseconds (uncontended)
 * • xSemaphoreGive(): ~1 microsecond
 * • Context switch overhead if lock held: ~10-50 microseconds
 * Not a bottleneck; typical hold times <10 microseconds per access
 *
 * DEADLOCK PREVENTION:
 * Only one mutex exists (no lock ordering issues).
 * Tasks never hold mutex across blocking operations (I/O, delays).
 *
 * USAGE FROM DIFFERENT TASK PRIORITIES:
 * sensorTask (high) and bleTask (medium) can both access safely.
 * Priority inversion is mitigated by short critical sections (<1ms).
 */

#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

/**
 * DeviceState — Shared Mutable State for All Tasks
 *
 * All fields must be accessed under gStateMutex lock.
 * Never write to gState without holding the lock.
 * Reads are also protected to ensure consistency (all fields coherent).
 *
 * FIELDS:
 *   distance_cm  - Latest ultrasonic distance reading (cm), or -1 if no valid reading
 *   level_pct    - Calculated tank fill percentage (0-100), computed from distance
 *   last_read_ts - Timestamp of last reading (seconds since device boot)
 *   sensor_ok    - True if last reading passed validation checks
 *   queue_depth  - Number of queued readings pending sync to app
 *   wifi_rssi    - WiFi signal strength (dBm, -100 to 0; -100 = worst)
 *   wifi_ok      - True if WiFi is connected and ready
 *
 * SIZE:
 * Total 18 bytes (3 floats + 4 bools + 1 uint16 + 1 int8, plus padding)
 * Copy to stack for snapshot reads to avoid holding lock during processing.
 */
struct DeviceState {
    float    distance_cm  = -1.0f;      // Latest sensor reading (cm), or -1 if none
    uint8_t  level_pct    = 0;          // Tank level (0-100%), derived from distance
    uint32_t last_read_ts = 0;          // Timestamp of reading (seconds since boot)
    bool     sensor_ok    = false;      // True if reading passed validation
    uint16_t queue_depth  = 0;          // Pending readings in offline queue
    int8_t   wifi_rssi    = 0;          // WiFi signal (-100 to 0 dBm)
    bool     wifi_ok      = false;      // True if WiFi connected and responding
};

/**
 * Global state instance — single point of truth for all mutable state.
 * Initialized in setup(). Modified by sensor/WiFi tasks, read by API/BLE tasks.
 * ALWAYS accessed under gStateMutex lock — never read or write directly without it.
 */
extern DeviceState gState;

/**
 * Binary semaphore protecting gState.
 * Created in setup() via xSemaphoreCreateMutex().
 * Acquired before any gState access (read or write).
 * Timeout: 50ms to prevent high-priority tasks from blocking indefinitely.
 *
 * Example usage:
 *   if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
 *       DeviceState snap = gState;  // Atomic snapshot
 *       xSemaphoreGive(gStateMutex);
 *       // Now process snap safely without holding lock
 *   }
 */
extern SemaphoreHandle_t gStateMutex;
