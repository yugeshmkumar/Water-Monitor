#pragma once

#include <Arduino.h>

/**
 * Non-blocking timer management
 * Replaces blocking delay() calls with millis()-based timing
 */

class Timer {
private:
    unsigned long interval_ms;
    unsigned long last_trigger;
    bool enabled;
    
public:
    Timer(unsigned long interval_ms = 1000);
    
    /**
     * Check if timer has elapsed (non-blocking)
     * @return true if interval has passed since last trigger
     */
    bool is_ready();
    
    /**
     * Manually trigger and reset timer
     */
    void reset();
    
    /**
     * Enable/disable timer
     */
    void set_enabled(bool enabled);
    
    /**
     * Update interval
     */
    void set_interval(unsigned long interval_ms);
};

// System timers
extern Timer sensor_poll_timer;      // Poll sensor every 5 seconds
extern Timer wifi_check_timer;       // Check WiFi every 30 seconds
extern Timer ble_advertise_timer;    // BLE advertisement every 2 seconds
extern Timer queue_sync_timer;       // Sync queue every 60 seconds

void timers_init();
void timers_update();

