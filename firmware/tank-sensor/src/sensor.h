#pragma once
#include <Arduino.h>

// Multi-sample median + temporal plausibility filter.
// Returns -1.0 if reading is out-of-range or an implausible spike.
float readDistanceCM();

// Reset the temporal filter history (call after tank config changes).
void resetSensorFilter();

// Maps sensor distance to fill percentage.
// emptyDist: distance when tank is empty (sensor to bottom).
// fullDist : distance when tank is full  (sensor to water surface).
float computeLevelPct(float distCM, float emptyDist, float fullDist);

// "D0"–"D10" → GPIO number. Returns 255 for unknown/invalid.
uint8_t resolvePin(const String& name);

// Executes a BLE/REST pin-test or pin-save command.
// json: {"cmd":"test_pin","pin":"D2","peripheral":"trig"|"echo"}
//    or {"cmd":"save_pin","pin":"D2","peripheral":"trig"|"echo"}
// resultBuf: filled with {"result":"ok|fail",...}
void handlePinCommand(const char* json, char* resultBuf, size_t bufLen);
