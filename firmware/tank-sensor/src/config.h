#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>

struct DeviceConfig {
    char     wifi_ssid[64]        = "";
    char     wifi_pass[64]        = "";
    float    tank_empty_cm        = 150.0f; // sensor→bottom when empty
    float    tank_full_cm         = 20.0f;  // sensor→surface when full
    uint32_t tank_volume_l        = 1000;
    uint8_t  alert_low_pct        = 15;
    uint8_t  alert_high_pct       = 95;
    uint16_t poll_interval_s      = 30;    // Normal polling: 15s–15min (default 30s)
    bool     testing_mode         = false; // When true, use test_poll_interval_s instead
    uint8_t  test_poll_interval_s = 3;    // Test polling: 1s–10s (default 3s)
    bool     watchdog_enabled     = true;  // Hardware watchdog (auto-restart on hang) — disable for development
    char     pin_trig[4]          = "D2";
    char     pin_echo[4]          = "D1";
    char     node_id[32]          = "sensor-a";
    char     mqtt_broker_ip[16]   = "";
    char     firmware_version[16] = "1.0.0";
    // Auto-calibration tracking (AI learns over cycles)
    bool     auto_calibration_enabled = false;
    float    auto_cal_min_cm      = 999.0f; // Detected minimum distance
    float    auto_cal_max_cm      = -1.0f;  // Detected maximum distance
    uint16_t calibration_cycles   = 0;      // Number of fill/drain events seen
    uint8_t  calibration_confidence = 0;    // 0-100%, increases with cycles
};

class Config {
public:
    void load();
    void save();
    // Applies only the keys present in the JSON string; saves to NVS on success.
    bool applyPartialJson(const char* json);
    void toJson(JsonDocument& out) const;
    void toJsonString(char* buf, size_t len) const;

    DeviceConfig d;
};

extern Config config;
