#include "sensor.h"
#include "config.h"
#include "pins.h"
#include "constants.h"
#include <ArduinoJson.h>
#include <math.h>

static float kfState   = -1.0f;
static float kfP       = KF_INITIAL_P;
static int   kfRejects = 0;

// Tolerance scales with tank size: 3 % of range, minimum 5 cm.
// For a 130 cm range → 5 cm.  For a 200 cm range → 6 cm.
static inline float confirmTol() {
    float range = config.d.tank_empty_cm - config.d.tank_full_cm;
    return fmaxf(range * CONFIRM_TOL_PERCENT, CONFIRM_TOL_MIN_CM);
}

// State machine for the confirmation window
enum ConfirmState { CS_SEEKING, CS_STABLE };
static ConfirmState csState       = CS_SEEKING;
static float        csBuf[CONFIRM_N] = {};
static int          csCount       = 0;
static float        csConfirmed   = -1.0f;  // last published stable value

// ── Internal helpers ──────────────────────────────────────────────────────────

static float takeOnePulse() {
    digitalWrite(PIN_TRIG, LOW);  delayMicroseconds(SENSOR_ECHO_PRE_DELAY_US);
    digitalWrite(PIN_TRIG, HIGH); delayMicroseconds(TRIG_PULSE_US);
    digitalWrite(PIN_TRIG, LOW);
    long dur = pulseIn(PIN_ECHO, HIGH, ECHO_TIMEOUT_US);
    if (dur <= 0) return -1.0f;
    return (dur * SOUND_SPEED_CM_US) / 2.0f;
}

// Insertion sort + return median.  Works on a small array (n ≤ READINGS_N).
static float sortedMedian(float* buf, int n) {
    for (int i = 1; i < n; i++) {
        float k = buf[i]; int j = i - 1;
        while (j >= 0 && buf[j] > k) { buf[j + 1] = buf[j]; j--; }
        buf[j + 1] = k;
    }
    return buf[n / 2];
}

// ── Confirmation state machine ──────────────────────────────────────────────────
// Layer 2 sits on top of Kalman: only publishes a level when CONFIRM_N
// consecutive accepted readings agree within tolerance.  Prevents a single
// spurious reading from momentarily reporting the wrong level.
//
// State CS_SEEKING: accumulate readings into csBuf until we have CONFIRM_N in agreement.
//   If a reading breaks consensus, reset and start over (retry 2 s later).
// State CS_STABLE: new reading is within tolerance of csConfirmed.  Slide the window:
//   shift csBuf left, add new reading on the right.
static float confirmationUpdate(float kfEstimate) {
    if (kfEstimate < 0.0f) return -1.0f;  // Kalman rejected it

    float tol = confirmTol();

    switch (csState) {
    case CS_SEEKING: {
        // Fill the buffer until we have CONFIRM_N readings
        csBuf[csCount] = kfEstimate;
        csCount++;

        if (csCount < CONFIRM_N) {
            // Still seeking — need more readings
            Serial.printf("[Confirm] Seeking: %d/%d readings (latest: %.1f cm)\n", csCount, CONFIRM_N, kfEstimate);
            return -1.0f;
        }

        // Have CONFIRM_N readings — check if they're all within tolerance of each other
        float minVal = csBuf[0], maxVal = csBuf[0];
        for (int i = 1; i < CONFIRM_N; i++) {
            if (csBuf[i] < minVal) minVal = csBuf[i];
            if (csBuf[i] > maxVal) maxVal = csBuf[i];
        }

        if (maxVal - minVal > tol) {
            // Readings don't agree — reset and retry
            Serial.printf("[Confirm] Disagreement: range %.1f cm > tol %.1f cm — seeking again\n",
                          maxVal - minVal, tol);
            csCount = 0;
            return -1.0f;
        }

        // All CONFIRM_N readings agree — move to stable state and publish the average
        float sum = 0.0f;
        for (int i = 0; i < CONFIRM_N; i++) sum += csBuf[i];
        csConfirmed = sum / CONFIRM_N;
        csState = CS_STABLE;
        Serial.printf("[Confirm] Stable at %.1f cm\n", csConfirmed);
        return csConfirmed;
    }

    case CS_STABLE: {
        // Check if new reading is still within tolerance
        if (fabsf(kfEstimate - csConfirmed) > tol) {
            // Out of tolerance — potential change; switch back to SEEKING mode
            Serial.printf("[Confirm] Divergence: %.1f cm (was %.1f cm) — seeking new consensus\n",
                          kfEstimate, csConfirmed);
            csCount = 1;
            csBuf[0] = kfEstimate;
            csState = CS_SEEKING;
            return -1.0f;
        }

        // Still within tolerance — slide the window
        for (int i = 0; i < CONFIRM_N - 1; i++) {
            csBuf[i] = csBuf[i + 1];
        }
        csBuf[CONFIRM_N - 1] = kfEstimate;

        // Re-compute the average from the sliding window
        float sum = 0.0f;
        for (int i = 0; i < CONFIRM_N; i++) sum += csBuf[i];
        csConfirmed = sum / CONFIRM_N;
        return csConfirmed;
    }
    }
    return -1.0f;
}

// ── Kalman update ─────────────────────────────────────────────────────────────
// Returns the filtered estimate if the measurement is plausible,
// or -1.0 if it is a spike.  The filter is SELF-HEALING:
//   - Each rejection causes kfP to grow (we become less certain).
//   - A larger kfP → larger innovation std dev → wider acceptance window.
//   - After KF_MAX_REJECT_STREAK rejections, history is treated as corrupted;
//     the measurement is force-accepted and the filter re-initialises.
static float kalmanUpdate(float measurement) {
    // First valid measurement ever → initialise and trust it blindly
    if (kfState < 0.0f) {
        kfState   = measurement;
        kfP       = KF_R;
        kfRejects = 0;
        return measurement;
    }

    // ── Predict step ─────────────────────────────────────────────────────────
    // State doesn't change between polls (tank level is stable over 30 s),
    // but uncertainty grows by Q each cycle.
    float P_pred = kfP + KF_Q;

    // ── Innovation (residual) ─────────────────────────────────────────────────
    float innovation  = measurement - kfState;          // how far is new reading from prediction
    float S           = P_pred + KF_R;                  // total innovation variance
    float sigma       = sqrtf(S);                       // ± this many cm is "normal"
    float threshold   = KF_OUTLIER_SIGMA * sigma;

    // ── Outlier check ─────────────────────────────────────────────────────────
    if (fabsf(innovation) > threshold) {
        kfRejects++;

        if (kfRejects >= KF_MAX_REJECT_STREAK) {
            // History is clearly wrong (e.g. sensor was temporarily obstructed,
            // incorrectly mounted, or previous readings were bad).
            // Force-accept this measurement and restart.
            Serial.printf("[Sensor] History corrected after %d rejections — "
                          "resetting to %.1f cm (prev_est=%.1f)\n",
                          kfRejects, measurement, kfState);
            kfState   = measurement;
            kfP       = KF_R;
            kfRejects = 0;
            return measurement;
        }

        // Normal rejection: grow uncertainty so threshold widens next time
        kfP = P_pred + KF_Q;   // extra Q to speed up uncertainty growth
        Serial.printf("[Sensor] Spike rejected: %.1f cm "
                      "(est=%.1f  ±%.1f cm  streak=%d)\n",
                      measurement, kfState, threshold, kfRejects);
        return -1.0f;
    }

    // ── Update step (measurement accepted) ───────────────────────────────────
    float K   = P_pred / S;                   // Kalman gain: 0 = ignore measurement, 1 = trust it fully
    kfState   = kfState + K * innovation;     // blend prediction with measurement
    kfP       = (1.0f - K) * P_pred;          // reduce uncertainty
    kfRejects = 0;

    return kfState;   // return the smoothed estimate, not the raw reading
}

// ── Public API ────────────────────────────────────────────────────────────────

float readDistanceCM() {
    // Step 1: multi-sample median — removes single-pulse hardware noise
    float buf[SENSOR_READINGS_PER_SAMPLE];
    int   valid = 0;
    for (int i = 0; i < SENSOR_READINGS_PER_SAMPLE; i++) {
        float d = takeOnePulse();
        if (d >= SENSOR_MIN_DISTANCE_CM && d <= SENSOR_MAX_DISTANCE_CM) buf[valid++] = d;
        if (i < SENSOR_READINGS_PER_SAMPLE - 1) delay(SENSOR_READING_DELAY_MS);
    }
    if (valid < SENSOR_MIN_VALID_PULSES) {
        // Not enough valid pulses — sensor may be disconnected or pins wrong
        static unsigned long lastWarn = 0;
        if (millis() - lastWarn > SENSOR_WARNING_LOG_INTERVAL_MS) {  // Log warning once per 10s to avoid spam
            Serial.printf("[Sensor] WARNING: Only %d/%d valid pulses. Check sensor connection and pins (TRIG=D2, ECHO=D1)\n", valid, SENSOR_READINGS_PER_SAMPLE);
            lastWarn = millis();
        }
        return -1.0f;
    }

    float median = sortedMedian(buf, valid);

    // Step 2: Kalman filter — per-reading noise suppression + self-healing
    float kfEst = kalmanUpdate(median);

    // Step 3: Consensus window — only report a level after CONFIRM_N (~3) readings
    // agree within tolerance. Prevents a single outlier that sneaks past Kalman
    // from momentarily showing the wrong level.
    return confirmationUpdate(kfEst);
}

void resetSensorFilter() {
    kfState     = -1.0f;
    kfP         = KF_INITIAL_P;
    kfRejects   = 0;
    csState     = CS_SEEKING;
    csCount     = 0;
    csConfirmed = -1.0f;
    Serial.println("[Sensor] Filters reset (Kalman + confirmation)");
}

float computeLevelPct(float distCM, float emptyDist, float fullDist) {
    float pct = LEVEL_PERCENTAGE_SCALE * (emptyDist - distCM) / (emptyDist - fullDist);
    return constrain(pct, 0.0f, LEVEL_PERCENTAGE_SCALE);
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
    const char* cmd    = doc["cmd"]        | "";
    const char* pin    = doc["pin"]        | "";
    const char* periph = doc["peripheral"] | "";

    if (strcmp(cmd, "test_pin") == 0) {
        // Full sensor test: trigger + echo in one atomic operation
        if (strcmp(periph, "sensor") == 0) {
            // Use hardcoded pins (same as normal polling)
            const uint8_t trigPin = PIN_TRIG;
            const uint8_t echoPin = PIN_ECHO;

            // Single attempt (no retries to avoid blocking)
            pinMode(trigPin, OUTPUT);
            pinMode(echoPin, INPUT);

            // Send trigger pulse (same timing as normal polling)
            digitalWrite(trigPin, LOW); delayMicroseconds(4);
            digitalWrite(trigPin, HIGH); delayMicroseconds(TRIG_PULSE_US);
            digitalWrite(trigPin, LOW);

            // Wait for echo immediately
            long dur = pulseIn(echoPin, HIGH, ECHO_TIMEOUT_US);

            if (dur > 0) {
                float dist = (dur * SOUND_SPEED_CM_US) / 2.0f;
                snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"value\":%.2f,\"unit\":\"cm\"}", dist);
            } else {
                snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"no_echo_timeout\"}");
            }
            return;
        }

        // Legacy: individual pin tests (kept for compatibility)
        uint8_t gpio = resolvePin(String(pin));
        if (gpio == 255) {
            snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"invalid_pin\"}");
            return;
        }
        if (strcmp(periph, "trig") == 0) {
            pinMode(gpio, OUTPUT);
            digitalWrite(gpio, LOW); delayMicroseconds(4);
            digitalWrite(gpio, HIGH); delayMicroseconds(TRIG_PULSE_US);
            digitalWrite(gpio, LOW);
            snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"detail\":\"pulse_sent\"}");
        } else if (strcmp(periph, "echo") == 0) {
            pinMode(gpio, INPUT);
            long dur = pulseIn(gpio, HIGH, ECHO_TIMEOUT_US);
            if (dur > 0) {
                float dist = (dur * SOUND_SPEED_CM_US) / 2.0f;
                snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"value\":%.2f,\"unit\":\"cm\"}", dist);
            } else {
                snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"no_echo_timeout\"}");
            }
        } else {
            snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"unknown_peripheral\"}");
        }
    } else if (strcmp(cmd, "save_pin") == 0) {
        char partial[PIN_COMMAND_PARTIAL_JSON_SIZE];
        if (strcmp(periph, "trig") == 0)
            snprintf(partial, sizeof(partial), "{\"pin_trig\":\"%s\"}", pin);
        else if (strcmp(periph, "echo") == 0)
            snprintf(partial, sizeof(partial), "{\"pin_echo\":\"%s\"}", pin);
        else {
            snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"unknown_peripheral\"}");
            return;
        }
        config.applyPartialJson(partial);
        snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"detail\":\"saved\"}");
    } else if (strcmp(cmd, "reboot") == 0) {
        snprintf(resultBuf, bufLen, "{\"result\":\"ok\",\"detail\":\"rebooting\"}");
    } else {
        snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"unknown_cmd\"}");
    }
}
