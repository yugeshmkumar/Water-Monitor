# Phase 1B — Firmware Completion Roadmap

**Date:** 2026-06-07  
**Status:** In Progress  
**Owner:** yugeshmluv

---

## 📋 Firmware Work Breakdown

### ✅ COMPLETED (Phase 1B-3)

1. **Sensor Module Refactoring**
   - ✅ `src/pins.h` — SR04M-2 UART GPIO configuration
   - ✅ `src/sensor.h` — New API (sensorInit, readDistanceCM, sensorSelfTest, getSensorDiagnostics)
   - ✅ `src/sensor.cpp` — Complete rewrite for triggered UART
     - Frame reception (0xFF, H, L, SUM)
     - Checksum validation
     - Temporal filtering (trimmed-mean, plausibility check)
     - Error tracking (timeouts, frame errors, read counts)

2. **Main Loop Integration (Partial)**
   - ✅ sensorInit() call in sensorTask
   - ✅ sensorSelfTest() on startup
   - ⏳ Update calibration references (tank_empty_cm → tank_empty_dist_mm)

---

### ⏳ IN PROGRESS (This Session)

#### Part A: Configuration & Calibration
- [ ] Update config schema references (cm → mm)
- [ ] Verify two-point calibration system
- [ ] Add factory reset on invalid calibration

#### Part B: WiFi Offline-First
- [ ] Implement non-blocking WiFi reconnect timer
- [ ] Verify queue management during outages
- [ ] Test 1-2 day offline tolerance

#### Part C: Diagnostics & Monitoring
- [ ] Add sensor diagnostics API endpoint
- [ ] Add WiFi statistics (RSSI, reconnect count)
- [ ] Add memory usage monitoring
- [ ] Add queue statistics

#### Part D: Testing & Validation
- [ ] Unit tests for frame validation
- [ ] Integration tests for measurement loop
- [ ] WiFi offline-first validation
- [ ] Self-test procedure documentation

---

## 🔧 CRITICAL FIX: Configuration References

### Issue
Current code uses `config.d.tank_empty_cm` and `config.d.tank_full_cm`, but HARDWARE_REV_G.md specifies:
- `config.d.tank_empty_dist_mm` — Distance from sensor to tank bottom (mm)
- `config.d.tank_full_dist_mm` — Distance from sensor to water surface (mm)

### Solution
Update sensorTask to use mm-based calibration and convert properly.

---

## 🌐 WiFi Offline-First Implementation

### Current Behavior
- WiFi reconnect happens in commsTask every 500ms
- Blocking on wifiConnect() if network unavailable
- Measurements continue (good!)
- Queue fills automatically (good!)

### Desired Behavior (Phase 1D)
- Attempt WiFi reconnect every 50 seconds (not every 500ms)
- Non-blocking (immediate return, no delay)
- Track reconnection attempts
- Report WiFi statistics to BLE/REST API

### Implementation
```cpp
// WiFi reconnect scheduler (non-blocking)
static unsigned long lastWiFiAttempt = 0;
static const unsigned long WIFI_RETRY_INTERVAL = 50000;  // 50 seconds

// In commsTask:
if (WiFi.status() != WL_CONNECTED) {
    if (millis() - lastWiFiAttempt > WIFI_RETRY_INTERVAL) {
        lastWiFiAttempt = millis();
        Serial.println("[WiFi] Attempting reconnect...");
        WiFi.begin(config.d.wifi_ssid, config.d.wifi_pass);
        // Don't wait for result — return immediately
    }
}
```

---

## 📊 Diagnostics System

### Current Diagnostics Available
- ✅ SensorDiag structure (read count, errors, timeouts, raw/filtered distance)
- ✅ DeviceState structure (distance_cm, level_pct, sensor_ok, wifi_ok, queue_depth)

### Required Additions
- WiFi reconnection attempts counter
- Memory usage (heap free, stack watermark)
- Queue statistics (pending entries, total written, flushed)
- Frame validation success rate
- Last successful read timestamp

### API Endpoints (REST)
```
GET /api/diagnostics
{
  "sensor": {
    "reads": 1250,
    "errors": 5,
    "timeouts": 2,
    "last_raw_cm": 150.5,
    "last_filtered_cm": 150.3
  },
  "system": {
    "uptime_s": 86400,
    "heap_free_bytes": 45000,
    "queue_pending": 12,
    "queue_total": 5420
  },
  "wifi": {
    "connected": true,
    "rssi": -45,
    "reconnect_attempts": 3,
    "last_reconnect_s": 3600
  }
}
```

---

## ✅ Testing Strategy

### Unit Tests

#### Test 1: Frame Validation
```cpp
void test_sensorFrameValidation() {
    // Valid frame: 0xFF, 0x12, 0x34, checksum
    uint8_t valid[] = {0xFF, 0x12, 0x34, 0x46};  // checksum = (0xFF+0x12+0x34)&0xFF
    assert(validateFrame(valid) == true);
    
    // Bad checksum
    uint8_t badcs[] = {0xFF, 0x12, 0x34, 0x00};
    assert(validateFrame(badcs) == false);
}
```

#### Test 2: Temporal Filter
```cpp
void test_temporalFilter() {
    resetSensorFilter();
    
    // Add 10 stable readings
    for (int i = 0; i < 10; i++) {
        float result = applyTemporalFilter(100.0f);
        if (i < 9) assert(result < 0);  // Still warming up
    }
    
    // Should now accept readings
    float stable = applyTemporalFilter(100.0f);
    assert(fabs(stable - 100.0f) < 1.0f);
}
```

#### Test 3: Plausibility Check
```cpp
void test_plausibilityCheck() {
    resetSensorFilter();
    
    // Warm up with 100cm readings
    for (int i = 0; i < 10; i++) {
        applyTemporalFilter(100.0f);
    }
    
    // Inject spike (>2cm from mean)
    float spiked = applyTemporalFilter(150.0f);  // 50cm spike
    assert(spiked < 120.0f);  // Should be rejected/smoothed
}
```

### Integration Tests

#### Test 4: Measurement Loop (5 min)
```
Procedure:
1. Power on system
2. Wait for first reading (5s)
3. Verify 60 consecutive readings without errors
4. Check that distance varies < 0.5cm (temporal filter working)
5. Verify WiFi queue fills if disconnected
```

#### Test 5: WiFi Offline Tolerance (30 min)
```
Procedure:
1. Power on, connect to WiFi
2. Disable WiFi (or router)
3. System should:
   - Continue measurements every 5s
   - Queue all readings locally
   - Attempt WiFi reconnect every 50s (no blocking)
4. Re-enable WiFi
5. Verify queue flushes within 2 minutes
6. Verify all readings uploaded (no loss)
```

#### Test 6: Factory Reset
```
Procedure:
1. Power on device
2. Hold reset button for 10+ seconds
3. Verify LED triple-blinks (reset confirmation)
4. Verify configuration reset to defaults
5. Verify WiFi credentials cleared
6. Device requires reconfiguration via BLE
```

---

## 🎯 Implementation Priorities

### Priority 1 (CRITICAL) — This Week
- [ ] Fix config references (cm → mm) in sensorTask
- [ ] Verify calibration system works with new config
- [ ] Add sensorSelfTest to startup
- [ ] Test measurement loop with real sensor (once components arrive)

### Priority 2 (HIGH) — This Week
- [ ] Implement WiFi non-blocking reconnect
- [ ] Add diagnostics API endpoint
- [ ] Add reconnection attempt tracking

### Priority 3 (MEDIUM) — Next Week
- [ ] Memory usage monitoring
- [ ] Queue statistics API
- [ ] Factory reset validation
- [ ] Unit test suite

### Priority 4 (LOW) — After Prototype Testing
- [ ] OTA update capability
- [ ] Advanced logging to SD card
- [ ] Battery voltage monitoring (if power-hungry later)

---

## 📝 Code Organization

```
firmware/tank-sensor/src/
├── main.cpp              ← Task scheduling, setup, loop
├── sensor.h/cpp          ← ✅ SR04M-2 UART interface
├── config.h/cpp          ← Configuration (NVS storage)
├── state.h               ← Global state structure
├── queue_store.h/cpp     ← Offline queue management
├── api_server.h/cpp      ← REST API endpoints (includes diagnostics)
├── ble_server.h/cpp      ← BLE server + notifications
├── pins.h                ← ✅ GPIO pin definitions
└── [test files]          ← Unit tests (optional)
```

---

## 🔍 Known Issues & Workarounds

### Issue 1: Config Schema Mismatch
**Status:** TODO  
**Description:** Old code references tank_empty_cm/tank_full_cm, schema now uses mm  
**Fix:** Update all references in sensorTask to use *_mm variants and divide by 10 when needed for cm display

### Issue 2: WiFi Blocking on Slow Networks
**Status:** TODO  
**Description:** wifiConnect() can block for up to 15 seconds on unavailable networks  
**Fix:** Implement non-blocking WiFi with separate 50s retry timer

### Issue 3: No Diagnostics Endpoint
**Status:** TODO  
**Description:** sensorSelfTest() runs on startup, but no way to call it again after failure  
**Fix:** Add REST endpoint: GET /api/sensor/test

---

## 📚 Related Documentation

- [PHASE_1B_IMPLEMENTATION_PLAN.md](../architecture/PHASE_1B_IMPLEMENTATION_PLAN.md) §3.3 — Main loop integration details
- [HARDWARE_REV_G.md](HARDWARE_REV_G.md) — Configuration schema
- [state.h](../firmware/tank-sensor/src/state.h) — Global state structure
- [config.h](../firmware/tank-sensor/src/config.h) — Configuration system

---

## ✅ Sign-Off Checklist

Before declaring firmware Phase 1B complete:

- [ ] All sensor references updated to SR04M-2 UART
- [ ] sensorSelfTest runs on boot
- [ ] Measurement loop stable (no crashes)
- [ ] WiFi reconnect non-blocking (no measurement delay during outages)
- [ ] Queue fills and flushes correctly (offline tolerance verified)
- [ ] Diagnostics API available (sensor stats, WiFi stats, memory)
- [ ] Factory reset working (clear config, LED feedback)
- [ ] All compiler warnings resolved
- [ ] Code compiles without errors on latest Arduino/ESP-IDF

---

## 🚀 Next Phases

**Phase 1C (1-2 weeks):** Prototype build & hardware bringup
- Assemble PCB (when arrives from fab)
- Flash firmware to XIAO
- Bench test with real SR04M-2 sensor
- Validate calibration system

**Phase 1D (1 week):** Field deployment testing
- Install on urban roof
- Monitor for 72+ hours
- Test offline tolerance (unplug WiFi for 2+ days)
- Verify data integrity and completeness

**Phase 1E (1 week):** Production readiness
- Add ESD protection (PESD diodes)
- Optional: Add external watchdog (TPL5010)
- Generate final documentation
- Release as "Phase 1 Complete"

---

**Status:** Ready for implementation  
**Owner:** yugeshmluv  
**Last Updated:** 2026-06-07
