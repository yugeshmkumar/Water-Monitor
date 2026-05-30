#pragma once

#include <Arduino.h>

/**
 * Device state management
 * Encapsulates all global state in a single struct to improve testability
 */

struct SensorReading {
    float distance_cm;
    int level_pct;
    bool sensor_ok;
    unsigned long timestamp;
};

struct DeviceState {
    // WiFi state
    char wifi_ssid[64];
    char wifi_password[64];
    bool wifi_connected;
    unsigned long wifi_last_connect_attempt;
    
    // BLE state
    bool ble_enabled;
    char ble_device_id[32];
    
    // Sensor state
    SensorReading last_reading;
    unsigned long last_sensor_poll;
    
    // Queue state
    int queue_size;
    unsigned long queue_last_sync;
    
    // System state
    unsigned long system_uptime;
    int error_count;
};

/**
 * Global state instance - single point of truth
 */
extern DeviceState gDevice;

/**
 * Initialize device state to defaults
 */
void device_state_init();

/**
 * Update sensor reading with proper error handling
 */
bool device_state_update_reading(const SensorReading& reading);

/**
 * Reset error counter
 */
void device_state_reset_errors();

/**
 * Get current device state
 */
const DeviceState& device_state_get();

