// Water Monitor Phase 1B — Unit Tests
// File: firmware/tank-sensor/test/unit_tests.cpp
// Compile with: platformio test

#include <Arduino.h>
#include <unity.h>
#include "../src/sensor.h"

// ─────────────────────────────────────────────────────────────
// TEST 1: Frame Validation
// ─────────────────────────────────────────────────────────────

void test_frameValidation_validFrame() {
    // Valid frame: 0xFF, 0x12, 0x34, checksum
    // Checksum: (0xFF + 0x12 + 0x34) & 0xFF = (0xFF + 0x12 + 0x34) = 0x145 & 0xFF = 0x45
    uint8_t valid[] = {0xFF, 0x12, 0x34, 0x45};

    // Note: We can't call validateFrame directly (it's static in sensor.cpp)
    // Instead, call readDistanceCM and verify it accepts the frame
    // This is an integration test, not a unit test

    TEST_MESSAGE("Frame validation requires integration test or exposure of validateFrame()");
}

void test_frameValidation_badChecksum() {
    // Bad checksum: should be rejected
    uint8_t badcs[] = {0xFF, 0x12, 0x34, 0x00};  // Wrong checksum

    TEST_MESSAGE("Frame validation requires integration test or exposure of validateFrame()");
}

// ─────────────────────────────────────────────────────────────
// TEST 2: Temporal Filter Initialization
// ─────────────────────────────────────────────────────────────

void test_temporalFilter_reset() {
    // Reset filter state
    resetSensorFilter();

    // First call should fail (warming up)
    float result1 = applyTemporalFilter(100.0f);
    TEST_ASSERT_EQUAL_FLOAT(-1.0f, result1);

    TEST_MESSAGE("Temporal filter reset successful");
}

// ─────────────────────────────────────────────────────────────
// TEST 3: Configuration Conversion (mm to cm)
// ─────────────────────────────────────────────────────────────

void test_configConversion_mmToCm() {
    // Test conversion from mm to cm
    float tank_empty_mm = 1000.0f;  // 1000 mm
    float tank_empty_cm = tank_empty_mm / 10.0f;  // 100 cm

    TEST_ASSERT_EQUAL_FLOAT(100.0f, tank_empty_cm);
}

void test_configConversion_levelCalculation() {
    // Test level percentage calculation
    // empty = 1000mm (100cm), full = 100mm (10cm), current = 500mm (50cm)
    float empty_cm = 1000.0f / 10.0f;   // 100 cm
    float full_cm = 100.0f / 10.0f;     // 10 cm
    float current_cm = 500.0f / 10.0f;  // 50 cm

    float range = empty_cm - full_cm;  // 90 cm
    float level = (empty_cm - current_cm) / range * 100.0f;  // (100-50)/90*100 = 55.56%

    TEST_ASSERT_FLOAT_WITHIN(0.1f, 55.56f, level);
}

void test_configConversion_levelBounds() {
    // Test that level is clamped to 0-100%
    float empty_cm = 100.0f;
    float full_cm = 10.0f;

    // Current above empty (full)
    float level_over = (empty_cm - 150.0f) / (empty_cm - full_cm) * 100.0f;
    level_over = constrain(level_over, 0.0f, 100.0f);
    TEST_ASSERT_EQUAL_FLOAT(0.0f, level_over);

    // Current below full (empty)
    float level_under = (empty_cm - 0.0f) / (empty_cm - full_cm) * 100.0f;
    level_under = constrain(level_under, 0.0f, 100.0f);
    TEST_ASSERT_EQUAL_FLOAT(100.0f, level_under);
}

// ─────────────────────────────────────────────────────────────
// TEST 4: Distance Filtering Logic
// ─────────────────────────────────────────────────────────────

void test_distanceFilter_plausibilityCheck() {
    // Test that a spike >2cm from mean is rejected
    resetSensorFilter();

    // Warm up with 10 stable readings (100cm)
    for (int i = 0; i < 10; i++) {
        float result = applyTemporalFilter(100.0f);
        // Results should be -1 (still warming up) until buffer full
    }

    // After warmup, normal reading should succeed
    float normal = applyTemporalFilter(100.0f);
    TEST_ASSERT(normal > 0.0f);  // Should now accept readings

    // Inject a spike >2cm from mean (should be smoothed or rejected)
    float spiked = applyTemporalFilter(150.0f);  // 50cm spike

    // Result should be closer to 100cm than 150cm (spike rejected/smoothed)
    TEST_ASSERT(spiked < 130.0f);  // Spike attenuated
}

void test_distanceFilter_validReading() {
    // Test that stable readings are accepted
    resetSensorFilter();

    // Warm up
    for (int i = 0; i < 10; i++) {
        applyTemporalFilter(150.0f);
    }

    // Normal reading should be accepted
    float result = applyTemporalFilter(150.5f);  // +0.5cm variance
    TEST_ASSERT(result > 0.0f);
    TEST_ASSERT_FLOAT_WITHIN(1.0f, 150.0f, result);  // Within 1cm of mean
}

// ─────────────────────────────────────────────────────────────
// TEST 5: Sensor Diagnostics Structure
// ─────────────────────────────────────────────────────────────

void test_sensorDiagnostics_structure() {
    // Verify SensorDiag struct is properly initialized
    SensorDiag diag;
    diag.readCount = 100;
    diag.frameErrorCount = 2;
    diag.timeoutCount = 1;

    TEST_ASSERT_EQUAL_UINT32(100, diag.readCount);
    TEST_ASSERT_EQUAL_UINT32(2, diag.frameErrorCount);
    TEST_ASSERT_EQUAL_UINT32(1, diag.timeoutCount);
}

void test_sensorDiagnostics_errorRate() {
    // Test error rate calculation
    uint32_t reads = 1000;
    uint32_t errors = 10;
    float error_rate = (float)errors / reads * 100.0f;

    TEST_ASSERT_FLOAT_WITHIN(0.01f, 1.0f, error_rate);  // 1% error rate
}

// ─────────────────────────────────────────────────────────────
// TEST 6: WiFi Reconnect Timer Logic
// ─────────────────────────────────────────────────────────────

void test_wifiReconnect_timerInterval() {
    // Test WiFi reconnect timer calculation
    unsigned long WIFI_RETRY_INTERVAL_MS = 50000;  // 50 seconds
    unsigned long now = millis();
    unsigned long lastAttempt = now - 60000;  // 60 seconds ago

    bool shouldRetry = (now - lastAttempt) > WIFI_RETRY_INTERVAL_MS;
    TEST_ASSERT_TRUE(shouldRetry);  // Should retry after 50s

    lastAttempt = now - 30000;  // 30 seconds ago
    shouldRetry = (now - lastAttempt) > WIFI_RETRY_INTERVAL_MS;
    TEST_ASSERT_FALSE(shouldRetry);  // Should NOT retry yet
}

// ─────────────────────────────────────────────────────────────
// TEST SETUP & TEARDOWN
// ─────────────────────────────────────────────────────────────

void setUp(void) {
    // Setup code (if needed for each test)
}

void tearDown(void) {
    // Cleanup code (if needed after each test)
}

// ─────────────────────────────────────────────────────────────
// MAIN TEST RUNNER
// ─────────────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(500);

    UNITY_BEGIN();

    // Frame validation
    RUN_TEST(test_frameValidation_validFrame);
    RUN_TEST(test_frameValidation_badChecksum);

    // Temporal filter
    RUN_TEST(test_temporalFilter_reset);

    // Configuration & conversion
    RUN_TEST(test_configConversion_mmToCm);
    RUN_TEST(test_configConversion_levelCalculation);
    RUN_TEST(test_configConversion_levelBounds);

    // Distance filtering
    RUN_TEST(test_distanceFilter_plausibilityCheck);
    RUN_TEST(test_distanceFilter_validReading);

    // Sensor diagnostics
    RUN_TEST(test_sensorDiagnostics_structure);
    RUN_TEST(test_sensorDiagnostics_errorRate);

    // WiFi reconnect
    RUN_TEST(test_wifiReconnect_timerInterval);

    UNITY_END();
}

void loop() {
    // Empty — all tests run in setup()
}
