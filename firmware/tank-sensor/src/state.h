#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

// Runtime state shared across sensor, BLE, and API modules.
// Always access under gStateMutex.
struct DeviceState {
    float    distance_cm  = -1.0f;
    uint8_t  level_pct    = 0;
    uint32_t last_read_ts = 0;   // seconds since boot
    bool     sensor_ok    = false;
    uint16_t queue_depth  = 0;
    int8_t   wifi_rssi    = 0;
    bool     wifi_ok      = false;
};

extern DeviceState       gState;
extern SemaphoreHandle_t gStateMutex;
