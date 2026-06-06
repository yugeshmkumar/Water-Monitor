#include "sensor.h"
#include "config.h"
#include "pins.h"
#include <ArduinoJson.h>
#include <math.h>

#define SOUND_SPEED_CM_US  0.0343f
#define TRIG_PULSE_US      15
#define ECHO_TIMEOUT_US    30000UL

// ── Multi-sample constants ────────────────────────────────────────────────────
// 5 samples × 60 ms = 300 ms per poll call
#define READINGS_N       5
#define READING_DELAY_MS 60

// ── Statistical ML Validator parameters ──────────────────────────────────────
// Dual-criterion validator: Welford online stats + sliding linear trend prediction.
// Warmup: first 30 readings → sort → trim 10% → seed both criteria
// Criterion A: reject if |reading - running_mean| > 2σ (Welford)
// Criterion B: reject if |reading - predicted_next| > 2σ_residual (linear trend)
// Mini-confirmation: 2-reading agreement within confirmTol() before emission
#define WARMUP_N      30
#define WARMUP_TRIM    3       // discard bottom/top 3 of 30 (10% each)
#define TREND_WINDOW   8       // 8-point sliding window for trend LS
#define REJECT_SIGMA  2.0f     // z-score threshold for both criteria
#define WF_DECAY      0.995f   // forgetting factor for Welford M2

struct ValidatorState {
    // Warmup buffer
    float    wu_buf[WARMUP_N];
    uint8_t  wu_count;
    bool     wu_done;

    // Criterion A: Welford online running mean/variance
    float    wf_mean;
    float    wf_M2;            // sum of squared deviations (not divided by n)
    uint16_t wf_count;

    // Criterion B: 8-point sliding window for online linear regression
    float    tr_buf[TREND_WINDOW];
    uint8_t  tr_head;          // ring buffer head index
    uint8_t  tr_count;         // number of valid entries (up to TREND_WINDOW)
    float    tr_sx, tr_sy;     // sums: Σx, Σy
    float    tr_sxx, tr_sxy;   // sums: Σx², Σxy (x is time index 0..7)

    // Residual tracking for trend standard deviation
    float    tr_res_mean;
    float    tr_res_M2;
    uint16_t tr_res_count;

    // Mini-confirmation: 2-reading agreement
    float    mc_last;          // -1.0 = no prior
};

static ValidatorState vs = {};

// Tolerance scales with tank size: 3% of range, minimum 5 cm.
static inline float confirmTol() {
    float range = config.d.tank_empty_cm - config.d.tank_full_cm;
    return fmaxf(range * 0.03f, 5.0f);
}

// ── Internal helpers ──────────────────────────────────────────────────────────

static float takeOnePulse() {
    // Use configured pins instead of hardcoded defaults
    uint8_t trigPin = resolvePin(String(config.d.pin_trig));
    uint8_t echoPin = resolvePin(String(config.d.pin_echo));

    // Validate pin resolution — 255 means invalid pin name
    if (trigPin == 255 || echoPin == 255) {
        static unsigned long lastWarn = 0;
        if (millis() - lastWarn > 10000) {
            Serial.printf("[Sensor] ERROR: Invalid pin config (TRIG=%s→%d, ECHO=%s→%d)\n",
                          config.d.pin_trig, trigPin, config.d.pin_echo, echoPin);
            lastWarn = millis();
        }
        return -1.0f;
    }

    // Disable interrupts during pulse timing to prevent BLE/WiFi from preempting
    // This is critical for ultrasonic sensors on ESP32 with radio tasks
    noInterrupts();

    digitalWrite(trigPin, LOW);  delayMicroseconds(4);
    digitalWrite(trigPin, HIGH); delayMicroseconds(TRIG_PULSE_US);
    digitalWrite(trigPin, LOW);
    long dur = pulseIn(echoPin, HIGH, ECHO_TIMEOUT_US);

    interrupts();

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

// ── Helper: insertion sort for warmup initialization ──────────────────────────
static void insertionSortAscending(float* buf, int n) {
    for (int i = 1; i < n; i++) {
        float k = buf[i];
        int j = i - 1;
        while (j >= 0 && buf[j] > k) {
            buf[j + 1] = buf[j];
            j--;
        }
        buf[j + 1] = k;
    }
}

// ── Helper: push new reading into trend buffer and recompute LS sums ──────────
static void trendPush(float y) {
    // Ring buffer: vs.tr_head points to next insertion slot
    // When buffer is full, recompute all sums; when not full, accumulate

    if (vs.tr_count == TREND_WINDOW) {
        // Buffer is full — add new, recompute sums from scratch
        vs.tr_buf[vs.tr_head] = y;
        vs.tr_head = (vs.tr_head + 1) % TREND_WINDOW;

        // Recompute all sums (8 elements, negligible cost)
        vs.tr_sx = vs.tr_sy = vs.tr_sxx = vs.tr_sxy = 0.0f;
        for (int i = 0; i < TREND_WINDOW; i++) {
            float xi = (float)i;
            float yi = vs.tr_buf[(vs.tr_head + i) % TREND_WINDOW];
            vs.tr_sx  += xi;
            vs.tr_sy  += yi;
            vs.tr_sxx += xi * xi;
            vs.tr_sxy += xi * yi;
        }
    } else {
        // Buffer not full — just append
        float xi = (float)vs.tr_count;
        vs.tr_buf[vs.tr_head] = y;
        vs.tr_head = (vs.tr_head + 1) % TREND_WINDOW;
        vs.tr_sx  += xi;
        vs.tr_sy  += y;
        vs.tr_sxx += xi * xi;
        vs.tr_sxy += xi * y;
        vs.tr_count++;
    }
}

// ── Helper: predict next reading using linear regression on trend ──────────────
static float trendPredict() {
    float n   = (float)TREND_WINDOW;
    float det = n * vs.tr_sxx - vs.tr_sx * vs.tr_sx;

    // Degenerate case — fall back to running mean
    if (fabsf(det) < 1e-6f) {
        return vs.wf_mean;
    }

    // Compute slope b and intercept a from least squares
    float b = (n * vs.tr_sxy - vs.tr_sx * vs.tr_sy) / det;
    float a = (vs.tr_sy - b * vs.tr_sx) / n;

    // Predict at x = TREND_WINDOW (one step ahead from the current window)
    return a + b * (float)TREND_WINDOW;
}

// ── Main validator: dual-criterion outlier rejection + mini-confirmation ──────
static float validatorUpdate(float median) {
    static bool inited = false;
    if (!inited) {
        vs.mc_last = -1.0f;
        inited = true;
    }

    // ── PHASE 1: WARMUP ──────────────────────────────────────────────────────
    if (!vs.wu_done) {
        vs.wu_buf[vs.wu_count++] = median;
        if (vs.wu_count < WARMUP_N) {
            return -1.0f;  // Still collecting; don't emit reading yet
        }

        // Warmup complete — initialize both criteria from trimmed data
        insertionSortAscending(vs.wu_buf, WARMUP_N);

        // Trim 10% from bottom and top (3 readings each of 30)
        int lo = WARMUP_TRIM;           // 3
        int hi = WARMUP_N - WARMUP_TRIM; // 27, exclusive
        int trimN = hi - lo;            // 24

        // Compute trimmed mean and variance
        float sum = 0.0f, sumSq = 0.0f;
        for (int i = lo; i < hi; i++) sum += vs.wu_buf[i];
        float mean = sum / trimN;
        for (int i = lo; i < hi; i++) {
            float d = vs.wu_buf[i] - mean;
            sumSq += d * d;
        }

        // Seed Welford state (Criterion A)
        vs.wf_mean  = mean;
        vs.wf_M2    = sumSq;  // sum of squared deviations
        vs.wf_count = (uint16_t)trimN;

        // Seed trend buffer (Criterion B) with last 8 of trimmed readings
        vs.tr_count = 0;
        vs.tr_head  = 0;
        vs.tr_sx = vs.tr_sy = vs.tr_sxx = vs.tr_sxy = 0.0f;
        int start = (hi >= TREND_WINDOW) ? (hi - TREND_WINDOW) : lo;
        for (int i = start; i < hi; i++) {
            trendPush(vs.wu_buf[i]);
        }

        // Mini-confirmation state
        vs.mc_last = -1.0f;
        vs.wu_done = true;

        Serial.printf("[Validator] Warmup complete (trimmed mean=%.1f, n=%d)\n", mean, trimN);
        return -1.0f;  // Don't emit on warmup completion
    }

    // ── PHASE 2: VALIDATION ──────────────────────────────────────────────────

    // Criterion A: z-score vs running mean (Welford)
    float wf_std = (vs.wf_count > 1)
        ? sqrtf(vs.wf_M2 / (vs.wf_count - 1))
        : 999.0f;
    bool rejectA = (fabsf(median - vs.wf_mean) > REJECT_SIGMA * wf_std);

    // Criterion B: z-score vs linear trend prediction (only after 4 trend readings)
    bool rejectB = false;
    if (vs.tr_count >= 4) {
        float predicted = trendPredict();
        float res_std = (vs.tr_res_count > 1)
            ? sqrtf(vs.tr_res_M2 / (vs.tr_res_count - 1))
            : 999.0f;
        rejectB = (fabsf(median - predicted) > REJECT_SIGMA * res_std);
    }

    // OR logic: reject if either criterion fires
    if (rejectA || rejectB) {
        Serial.printf("[Validator] REJECTED: meas=%.1f mean=%.1f wf_std=%.1f "
                      "predicted=%.1f rejectA=%d rejectB=%d\n",
                      median, vs.wf_mean, wf_std,
                      (vs.tr_count >= 4) ? trendPredict() : -1.0f,
                      (int)rejectA, (int)rejectB);
        return -1.0f;
    }

    // ── UPDATE STATISTICS (reading accepted) ─────────────────────────────────

    // Update Welford state with forgetting factor
    vs.wf_count++;
    float delta  = median - vs.wf_mean;
    vs.wf_mean  += delta / vs.wf_count;
    float delta2 = median - vs.wf_mean;
    vs.wf_M2     = vs.wf_M2 * WF_DECAY + delta * delta2;
    vs.wf_M2     = fmaxf(vs.wf_M2, 0.0f);  // Guard against float precision issues

    // Update residual tracking if trend is active
    if (vs.tr_count >= 4) {
        float predicted = trendPredict();
        float residual  = median - predicted;
        vs.tr_res_count++;
        float rd  = residual - vs.tr_res_mean;
        vs.tr_res_mean += rd / vs.tr_res_count;
        float rd2 = residual - vs.tr_res_mean;
        vs.tr_res_M2 = vs.tr_res_M2 * WF_DECAY + rd * rd2;
        vs.tr_res_M2 = fmaxf(vs.tr_res_M2, 0.0f);
    }

    // Push to trend buffer
    trendPush(median);

    Serial.printf("[Validator] ACCEPTED: meas=%.1f mean=%.1f wf_std=%.1f\n",
                  median, vs.wf_mean, wf_std);

    // ── PHASE 3: MINI-CONFIRMATION (2-reading agreement) ─────────────────────
    if (vs.mc_last < 0.0f) {
        // First accepted reading after validation — hold for next one
        vs.mc_last = median;
        return -1.0f;
    }

    float tol = confirmTol();
    if (fabsf(median - vs.mc_last) <= tol) {
        // Two consecutive readings agree — emit average
        float out  = (median + vs.mc_last) / 2.0f;
        vs.mc_last = median;
        return out;
    }

    // Readings diverge — this becomes new baseline, wait for agreement
    vs.mc_last = median;
    return -1.0f;
}

// ── Public API ────────────────────────────────────────────────────────────────

float readDistanceCM() {
    // Step 1: multi-sample median — removes single-pulse hardware noise
    float buf[READINGS_N];
    float rawReadings[READINGS_N];  // Debug: store all attempts including failures
    int   valid = 0;
    for (int i = 0; i < READINGS_N; i++) {
        float d = takeOnePulse();
        rawReadings[i] = d;
        if (d >= 20.0f && d <= 600.0f) buf[valid++] = d;
        if (i < READINGS_N - 1) delay(READING_DELAY_MS);
    }
    if (valid < 3) {
        // Not enough valid pulses — sensor may be disconnected or pins wrong
        static unsigned long lastWarn = 0;
        if (millis() - lastWarn > 10000) {  // Log warning once per 10s to avoid spam
            Serial.printf("[Sensor] WARNING: Only %d/%d valid pulses\n", valid, READINGS_N);
            Serial.printf("[Sensor DEBUG] Raw measurements: %.1f, %.1f, %.1f, %.1f, %.1f cm\n",
                          rawReadings[0], rawReadings[1], rawReadings[2], rawReadings[3], rawReadings[4]);
            Serial.printf("[Sensor DEBUG] Valid readings: ");
            for (int i = 0; i < valid; i++) Serial.printf("%.1f ", buf[i]);
            Serial.println("cm");
            lastWarn = millis();
        }
        return -1.0f;
    }

    float median = sortedMedian(buf, valid);
    Serial.printf("[Sensor DEBUG] Raw: [%.1f, %.1f, %.1f, %.1f, %.1f] → Median: %.1f cm (%d valid)\n",
                  rawReadings[0], rawReadings[1], rawReadings[2], rawReadings[3], rawReadings[4], median, valid);

    // In test mode: return raw median for true real-time readings without filtering delays
    if (config.d.testing_mode) {
        return median;
    }

    // Step 2: Statistical ML validator — dual-criterion outlier rejection with
    //         online learning, warmup initialization, and mini-confirmation.
    return validatorUpdate(median);
}

void resetSensorFilter() {
    vs         = {};  // zero-initialize all validator state
    vs.mc_last = -1.0f;  // sentinel: no prior reading yet
    Serial.println("[Sensor] Validator reset (warmup will restart)");
}

float computeLevelPct(float distCM, float emptyDist, float fullDist) {
    float range = emptyDist - fullDist;
    if (fabsf(range) < 1.0f) return -1.0f;  // Invalid calibration, return error
    float pct = 100.0f * (emptyDist - distCM) / range;
    return constrain(pct, 0.0f, 100.0f);
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
            // Use configured pins (same as normal polling)
            const uint8_t trigPin = resolvePin(String(config.d.pin_trig));
            const uint8_t echoPin = resolvePin(String(config.d.pin_echo));

            // Validate pin resolution
            if (trigPin == 255 || echoPin == 255) {
                snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"invalid_pin_config\"}");
                return;
            }

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
        if (gpio == 255 || pin[0] == '\0') {
            snprintf(resultBuf, bufLen, "{\"result\":\"fail\",\"detail\":\"invalid_pin\"}");
            return;
        }
        if (strcmp(periph, "trig") == 0) {
            pinMode(gpio, OUTPUT);
            digitalWrite(gpio, LOW); delayMicroseconds(4);
            digitalWrite(gpio, HIGH); delayMicroseconds(15);
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
        char partial[64];
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
