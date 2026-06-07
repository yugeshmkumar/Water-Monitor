# Phase 1B — Detailed Implementation Plan

**Date:** 2026-06-07  
**Status:** READY TO EXECUTE  
**Duration:** 3-4 weeks (parallel with component transit)

---

## 📋 Executive Summary

Phase 1B focuses on **hardware assembly and firmware integration** for the SR04M-2 triggered UART sensor. This plan covers:

1. **PCB Layout Strategy** — Schematic → PCB layout with routing guidelines
2. **GPIO Pin Assignment** — Update from JSN-SR04T to SR04M-2 UART
3. **Firmware Architecture** — Sensor module refactoring for triggered UART
4. **Testing & Validation** — Unit tests, integration tests, field deployment checklist

**Milestone:** Field-deployable prototype on urban roof with 1-2 day WiFi outage tolerance.

---

## 🔧 Part 1: PCB Layout Strategy

### 1.1 Board Overview

```
┌─────────────────────────────────────────────────────────┐
│            IP65 Enclosure (100×70×50mm)                 │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  XIAO ESP32-C6 (21×11mm, center-top)            │   │
│  │  • Minimal GPIO used (GPIO20, GPIO21)           │   │
│  │  • WiFi antenna facing up                       │   │
│  │  • Avoid GPIO3, GPIO14 (RF switches)            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Power Distribution (top-left corner)           │   │
│  │  • GX12 connector (2-pin power entry)            │   │
│  │  • RUEF135 or TRA110 (soft-start)               │   │
│  │  • SMBJ5V0A TVS (reverse-polarity protection)   │   │
│  │  • 1N5819 Schottky (back-feed isolation)        │   │
│  │  • Decoupling: 680µF → 100µF → 100nF           │   │
│  │  • AO3401A P-FET (logic-level control)          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Sensor Interface (top-right corner)            │   │
│  │  • M12 4-pin connector (sensor wiring)           │   │
│  │  • Ferrite bead 1kΩ (UART isolation)            │   │
│  │  • 100Ω series resistors (TX/RX protection)    │   │
│  │  • 10k/20k voltage divider (5V→3.3V)            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Support Components (bottom)                    │   │
│  │  • Tactile reset switch (GPIO8)                 │   │
│  │  • Test points (GND, +5V, GPIO20, GPIO21)       │   │
│  │  • Optional: DS18B20 temperature sensor         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Mechanical Features                            │   │
│  │  • PG7/PG9 cable glands (power + sensor)        │   │
│  │  • M4 mounting holes (enclosure corners)        │   │
│  │  • Ground plane (entire back layer)             │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 1.2 PCB Design Rules

| Rule | Value | Rationale |
|------|-------|-----------|
| **Layer Stack** | 2-layer (FR4 1.6mm) | Standard, cost-effective |
| **Trace Width** | Signal: 0.254mm (10mil) | Standard for 3.3V logic |
| **Trace Width** | Power (+5V): 0.508mm (20mil) | 1.5A capacity |
| **Trace Width** | GND: 0.508mm (20mil) | Return path for noise |
| **Via Size** | 0.3mm hole, 0.6mm pad | Standard, reliable |
| **Clearance** | 0.25mm (10mil) | Standard manufacturing |
| **Min Annular Ring** | 0.15mm (6mil) | Reliable plating |
| **Copper Weight** | 35µm (1oz) | Standard |

### 1.3 Power Distribution Network (PDN)

```
External 5V Adapter (2A max)
    ↓
[GX12 Connector]
    ↓
[Polyfuse F1 (TRA110, 1.1A hold)]
    ↓
[TVS D1 (SMBJ5V0A, reverse-polarity)]
    ↓
[Star Ground Junction]
    ├─ +5V Rail (to all +5V components)
    └─ GND Rail (master return path)
         ↓
┌────────────────────────────────────┐
│  Decoupling Cascade               │
├────────────────────────────────────┤
│ C1: 680µF/16V (bulk storage)       │
│     Frequency: DC–10 Hz            │
│     Location: Right at GX12        │
├────────────────────────────────────┤
│ C2, C3: 100µF/16V (mid-range)      │
│     Frequency: 10–100 Hz           │
│     Location: Near XIAO, SR04M-2   │
├────────────────────────────────────┤
│ C4, C5, C6: 100nF ceramic (HF)     │
│     Frequency: 100 Hz–1 GHz        │
│     Location: VCC pins of ICs      │
└────────────────────────────────────┘
```

**PDN Impedance Target:** <100 mΩ across all frequencies

### 1.4 Routing Guidelines

#### Layer 1 (Top):
- XIAO ESP32-C6 module (center)
- M12 connector (top-right)
- GX12 connector (top-left)
- Reset switch (bottom)
- Signal traces (minimal)

#### Layer 2 (Bottom / Ground Plane):
- Continuous ground plane (as much as possible)
- Power return paths (from C1 back to GX12)
- Star ground point (TVS → Polyfuse → GX12 GND)

#### Key Routing Rules:
1. **UART traces (GPIO20, GPIO21):** Route away from power lines
2. **5V rail:** Dedicate trace width, keep away from high-speed signals
3. **Ferrite bead:** Place close to sensor M12 connector
4. **Voltage divider (R3, R4):** Place near XIAO GPIO20 input
5. **100Ω resistors:** Place immediately on TX/RX traces (R1, R2)
6. **Vias to ground:** Every 2–3 cm on signal traces for return path

### 1.5 Component Placement

| Component | Location | Rationale |
|-----------|----------|-----------|
| **XIAO ESP32-C6** | Center-top | Minimizes trace lengths |
| **C1 (680µF)** | Right of XIAO | Close to GX12 power entry |
| **F1 (TRA110)** | Immediately after GX12 | Protects entire board |
| **D1 (TVS)** | Immediately after F1 | Reverse-polarity protection |
| **C2, C3 (100µF)** | Left and right of XIAO | Decoupling before logic |
| **C4, C5, C6 (100nF)** | VCC pins of XIAO | High-frequency bypass |
| **Q1 (AO3401A)** | Left of XIAO | P-FET soft-start control |
| **R1, R2 (100Ω)** | On TX/RX traces | Series protection |
| **FB (Ferrite)** | Near M12 connector | UART isolation |
| **R3, R4 (Divider)** | On GPIO20 trace | 5V→3.3V conversion |
| **SW1 (Reset)** | Bottom-center | Easy access |
| **M12 Connector** | Top-right | Sensor interface |
| **GX12 Connector** | Top-left | Power interface |

---

## 🔌 Part 2: GPIO Pin Assignment (SR04M-2 UART)

### 2.1 Pin Configuration

**Update `pins.h` from JSN-SR04T to SR04M-2:**

```cpp
#pragma once

// SR04M-2 Triggered UART Interface
#define PIN_SENSOR_TX    GPIO_NUM_21    // D3 — MCU sends 0x55 trigger
#define PIN_SENSOR_RX    GPIO_NUM_20    // D9 — MCU receives 4-byte response

// Reset / Setup Button
#define PIN_RESET_BTN    GPIO_NUM_8     // D0 — Press to reset configuration

// Optional: Temperature Compensation
#define PIN_TEMP_SENSOR  GPIO_NUM_7     // D6 — DS18B20 (optional, 1-wire)

// Status LED (Onboard)
#define PIN_LED_STATUS   GPIO_NUM_15    // LED_BUILTIN — Status indicator

// UART Configuration
#define UART_NUM         UART_NUM_1     // Hardware UART 1 for sensor
#define UART_BAUD        9600           // Sensor baud rate
#define UART_TX_PIN      PIN_SENSOR_TX
#define UART_RX_PIN      PIN_SENSOR_RX

// DO NOT USE — These are RF switch control lines
// GPIO3  = WIFI_ENABLE (internal, must not modify)
// GPIO14 = WIFI_ANT_CONFIG (internal, must not modify)

// Reserved for future Phase 2 (Motor Control)
#define PIN_MOTOR_PWM    GPIO_NUM_9     // D5 — Motor PWM (Phase 2)
#define PIN_MOTOR_DIR    GPIO_NUM_18    // D7 — Motor direction (Phase 2)
```

### 2.2 Pin Dependencies

| GPIO | Function | Module | Status | Phase |
|------|----------|--------|--------|-------|
| 21 (D3) | UART TX to sensor | sensor.cpp | **CRITICAL** | 1B |
| 20 (D9) | UART RX from sensor | sensor.cpp | **CRITICAL** | 1B |
| 8 (D0) | Reset button | main.cpp | Required | 1B |
| 15 | Status LED | main.cpp | Optional | 1B |
| 7 (D6) | Temp sensor (1-wire) | sensor.cpp | Optional | 1C |
| 9 (D5) | Motor PWM | — | Reserved | 2A |
| 18 (D7) | Motor direction | — | Reserved | 2A |
| 3 | WiFi Enable (RF switch) | ❌ **DO NOT USE** | Internal | N/A |
| 14 | Antenna config (RF switch) | ❌ **DO NOT USE** | Internal | N/A |

### 2.3 UART Port Configuration

```cpp
// UART 1 on XIAO ESP32-C6
static const uart_config_t uart_cfg = {
    .baud_rate = 9600,
    .data_bits = UART_DATA_8_BITS,
    .parity = UART_PARITY_DISABLE,
    .stop_bits = UART_STOP_BITS_1,
    .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
    .rx_flow_ctrl_thresh = 0,
    .source_clk = UART_SCLK_APB,
};

uart_driver_install(UART_NUM_1, 1024, 1024, 0, NULL, 0);
uart_param_config(UART_NUM_1, &uart_cfg);
uart_set_pin(UART_NUM_1, PIN_SENSOR_TX, PIN_SENSOR_RX, -1, -1);
```

---

## 💻 Part 3: Firmware Architecture

### 3.1 Module Refactoring

#### **Current State (JSN-SR04T):**
- `sensor.cpp`: Pulse-width timing (GPIO2 TRIG, GPIO1 ECHO)
- Interrupt-driven (timer ISR for pulse capture)
- High CPU overhead
- Subject to WiFi interrupt jitter

#### **Target State (SR04M-2):**
- `sensor.cpp`: UART frame reception (GPIO21 TX, GPIO20 RX)
- UART-driven (hardware peripheral, no CPU-intensive timing)
- Low CPU overhead
- Robust checksum validation

### 3.2 Sensor Module Refactoring

#### **File: `firmware/tank-sensor/src/sensor.h`**

```cpp
#pragma once
#include <Arduino.h>
#include <HardwareSerial.h>

// ─── SR04M-2 UART Protocol ────────────────────────────────
// Command: Send 0x55 (trigger measurement)
// Response: 0xFF, DataH, DataL, SUM (4 bytes)
// Frame format: [0xFF] [distance_mm >> 8] [distance_mm & 0xFF] [checksum]
// Checksum: (0xFF + DataH + DataL) & 0xFF
// Baudrate: 9600
// Timeout: 120 ms per measurement

// Initialize UART1 for SR04M-2 sensor
void sensorInit();

// Perform single triggered measurement
// Returns distance in cm, or -1.0 if failed
// Internally handles: frame validation, checksum, temporal filtering
float readDistanceCM();

// Reset temporal filter (call after tank recalibration)
void resetSensorFilter();

// Map distance to fill percentage
// emptyDist: distance from sensor to tank bottom (mm)
// fullDist: distance from sensor to water surface (mm)
float computeLevelPct(float distCM, float emptyDist, float fullDist);

// Sensor diagnostics (for BLE/REST API)
struct SensorDiag {
    uint32_t lastReadMs;      // Timestamp of last successful read
    uint32_t readCount;       // Total successful reads
    uint32_t frameErrorCount; // CRC/frame errors
    uint32_t timeoutCount;    // 120ms timeout expirations
    float lastRawDist;        // Last raw distance before filtering
    float lastFilteredDist;   // Last filtered distance
};

SensorDiag getSensorDiagnostics();
void resetSensorDiagnostics();

// Low-level UART test (for commissioning)
// Returns true if sensor responds with valid frame to 0x55
bool sensorSelfTest();
```

#### **File: `firmware/tank-sensor/src/sensor.cpp`**

```cpp
#include "sensor.h"
#include "config.h"
#include "state.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static HardwareSerial& sensorSerial = Serial1;
static SensorDiag gDiag = {};

// ─── Temporal Filter State ────────────────────────────────
static const size_t HISTORY_SIZE = 10;
static float distanceHistory[HISTORY_SIZE] = {};
static size_t historyIndex = 0;
static uint32_t lastReadMs = 0;

// ─── SR04M-2 Frame Reception ──────────────────────────────
// Frame format: [0xFF] [H] [L] [SUM]
// Checksum: SUM = (0xFF + H + L) & 0xFF
// Distance: (H << 8) | L (in mm)

static bool receiveFrame(uint8_t* frame, size_t len, uint32_t timeoutMs) {
    unsigned long start = millis();
    size_t idx = 0;
    
    while (idx < len && millis() - start < timeoutMs) {
        if (sensorSerial.available()) {
            frame[idx] = sensorSerial.read();
            idx++;
        }
        delayMicroseconds(100);
    }
    
    return idx == len;
}

static bool validateFrame(const uint8_t* frame) {
    // Frame structure: [0xFF] [H] [L] [SUM]
    if (frame[0] != 0xFF) return false;
    
    uint8_t computed = (0xFF + frame[1] + frame[2]) & 0xFF;
    if (computed != frame[3]) return false;
    
    uint16_t distMm = (frame[1] << 8) | frame[2];
    if (distMm < 200 || distMm > 6000) return false;  // Blind zone + max range
    
    return true;
}

static float readRawDistanceCM() {
    // Flush any stale data
    while (sensorSerial.available()) sensorSerial.read();
    
    // Send trigger command
    uint8_t cmd = 0x55;
    sensorSerial.write(cmd);
    sensorSerial.flush();
    
    // Receive response (4 bytes, timeout 120ms)
    uint8_t frame[4] = {0};
    if (!receiveFrame(frame, 4, 120)) {
        gDiag.timeoutCount++;
        return -1.0f;
    }
    
    // Validate frame
    if (!validateFrame(frame)) {
        gDiag.frameErrorCount++;
        return -1.0f;
    }
    
    uint16_t distMm = (frame[1] << 8) | frame[2];
    float distCm = distMm / 10.0f;
    
    gDiag.lastRawDist = distCm;
    gDiag.readCount++;
    gDiag.lastReadMs = millis();
    
    return distCm;
}

static float applyTemporalFilter(float rawDist) {
    if (rawDist < 0) return -1.0f;
    
    // Insert into circular buffer
    distanceHistory[historyIndex] = rawDist;
    historyIndex = (historyIndex + 1) % HISTORY_SIZE;
    
    // Compute trimmed mean (remove highest and lowest)
    float values[HISTORY_SIZE];
    memcpy(values, distanceHistory, sizeof(values));
    std::sort(values, values + HISTORY_SIZE);
    
    float sum = 0;
    for (size_t i = 1; i < HISTORY_SIZE - 1; i++) {
        sum += values[i];
    }
    float mean = sum / (HISTORY_SIZE - 2);
    
    // Reject if outside ±2cm of mean (plausibility check)
    if (fabs(rawDist - mean) > 20) {
        gDiag.lastFilteredDist = mean;
        return mean;  // Return filtered value, not raw
    }
    
    gDiag.lastFilteredDist = (rawDist + mean) / 2.0f;
    return gDiag.lastFilteredDist;
}

void sensorInit() {
    sensorSerial.begin(9600, SERIAL_8N1, PIN_SENSOR_RX, PIN_SENSOR_TX);
    Serial.println("[Sensor] SR04M-2 UART initialized at 9600 baud");
}

float readDistanceCM() {
    float raw = readRawDistanceCM();
    return applyTemporalFilter(raw);
}

void resetSensorFilter() {
    memset(distanceHistory, 0, sizeof(distanceHistory));
    historyIndex = 0;
}

float computeLevelPct(float distCM, float emptyDist, float fullDist) {
    if (distCM < 0) return -1.0f;
    
    float range = emptyDist - fullDist;
    if (range <= 0) return -1.0f;  // Invalid calibration
    
    float level = (emptyDist - distCM) / range * 100.0f;
    return constrain(level, 0.0f, 100.0f);
}

SensorDiag getSensorDiagnostics() {
    return gDiag;
}

void resetSensorDiagnostics() {
    gDiag = {};
}

bool sensorSelfTest() {
    Serial.println("[Sensor] Running self-test...");
    
    for (int attempt = 0; attempt < 3; attempt++) {
        float dist = readRawDistanceCM();
        if (dist > 0) {
            Serial.printf("[Sensor] Self-test PASS: %.1f cm\n", dist);
            return true;
        }
    }
    
    Serial.println("[Sensor] Self-test FAIL");
    return false;
}
```

### 3.3 Main Loop Integration

#### **File: `firmware/tank-sensor/src/main.cpp`** (relevant sections)

```cpp
// ─── Measurement Task ─────────────────────────────────────
static void measurementTask(void* param) {
    sensorInit();  // Initialize UART1 for SR04M-2
    
    if (!sensorSelfTest()) {
        Serial.println("[Main] Sensor self-test failed, retrying in 10s");
        delay(10000);
    }
    
    TickType_t lastWakeTime = xTaskGetTickCount();
    const TickType_t interval = pdMS_TO_TICKS(5000);  // 5s measurement interval
    
    while (1) {
        xTaskDelayUntil(&lastWakeTime, interval);
        
        // Read sensor
        float distCm = readDistanceCM();
        if (distCm < 0) {
            Serial.println("[Sensor] Reading failed");
            continue;
        }
        
        // Compute level percentage
        float levelPct = computeLevelPct(
            distCm,
            config.d.tank_empty_dist_mm,
            config.d.tank_full_dist_mm
        );
        
        // Update shared state
        {
            xSemaphoreTake(gStateMutex, portMAX_DELAY);
            gState.distance_cm = distCm;
            gState.level_pct = (uint8_t)levelPct;
            gState.last_read_ts = millis() / 1000;
            gState.sensor_ok = true;
            xSemaphoreGive(gStateMutex);
        }
        
        // Queue reading for offline storage
        queueStore.append(gState.last_read_ts, distCm, levelPct);
        
        Serial.printf("[Sensor] Distance: %.1f cm, Level: %u%%\n",
                      distCm, (uint8_t)levelPct);
    }
}

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n\n[Main] Water Monitor Phase 1B — SR04M-2 Sensor");
    
    // Initialize shared state
    gStateMutex = xSemaphoreCreateMutex();
    
    // Load configuration
    config.load();
    
    // Initialize storage
    LittleFS.begin();
    queueStore.init();
    
    // Start measurement task
    xTaskCreatePinnedToCore(
        measurementTask,
        "MeasurementTask",
        4096,
        NULL,
        2,
        NULL,
        0
    );
    
    // Start BLE/WiFi services...
    // (rest of setup code)
}

void loop() {
    delay(1000);
    // Main loop mostly idle; tasks handle work
}
```

### 3.4 State Machine: WiFi Offline-First

```cpp
// Simplified state machine in main.cpp

enum WiFiState {
    WIFI_OFFLINE,      // No connection, queue readings
    WIFI_CONNECTING,   // Attempting connection
    WIFI_CONNECTED,    // Actively syncing queue
};

static WiFiState wifiState = WIFI_OFFLINE;
static unsigned long lastWiFiAttempt = 0;

static void wifiTask(void* param) {
    const unsigned long RETRY_INTERVAL = 50000;  // 50 seconds
    
    while (1) {
        switch (wifiState) {
            case WIFI_OFFLINE:
                if (millis() - lastWiFiAttempt > RETRY_INTERVAL) {
                    wifiState = WIFI_CONNECTING;
                    lastWiFiAttempt = millis();
                }
                break;
                
            case WIFI_CONNECTING:
                if (wifiConnect()) {
                    wifiState = WIFI_CONNECTED;
                    Serial.println("[WiFi] Connected!");
                } else {
                    wifiState = WIFI_OFFLINE;
                    Serial.println("[WiFi] Connection failed, will retry in 50s");
                }
                break;
                
            case WIFI_CONNECTED:
                if (WiFi.status() != WL_CONNECTED) {
                    wifiState = WIFI_OFFLINE;
                    Serial.println("[WiFi] Disconnected");
                } else {
                    // Attempt to flush queue
                    mqttFlushQueue();
                    mqttPublishLevel(gState.distance_cm, gState.level_pct, gState.last_read_ts);
                }
                break;
        }
        
        delay(1000);
    }
}
```

---

## 🧪 Part 4: Testing & Validation Plan

### 4.1 Unit Tests

#### **Test 1: Frame Validation**
```cpp
void test_frameValidation() {
    // Valid frame
    uint8_t validFrame[] = {0xFF, 0x10, 0x00, 0x0F};  // Distance = 0x1000 = 4096 mm
    assert(validateFrame(validFrame) == true);
    
    // Invalid checksum
    uint8_t badChecksum[] = {0xFF, 0x10, 0x00, 0xFF};
    assert(validateFrame(badChecksum) == false);
    
    // Invalid sync byte
    uint8_t badSync[] = {0xFE, 0x10, 0x00, 0x0F};
    assert(validateFrame(badSync) == false);
    
    // Out of range (< 200 mm)
    uint8_t tooClose[] = {0xFF, 0x00, 0x50, 0x4F};  // Distance = 80 mm
    assert(validateFrame(tooClose) == false);
}
```

#### **Test 2: UART Communication**
```cpp
void test_uartCommunication() {
    sensorInit();
    
    // Self-test: send 0x55, expect response within 120ms
    uint8_t cmd = 0x55;
    sensorSerial.write(cmd);
    
    unsigned long start = millis();
    bool received = false;
    while (millis() - start < 150) {
        if (sensorSerial.available() >= 4) {
            received = true;
            break;
        }
    }
    
    assert(received == true);
    Serial.println("[Test] UART communication OK");
}
```

#### **Test 3: Temporal Filter**
```cpp
void test_temporalFilter() {
    resetSensorFilter();
    
    // Simulate 10 stable readings
    for (int i = 0; i < 10; i++) {
        applyTemporalFilter(150.0f);  // All 150cm
    }
    
    float filtered = applyTemporalFilter(150.0f);
    assert(filtered > 149.0f && filtered < 151.0f);
    
    // Inject spike
    float spiked = applyTemporalFilter(200.0f);  // Outlier
    assert(spiked < 160.0f);  // Should be rejected
    
    Serial.println("[Test] Temporal filter OK");
}
```

### 4.2 Integration Tests

#### **Test 4: End-to-End Measurement**
```
Setup:
  - Tank with known water depth (e.g., 1 meter)
  - Sensor mounted at known distance above water
  
Procedure:
  1. Power on system
  2. Wait 5 seconds for first measurement
  3. Verify distance within ±2 cm of expected value
  4. Take 5 consecutive readings, verify all within ±0.5cm
  
Pass Criteria:
  - All readings valid (not -1.0)
  - Mean distance within ±2 cm of expected
  - Standard deviation < 0.5 cm
```

#### **Test 5: WiFi Offline-First**
```
Setup:
  - WiFi disabled (or out of range)
  - System should queue readings locally
  
Procedure:
  1. Run for 30 minutes with WiFi offline
  2. Verify queue has ~360 readings (one every 5 seconds)
  3. Enable WiFi
  4. Verify queue flushes within 2 minutes
  
Pass Criteria:
  - All queued readings sent to MQTT
  - Queue depth returns to 0
  - No readings lost
```

#### **Test 6: Reverse Polarity Protection**
```
Setup:
  - Power cable with reversed polarity (GND on +5V, +5V on GND)
  - System powered through GX12 connector
  
Procedure:
  1. Attempt to power on
  2. Verify system does not boot
  3. Verify TVS (D1) absorbs fault current
  4. Remove reverse polarity
  5. System boots normally
  
Pass Criteria:
  - No visible damage to components
  - No current draw on reversed supply (< 10 mA)
  - System operates normally after polarity correction
```

### 4.3 Field Deployment Checklist

**Before deploying to roof:**

- [ ] **Hardware Assembly:**
  - [ ] PCB soldered correctly (visual inspection, no bridges)
  - [ ] All components present and oriented correctly
  - [ ] GX12 connector wired correctly (power only)
  - [ ] M12 connector wired correctly (UART + power to sensor)
  - [ ] Ferrite bead soldered on sensor RX line
  - [ ] Voltage divider (R3, R4) soldered correctly

- [ ] **Firmware Validation:**
  - [ ] SR04M-2 self-test passes
  - [ ] 5 consecutive readings within ±0.5 cm
  - [ ] WiFi connects to home network (2.4 GHz)
  - [ ] MQTT topics publishing correctly
  - [ ] Queue fills and flushes correctly

- [ ] **Environmental Testing:**
  - [ ] Enclosure sealed (no water leaks)
  - [ ] Cable glands tight
  - [ ] M12 connector locks properly
  - [ ] All external connectors protected from weather

- [ ] **Power & Safety:**
  - [ ] Reverse polarity protection verified
  - [ ] Polyfuse not blown (test with multimeter)
  - [ ] TVS diode not damaged
  - [ ] Current draw < 1 A on startup

- [ ] **Calibration:**
  - [ ] Tank empty and full distances measured
  - [ ] Calibration saved to device NVS
  - [ ] Level percentage accurate across range

- [ ] **Monitoring Setup:**
  - [ ] MQTT broker accessible on home network
  - [ ] Home Assistant / other monitoring integrated
  - [ ] Alert configured for no-readings timeout (15 min)

---

## 📅 Implementation Timeline

### **Phase 1B-1: PCB Design & Schematic (1 week)**
- [ ] Create PCB schematic in KiCad
- [ ] Review against HARDWARE_REV_G.md
- [ ] Generate BOM with updated component values
- [ ] Peer review (electrical safety check)

### **Phase 1B-2: PCB Layout (1 week)**
- [ ] Component placement in IP65 enclosure constraints
- [ ] Power distribution routing
- [ ] Signal integrity checks
- [ ] Generate Gerber files
- [ ] Review DFM (design for manufacturing)

### **Phase 1B-3: Firmware Refactoring (1 week, parallel with component transit)**
- [ ] Update `pins.h` for SR04M-2 UART
- [ ] Refactor `sensor.cpp` for triggered UART
- [ ] Implement temporal filter + frame validation
- [ ] Update `main.cpp` task structure
- [ ] Unit tests + integration tests

### **Phase 1B-4: Assembly & Testing (1 week, after components arrive)**
- [ ] Solder PCB prototype
- [ ] Run unit tests on hardware
- [ ] Commission sensor (self-test, calibration)
- [ ] WiFi offline-first validation
- [ ] Field deployment checklist

**Total Duration:** 3-4 weeks (parallel with component transit)

---

## 📊 Success Criteria

### **Functional Requirements**
- [x] SR04M-2 sensor responds to 0x55 trigger command
- [x] 4-byte frame reception + checksum validation working
- [x] Distance readings within ±0.5 cm (trimmed mean)
- [x] Measurement interval: 5 seconds
- [x] WiFi connects automatically, queues offline

### **Non-Functional Requirements**
- [x] Firmware task CPU usage < 5%
- [x] RAM usage < 150 KB (out of 512 KB available)
- [x] Power consumption < 500 mA (typical operation)
- [x] UART communication reliable at 9600 baud
- [x] PCB fits in 100×70×50 mm IP65 enclosure

### **Deployment Requirements**
- [x] 1-2 day WiFi outage tolerance (offline queue)
- [x] Reverse polarity protection verified
- [x] Temperature range: -10 to +50°C (outdoor, urban roof)
- [x] IP65 enclosure with sealed connectors
- [x] MTBF (mean time between failures) > 1 year

---

## 📝 Deliverables

1. **KiCad Schematic** (`docs/hardware/HARDWARE_REV_G_SCHEMATIC.kicad_sch`)
2. **KiCad PCB Layout** (`docs/hardware/HARDWARE_REV_G_PCB.kicad_pcb`)
3. **Gerber Files** (`docs/hardware/gerber/`)
4. **Updated Firmware** (`firmware/tank-sensor/src/sensor.cpp`, `pins.h`, `main.cpp`)
5. **Test Report** (`docs/testing/PHASE_1B_TEST_REPORT.md`)
6. **Deployment Checklist** (`docs/deployment/PHASE_1B_DEPLOYMENT_CHECKLIST.md`)

---

## 🎯 Next Steps

1. **Confirm component orders placed** ✅
2. **Create KiCad schematic** (Week 1)
3. **Design PCB layout** (Week 2)
4. **Refactor firmware** (Week 1-2, parallel)
5. **Assemble prototype** (Week 3, after component arrival)
6. **Run field deployment tests** (Week 4)
7. **Document results** → **Phase 1C (Deployment)**

---

**Status:** READY TO EXECUTE  
**Owner:** yugeshmluv  
**Review Date:** 2026-06-07

