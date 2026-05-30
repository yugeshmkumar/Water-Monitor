#pragma once

#include <Arduino.h>

/**
 * DeviceState — Centralized Global State Management
 *
 * OVERVIEW:
 * This module encapsulates all global state in a single DeviceState struct,
 * replacing scattered global variables. Benefits:
 * - Single source of truth for device status
 * - Improved testability (can be mocked/reset)
 * - Clear visibility of all global state
 * - Easier debugging and logging
 *
 * THREAD SAFETY:
 * DeviceState is NOT internally protected. Access from multiple tasks requires
 * external synchronization via gStateMutex (defined in state.h):
 *
 *   if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
 *       DeviceState snap = gDevice;  // Copy snapshot under lock
 *       xSemaphoreGive(gStateMutex);
 *   }
 *
 * LIFETIME:
 * DeviceState exists for the entire device lifecycle. It is initialized
 * once during boot and persisted in RAM (not to NVS). Persistent config
 * (WiFi SSID, BLE ID) is in Config class instead.
 *
 * USAGE EXAMPLE:
 *   SensorReading reading = {...};
 *   if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(100))) {
 *       device_state_update_reading(reading);
 *       xSemaphoreGive(gStateMutex);
 *   }
 */

// SensorReading holds a single polled sensor value with timestamp
struct SensorReading {
    float distance_cm;          // Distance in centimeters
    int level_pct;              // Calculated tank level (0-100%)
    bool sensor_ok;             // True if reading passed validation
    unsigned long timestamp;    // Seconds since device boot
};

// DeviceState is the global state struct - all shared mutable state lives here
// NOTE: When updating multiple related fields atomically, hold gStateMutex
// for the entire update sequence, not individual field writes:
//
//   xSemaphoreTake(gStateMutex, ...);
//   gDevice.distance_cm = dist;
//   gDevice.level_pct = pct;
//   gDevice.last_sensor_poll = now;
//   xSemaphoreGive(gStateMutex);  // All 3 fields updated atomically
//
struct DeviceState {
    // --- WiFi Connectivity State ---
    char wifi_ssid[64];                 // Current WiFi SSID (from Config)
    char wifi_password[64];             // Current WiFi password (from Config)
    bool wifi_connected;                // True if connected and ready
    unsigned long wifi_last_connect_attempt;  // Last WiFi connect attempt (millis)

    // --- BLE State ---
    bool ble_enabled;                   // True if BLE advertising is active
    char ble_device_id[32];             // Device ID advertised over BLE

    // --- Sensor Readings ---
    SensorReading last_reading;         // Most recent valid sensor reading
    unsigned long last_sensor_poll;     // Timestamp of last sensor poll (millis)

    // --- Queue State ---
    int queue_size;                     // Current pending entries in queue
    unsigned long queue_last_sync;      // Last time queue was synced to app

    // --- System Health ---
    unsigned long system_uptime;        // Seconds since device boot
    int error_count;                    // Number of errors since last reset
};

/**
 * Global state instance - single point of truth for all device state.
 * Access this via device_state_get() or by taking gStateMutex and reading directly.
 * NEVER write to gDevice directly — use device_state_update_reading() instead.
 */
extern DeviceState gDevice;

/**
 * Initialize device state to defaults.
 * Called once from main() during setup().
 * Zeros all fields except system_uptime (set to 0).
 */
void device_state_init();

/**
 * Update sensor reading in device state with validation.
 * Returns true if reading was accepted, false if rejected (out of range).
 * Thread-safe: caller must hold gStateMutex.
 *
 * Usage:
 *   xSemaphoreTake(gStateMutex, ...);
 *   device_state_update_reading(reading);
 *   xSemaphoreGive(gStateMutex);
 */
bool device_state_update_reading(const SensorReading& reading);

/**
 * Reset error counter to 0.
 * Called after errors have been logged to cloud.
 * Thread-safe: caller must hold gStateMutex.
 */
void device_state_reset_errors();

/**
 * Get a snapshot of current device state.
 * Creates a copy to avoid holding the lock. Safe to call from any task.
 * Note: Snapshot is point-in-time; fields may change immediately after return.
 * For transactional state reads, hold gStateMutex yourself.
 */
const DeviceState& device_state_get();

