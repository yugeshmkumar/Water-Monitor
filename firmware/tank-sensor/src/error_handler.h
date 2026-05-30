/**
 * Error Handling & Recovery Framework
 *
 * OVERVIEW:
 * ErrorHandler provides centralized error tracking and logging for the device.
 * It maintains:
 * - Error counter (incremented on each error)
 * - Last error code + timestamp (for diagnostics)
 * - Human-readable error messages with recovery suggestions
 *
 * PURPOSE:
 * - Track device health (error count visible in /api/status)
 * - Enable recovery strategies (e.g., retry with backoff)
 * - Provide diagnostics for mobile app (show "Check WiFi" hints)
 * - Support remote monitoring via cloud sync
 *
 * ERROR CODES:
 * ERROR_NONE (0)               - No error (default state)
 * ERROR_SENSOR_FAILURE (1)     - Ultrasonic sensor timeout or invalid reading
 *                                Recovery: Check wiring (TRIG→D2, ECHO→D1)
 * ERROR_WIFI_CONNECT_FAILED (2)- WiFi connection timeout or auth failed
 *                                Recovery: Verify SSID/password, check signal
 * ERROR_API_CALL_FAILED (3)    - REST API request failed (no response)
 *                                Recovery: Check device is on LAN, retry
 * ERROR_BLE_FAILURE (4)        - BLE advertising or GATT error
 *                                Recovery: Restart BLE, check for stack overflows
 * ERROR_QUEUE_FULL (5)         - Queue storage is at capacity (2000 entries)
 *                                Recovery: Flush queue via REST or BLE
 * ERROR_CONFIG_LOAD_FAILED (6) - NVS config corrupted on boot
 *                                Recovery: Config auto-resets to defaults
 * ERROR_MEMORY_INSUFFICIENT (7)- Heap allocation failed (OOM)
 *                                Recovery: Reduce polling rate, disable features
 *
 * USAGE:
 * ErrorHandler is a singleton (gErrorHandler) accessed from all tasks:
 *
 *   if (wifi_connect_failed) {
 *       gErrorHandler.log_error(ERROR_WIFI_CONNECT_FAILED,
 *                               "WiFi connect timeout",
 *                               "Check SSID and password");
 *   }
 *
 * THREAD SAFETY:
 * ErrorHandler is NOT internally locked. If accessed from multiple tasks,
 * synchronization must be done externally (similar to DeviceState).
 *
 * ERROR REPORTING:
 * Error count is reported to the mobile app via:
 * - /api/status endpoint (error_count field)
 * - Device notifications (if error count exceeds threshold)
 * The app can then suggest recovery steps based on the last error code.
 */

#pragma once

#include <Arduino.h>

// Error code enumeration - each represents a failure mode with recovery strategy
enum ErrorCode {
    ERROR_NONE = 0,                      // No error (normal state)
    ERROR_SENSOR_FAILURE = 1,            // Ultrasonic sensor unresponsive
    ERROR_WIFI_CONNECT_FAILED = 2,       // WiFi connection timeout or failed
    ERROR_API_CALL_FAILED = 3,           // HTTP request returned error
    ERROR_BLE_FAILURE = 4,               // BLE init or advertising failure
    ERROR_QUEUE_FULL = 5,                // NVS queue at capacity
    ERROR_CONFIG_LOAD_FAILED = 6,        // NVS config corrupted/unreadable
    ERROR_MEMORY_INSUFFICIENT = 7        // Heap allocation failed (out of memory)
};

/**
 * ErrorHandler - Centralized Error Logging & Recovery
 *
 * Tracks device errors, maintains error state, and provides recovery hints.
 * Used by all FreeRTOS tasks to report failures and coordinate recovery.
 */
class ErrorHandler {
private:
    int error_count;                     // Incremented on each error occurrence
    ErrorCode last_error;                // Last error code that occurred
    unsigned long last_error_time;       // Timestamp (millis) of last error

public:
    ErrorHandler();

    /**
     * Log an error with context and suggested recovery.
     * Increments error counter and updates last error state.
     * Logs to Serial for debugging.
     *
     * Parameters:
     *   code     - One of the ERROR_* codes above
     *   message  - Human-readable description (e.g., "WiFi timeout after 15s")
     *   recovery - Optional recovery hint for mobile app (e.g., "Check WiFi password")
     *
     * Example:
     *   gErrorHandler.log_error(ERROR_SENSOR_FAILURE,
     *                           "No echo response in 30ms",
     *                           "Check TRIG→D2 and ECHO→D1 wiring");
     */
    void log_error(ErrorCode code, const char* message, const char* recovery = nullptr);

    /**
     * Get the most recent error code.
     * Returns ERROR_NONE if no errors have occurred.
     */
    ErrorCode get_last_error() const;

    /**
     * Get total error count since last reset.
     * Reported to app via /api/status endpoint for health monitoring.
     */
    int get_error_count() const;

    /**
     * Reset error counter to 0.
     * Called after errors have been synced to cloud or logged.
     * Does not affect last_error or last_error_time (preserved for diagnostics).
     */
    void reset_error_count();

    /**
     * Check if device is currently in error state.
     * Returns true if error_count > 0 or last_error != ERROR_NONE.
     * Useful for deciding whether to retry operations.
     */
    bool has_errors() const;
};

// Global ErrorHandler singleton instance
extern ErrorHandler gErrorHandler;

