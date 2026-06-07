#pragma once
#include <Arduino.h>

// SR04M-2 triggered UART sensor diagnostics
struct SensorDiag {
    uint32_t lastReadMs;       // Timestamp of last successful read
    uint32_t readCount;        // Total successful reads
    uint32_t frameErrorCount;  // CRC/frame validation errors
    uint32_t timeoutCount;     // UART reception timeouts
    float lastRawDist;         // Last raw distance before filtering
    float lastFilteredDist;    // Last filtered distance
};

// Initialize UART1 for SR04M-2 sensor (call once at startup)
void sensorInit();

// Perform single triggered measurement with temporal filtering.
// Returns distance in cm, or -1.0 if failed/rejected.
float readDistanceCM();

// Reset the temporal filter history (call after tank recalibration).
void resetSensorFilter();

// Maps sensor distance to fill percentage.
// emptyDist: distance when tank is empty (sensor to bottom, in mm).
// fullDist: distance when tank is full (sensor to water surface, in mm).
// Returns percentage 0-100, or -1.0 if invalid calibration.
float computeLevelPct(float distCM, float emptyDist, float fullDist);

// Get sensor diagnostics (read counts, error counts, last values).
SensorDiag getSensorDiagnostics();

// Reset sensor diagnostic counters.
void resetSensorDiagnostics();

// Self-test: send trigger, verify response within 120ms (3 attempts).
// Returns true if sensor responds, false if all attempts timeout.
bool sensorSelfTest();

// "D0"–"D10" → GPIO number. Returns 255 for unknown/invalid.
uint8_t resolvePin(const String& name);

// Executes diagnostic or sensor control commands.
// json: {"cmd":"sensor_test"} → test if sensor responds
//    or {"cmd":"get_diagnostics"} → get read/error/timeout counts
// resultBuf: filled with JSON response {"result":"ok|fail",...}
void handlePinCommand(const char* json, char* resultBuf, size_t bufLen);
