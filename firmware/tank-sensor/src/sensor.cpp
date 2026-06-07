#include "sensor.h"
#include "pins.h"
#include <Arduino.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>
#include <math.h>
#include <cstring>
#include <algorithm>

// ─── SR04M-2 UART Configuration ──────────────────────────────────────────
// Sensor communicates via UART: send 0x55 → receive 4-byte frame
// Frame: [0xFF] [DataH] [DataL] [Checksum]
// Checksum: (0xFF + DataH + DataL) & 0xFF
// Distance: (DataH << 8) | DataL (in mm)

static HardwareSerial& sensorSerial = Serial1;
static bool sensorInitialized = false;

// ─── Temporal Filter Parameters ──────────────────────────────────────────
#define HISTORY_SIZE    10
static float distanceHistory[HISTORY_SIZE] = {};
static size_t historyIndex = 0;

// ─── Sensor Diagnostics ─────────────────────────────────────────────────
static struct {
    uint32_t lastReadMs;       // Timestamp of last successful read
    uint32_t readCount;        // Total successful reads
    uint32_t frameErrorCount;  // CRC/frame validation errors
    uint32_t timeoutCount;     // UART reception timeouts
    float lastRawDist;         // Last raw distance before filtering
    float lastFilteredDist;    // Last filtered distance
} gDiag = {};

// ─── Internal Helpers ────────────────────────────────────────────────────

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
    if (frame[0] != 0xFF) return false;

    uint8_t computed = (0xFF + frame[1] + frame[2]) & 0xFF;
    if (computed != frame[3]) return false;

    uint16_t distMm = (frame[1] << 8) | frame[2];
    if (distMm < 200 || distMm > 6000) return false;

    return true;
}

static float readRawDistanceCM() {
    if (!sensorInitialized) {
        Serial.println("[Sensor] ERROR: Sensor not initialized. Call sensorInit() first.");
        return -1.0f;
    }

    // Flush stale data
    while (sensorSerial.available()) sensorSerial.read();

    // Send trigger command
    uint8_t cmd = 0x55;
    sensorSerial.write(cmd);
    sensorSerial.flush();

    // Receive 4-byte response with 120ms timeout
    uint8_t frame[4] = {0};
    if (!receiveFrame(frame, 4, 120)) {
        gDiag.timeoutCount++;
        Serial.printf("[Sensor] TIMEOUT: No response within 120ms\n");
        return -1.0f;
    }

    // Validate frame structure and checksum
    if (!validateFrame(frame)) {
        gDiag.frameErrorCount++;
        Serial.printf("[Sensor] FRAME_ERROR: Invalid frame [0x%02X 0x%02X 0x%02X 0x%02X]\n",
                      frame[0], frame[1], frame[2], frame[3]);
        return -1.0f;
    }

    uint16_t distMm = (frame[1] << 8) | frame[2];
    float distCm = distMm / 10.0f;

    gDiag.lastRawDist = distCm;
    gDiag.readCount++;
    gDiag.lastReadMs = millis();

    Serial.printf("[Sensor] Raw: [0x%02X 0x%02X 0x%02X 0x%02X] → %u mm → %.1f cm\n",
                  frame[0], frame[1], frame[2], frame[3], distMm, distCm);

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

    // Sum middle 8 values (remove top and bottom)
    float sum = 0;
    for (size_t i = 1; i < HISTORY_SIZE - 1; i++) {
        sum += values[i];
    }
    float mean = sum / (HISTORY_SIZE - 2);

    // Plausibility check: reject if raw differs from mean by >2cm
    if (fabs(rawDist - mean) > 20.0f) {
        Serial.printf("[Filter] PLAUSIBLE_REJECT: raw=%.1f cm, mean=%.1f cm (>2cm threshold)\n",
                      rawDist, mean);
        gDiag.lastFilteredDist = mean;
        return mean;  // Return filtered value, not raw spike
    }

    float filtered = (rawDist + mean) / 2.0f;
    gDiag.lastFilteredDist = filtered;
    return filtered;
}

// ─── Public API ──────────────────────────────────────────────────────────

void sensorInit() {
    sensorSerial.begin(UART_BAUD, SERIAL_8N1, PIN_SENSOR_RX, PIN_SENSOR_TX);
    sensorInitialized = true;
    Serial.printf("[Sensor] SR04M-2 UART initialized: TX=GPIO%d, RX=GPIO%d, Baud=%d\n",
                  PIN_SENSOR_TX, PIN_SENSOR_RX, UART_BAUD);
}

float readDistanceCM() {
    float raw = readRawDistanceCM();
    return applyTemporalFilter(raw);
}

void resetSensorFilter() {
    memset(distanceHistory, 0, sizeof(distanceHistory));
    historyIndex = 0;
    Serial.println("[Sensor] Filter state reset");
}

float computeLevelPct(float distCM, float emptyDist, float fullDist) {
    if (distCM < 0) return -1.0f;

    float range = emptyDist - fullDist;
    if (range <= 0) return -1.0f;

    float level = (emptyDist - distCM) / range * 100.0f;
    return constrain(level, 0.0f, 100.0f);
}

SensorDiag getSensorDiagnostics() {
    SensorDiag d;
    d.lastReadMs = gDiag.lastReadMs;
    d.readCount = gDiag.readCount;
    d.frameErrorCount = gDiag.frameErrorCount;
    d.timeoutCount = gDiag.timeoutCount;
    d.lastRawDist = gDiag.lastRawDist;
    d.lastFilteredDist = gDiag.lastFilteredDist;
    return d;
}

void resetSensorDiagnostics() {
    gDiag = {};
}

bool sensorSelfTest() {
    Serial.println("[Sensor] Running self-test (3 attempts)...");

    if (!sensorInitialized) {
        Serial.println("[Sensor] ERROR: Sensor not initialized. Call sensorInit() first.");
        return false;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
        float dist = readRawDistanceCM();
        if (dist > 0) {
            Serial.printf("[Sensor] Self-test PASS (attempt %d): %.1f cm\n", attempt + 1, dist);
            return true;
        }
        delay(200);
    }

    Serial.println("[Sensor] Self-test FAIL (all 3 attempts failed)");
    return false;
}

uint8_t resolvePin(const String& name) {
    if (name == "D0")  return 0;
    if (name == "D1")  return 1;
    if (name == "D2")  return 2;
    if (name == "D3")  return 21;
    if (name == "D4")  return 22;
    if (name == "D5")  return 23;
    if (name == "D6")  return 16;
    if (name == "D7")  return 17;
    if (name == "D8")  return 19;
    if (name == "D9")  return 20;
    if (name == "D10") return 18;
    return 255;
}

void handlePinCommand(const char* json, char* resultBuf, size_t bufLen) {
    JsonDocument doc;
    if (deserializeJson(doc, json) != DeserializationError::Ok) {
        snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"invalid_json\"}");
        return;
    }

    const char* cmd = doc["cmd"] | "";

    if (strcmp(cmd, "sensor_test") == 0) {
        if (sensorSelfTest()) {
            snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"detail\":\"sensor_responds\"}");
        } else {
            snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"sensor_no_response\"}");
        }
    } else if (strcmp(cmd, "get_diagnostics") == 0) {
        SensorDiag d = getSensorDiagnostics();
        snprintf(resultBuf, bufLen,
                 "{\"result\":\"ok\",\"reads\":%lu,\"errors\":%lu,\"timeouts\":%lu,"
                 "\"last_raw\":%.1f,\"last_filtered\":%.1f}",
                 d.readCount, d.frameErrorCount, d.timeoutCount, d.lastRawDist, d.lastFilteredDist);
    } else {
        snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"unknown_cmd\"}");
    }
}
