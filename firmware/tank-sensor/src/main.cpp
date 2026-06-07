#include <Arduino.h>
#include <WiFi.h>
#include <LittleFS.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

#include "pins.h"
#include "state.h"
#include "config.h"
#include "sensor.h"
#include "queue_store.h"
#include "ble_server.h"
#include "api_server.h"
#include "watchdog.h"
#include "health.h"

// ─── Shared state (defined here, declared extern in state.h) ──
DeviceState       gState;
SemaphoreHandle_t gStateMutex;

// ─── MQTT ─────────────────────────────────────────────────────
static WiFiClient   wifiClient;
static PubSubClient mqttClient(wifiClient);
static bool         mqttConfigured = false;

static void mqttEnsureConnected() {
    if (strlen(config.d.mqtt_broker_ip) == 0) return;
    if (!mqttConfigured) {
        mqttClient.setServer(config.d.mqtt_broker_ip, 1883);
        mqttClient.setBufferSize(1024);
        mqttConfigured = true;
    }
    if (!mqttClient.connected()) {
        mqttClient.connect(config.d.node_id);
    }
}

static void mqttPublishLevel(float dist, uint8_t pct, uint32_t ts) {
    if (!mqttClient.connected()) return;
    char buf[192];
    snprintf(buf, sizeof(buf),
             "{\"node\":\"%s\",\"ts\":%lu,\"level_pct\":%u,"
             "\"distance_cm\":%.1f,\"sensor_ok\":true,\"queued\":false}",
             config.d.node_id, (unsigned long)ts, pct, dist);
    mqttClient.publish("home/tank/level", buf);
}

static void mqttFlushQueue() {
    if (!mqttClient.connected() || queueStore.pendingCount() == 0) return;

    JsonDocument doc;
    JsonArray arr = doc.to<JsonArray>();
    queueStore.getUnsent(arr, 50);
    if (arr.size() == 0) return;

    String payload;
    serializeJson(doc, payload);
    if (mqttClient.publish("home/tank/queue", payload.c_str())) {
        uint32_t lastSeq = arr[arr.size() - 1]["seq"] | 0u;
        queueStore.ackUpTo(lastSeq);
    }
}

// ─── WiFi ─────────────────────────────────────────────────────
static bool wifiConnect() {
    if (strlen(config.d.wifi_ssid) == 0) return false;

    WiFi.mode(WIFI_STA);
    WiFi.setHostname(config.d.node_id);
    WiFi.begin(config.d.wifi_ssid, config.d.wifi_pass);
    Serial.printf("[WiFi] Connecting to \"%s\"", config.d.wifi_ssid);

    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500);
        Serial.print('.');
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("[WiFi] Connected — IP: %s  RSSI: %d dBm\n",
                      WiFi.localIP().toString().c_str(), (int)WiFi.RSSI());
        return true;
    }
    Serial.println("[WiFi] Failed — BLE-only mode");
    return false;
}

// ─── FreeRTOS tasks ───────────────────────────────────────────
// NOTE: All tasks MUST call watchdog.feed() periodically to prevent restart

static void sensorTask(void* pv) {
    Serial.println("[Sensor] Task starting...");

    // Initialize SR04M-2 UART sensor (GPIO20 RX, GPIO21 TX, 9600 baud)
    sensorInit();

    // Register this task with watchdog (15 second deadline)
    watchdog.registerTask("sensor", xTaskGetCurrentTaskHandle(), 15000);

    // Wait for sensor module to stabilize after power-on
    vTaskDelay(pdMS_TO_TICKS(1000));

    // Run self-test to verify sensor responds
    uint8_t selfTestAttempts = 0;
    while (!sensorSelfTest() && selfTestAttempts < 3) {
        selfTestAttempts++;
        Serial.printf("[Sensor] Self-test attempt %u failed, retrying...\n", selfTestAttempts);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }

    if (selfTestAttempts >= 3) {
        Serial.println("[Sensor] ERROR: Self-test failed 3x. Sensor not responding.");
        Serial.println("[Sensor] Verify: SR04M-2 has 120kΩ mode resistor soldered on board");
        // Continue anyway - WiFi queue will buffer readings when sensor recovers
    }

    // Feed watchdog on startup success
    watchdog.feed("sensor");

    // Auto-calibration tracking
    float lastLevel = 50.0f;  // last known level %
    uint32_t cycleStartTs = 0;
    unsigned long lastSensorFeed = millis();

    while (true) {
        // Feed watchdog periodically (at least every 15 seconds)
        if (millis() - lastSensorFeed > 5000) {
            watchdog.feed("sensor");
            lastSensorFeed = millis();
        }

        float    dist = readDistanceCM();
        bool     ok   = (dist > 0.0f);
        uint32_t ts   = millis() / 1000;

        if (!ok) {
            // Reading failed (timeout or frame error) — normal during startup
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }

        float emptyDist_cm = config.d.tank_empty_cm;
        float fullDist_cm = config.d.tank_full_cm;

        Serial.printf("[Sensor] Valid reading: %.1f cm → %u%% (empty=%.1f, full=%.1f cm)\n",
                      dist, (uint8_t)computeLevelPct(dist, emptyDist_cm, fullDist_cm),
                      emptyDist_cm, fullDist_cm);

        uint8_t pct = (uint8_t)computeLevelPct(dist, emptyDist_cm, fullDist_cm);

        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(100))) {
            gState.distance_cm = dist;
            gState.level_pct   = pct;
            gState.sensor_ok   = true;
            gState.last_read_ts = ts;
            xSemaphoreGive(gStateMutex);
        }

        queueStore.write(dist, pct);
        bleServer.notifyLevel(dist, pct, ts);

        digitalWrite(PIN_LED_STATUS, HIGH);
        delay(30);
        digitalWrite(PIN_LED_STATUS, LOW);

        // ── Auto-calibration: track min/max and detect cycles ──────────────────
        if (config.d.auto_calibration_enabled) {
            // Update detected min/max
            if (dist < config.d.auto_cal_min_cm) {
                config.d.auto_cal_min_cm = dist;
            }
            if (dist > config.d.auto_cal_max_cm) {
                config.d.auto_cal_max_cm = dist;
            }

            // Detect fill/drain cycles: if level changes > 20% between readings
            if (abs((int)pct - (int)lastLevel) > 20) {
                if (cycleStartTs == 0 || (ts - cycleStartTs) > 600) {  // min 10 min between cycles
                    config.d.calibration_cycles++;
                    cycleStartTs = ts;
                    // Confidence increases: 10% per cycle, cap at 90%
                    if (config.d.calibration_confidence < 90) {
                        config.d.calibration_confidence = (uint8_t)min(
                            (int)config.d.calibration_confidence + 10, 90
                        );
                    }
                    config.save();
                    Serial.printf("[AutoCal] Cycle %u detected, confidence now %u%%\n",
                                  config.d.calibration_cycles, config.d.calibration_confidence);
                }
            }
            lastLevel = pct;
        }

        uint32_t intervalS = config.d.testing_mode
                             ? config.d.test_poll_interval_s
                             : config.d.poll_interval_s;
        vTaskDelay(pdMS_TO_TICKS(intervalS * 1000));
    }
}

static void commsTask(void* pv) {
    bool serverStarted   = false;
    uint32_t lastPushedTs = 0;  // tracks last ts pushed via WS + MQTT to avoid re-sends
    unsigned long lastDiagPrint = 0;  // tracks diagnostics print frequency

    // Register this task with watchdog (20 second deadline)
    watchdog.registerTask("comms", xTaskGetCurrentTaskHandle(), 20000);

    // WiFi non-blocking reconnect timer
    unsigned long lastWiFiAttempt = 0;
    static const unsigned long WIFI_RETRY_INTERVAL_MS = 50000;  // 50 seconds
    uint32_t wifiReconnectAttempts = 0;
    unsigned long lastCommsFeed = millis();

    // Initial WiFi connect attempt
    if (wifiConnect()) {
        apiServer.begin();
        serverStarted = true;
        Serial.println("[WiFi] Initial connection successful");
    } else {
        Serial.println("[WiFi] Initial connection failed, will retry every 50s");
    }

    // Feed watchdog on startup
    watchdog.feed("comms");

    while (true) {
        // Feed watchdog periodically (at least every 20 seconds)
        if (millis() - lastCommsFeed > 10000) {
            watchdog.feed("comms");
            lastCommsFeed = millis();
        }
        bool wifiNow = (WiFi.status() == WL_CONNECTED);

        // Non-blocking WiFi reconnect: only attempt every 50 seconds
        if (!wifiNow && strlen(config.d.wifi_ssid) > 0) {
            unsigned long now = millis();
            if (now - lastWiFiAttempt > WIFI_RETRY_INTERVAL_MS) {
                lastWiFiAttempt = now;
                wifiReconnectAttempts++;
                Serial.printf("[WiFi] Reconnection attempt #%lu (offline for ~%lus)\n",
                              wifiReconnectAttempts, (now / 1000));

                // Non-blocking: attempt connection with timeout, don't wait long
                WiFi.mode(WIFI_STA);
                WiFi.begin(config.d.wifi_ssid, config.d.wifi_pass);

                // Check result immediately after begin, but don't block
                vTaskDelay(pdMS_TO_TICKS(100));

                if (WiFi.status() == WL_CONNECTED) {
                    wifiNow = true;
                    Serial.println("[WiFi] Reconnection successful!");
                    if (!serverStarted) {
                        apiServer.begin();
                        serverStarted = true;
                    }
                }
            }
        }

        DeviceState snap;

        if (wifiNow) {
            int8_t rssi = (int8_t)WiFi.RSSI();

            mqttEnsureConnected();
            mqttClient.loop();

            if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
                gState.wifi_ok     = true;
                gState.wifi_rssi   = rssi;
                gState.queue_depth = queueStore.pendingCount();

                // Log connection success (helps with diagnostics)
                static unsigned long lastSuccessfulWiFi = 0;
                lastSuccessfulWiFi = millis();

                snap = gState;
                xSemaphoreGive(gStateMutex);
            }

            // Print diagnostics every 60 seconds while connected
            if (millis() - lastDiagPrint > 60000) {
                lastDiagPrint = millis();
                SensorDiag diag = getSensorDiagnostics();
                Serial.printf("[Diagnostics] Reads:%lu Errors:%lu Timeouts:%lu "
                              "Queue:%u RSSI:%d\n",
                              diag.readCount, diag.frameErrorCount, diag.timeoutCount,
                              gState.queue_depth, rssi);
            }

            // Push new readings only once per sensor cycle
            if (snap.sensor_ok && snap.last_read_ts != lastPushedTs) {
                apiServer.broadcastLevel(snap.distance_cm, snap.level_pct, snap.last_read_ts);
                mqttPublishLevel(snap.distance_cm, snap.level_pct, snap.last_read_ts);
                lastPushedTs = snap.last_read_ts;
            }

            mqttFlushQueue();
            bleServer.notifyStatus(true, snap.sensor_ok, rssi, snap.queue_depth);
            apiServer.loop();
            // Deferred ACK: process any pending ack seq set by the async_tcp REST handler.
            // Must run here (commsTask), not inside the async_tcp callback, because
            // LittleFS flash erase inside async_tcp starves the TCP stack → watchdog crash.
            queueStore.processPending();

            // Print diagnostics every 60 seconds while connected
            if (millis() - lastDiagPrint > 60000) {
                lastDiagPrint = millis();
                SensorDiag diag = getSensorDiagnostics();
                Serial.printf("[Diagnostics] Reads:%lu Errors:%lu Timeouts:%lu "
                              "Queue:%u RSSI:%d\n",
                              diag.readCount, diag.frameErrorCount, diag.timeoutCount,
                              snap.queue_depth, (int8_t)WiFi.RSSI());
            }

        } else {
            if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
                gState.wifi_ok   = false;
                gState.wifi_rssi = 0;
                snap = gState;
                xSemaphoreGive(gStateMutex);
            }
            bleServer.notifyStatus(false, snap.sensor_ok, 0, queueStore.pendingCount());
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void bleTask(void* pv) {
    // Register this task with watchdog (10 second deadline)
    watchdog.registerTask("ble", xTaskGetCurrentTaskHandle(), 10000);

    bleServer.begin();
    watchdog.feed("ble");

    unsigned long lastBleFeed = millis();

    while (true) {
        // Feed watchdog periodically
        if (millis() - lastBleFeed > 5000) {
            watchdog.feed("ble");
            lastBleFeed = millis();
        }

        bleServer.loop();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

// ─── Health Monitoring Task ──────────────────────────────────────────
// Monitors system health and triggers restart if critical issues detected

static void healthTask(void* pv) {
    health.begin();
    Serial.println("[Health] Health monitoring task started");

    unsigned long lastHealthCheck = millis();

    while (true) {
        vTaskDelay(pdMS_TO_TICKS(10000));  // Check every 10 seconds

        // Update health metrics
        health.update();

        // Check for recovery conditions
        health.checkAndRecover();

        // Log health every 60 seconds
        if (millis() - lastHealthCheck > 60000) {
            lastHealthCheck = millis();
            SystemHealth h = health.getHealth();
            Serial.printf("[Health] Score: %u%% | Heap: %u bytes | "
                          "Tasks: S:%s C:%s B:%s | WiFi: %s (RSSI:%d)\n",
                          h.healthScore, h.heapFree,
                          h.sensorTaskHealthy ? "✓" : "✗",
                          h.commsTaskHealthy ? "✓" : "✗",
                          h.bleTaskHealthy ? "✓" : "✗",
                          h.wifiConnected ? "✓" : "✗",
                          h.wifiRssi);
        }
    }
}

// ─── Arduino entry points ─────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(200);
    Serial.println("\n[Boot] Water Level Monitor v1.0 — Node A (XIAO ESP32-C6)");
    Serial.println("[Boot] Production-Grade Firmware with Watchdog & Health Monitoring");

    pinMode(PIN_LED_STATUS, OUTPUT);
    digitalWrite(PIN_LED_STATUS, HIGH);  // on during init sequence

    // Initialize watchdog FIRST (before any other subsystem)
    health.begin();
    watchdog.begin();

    if (!LittleFS.begin(true)) {
        Serial.println("[Boot] LittleFS mount failed — formatting");
        LittleFS.format();
        LittleFS.begin(true);
    }

    config.load();
    uint32_t activeInterval = config.d.testing_mode
                              ? config.d.test_poll_interval_s
                              : config.d.poll_interval_s;
    Serial.printf("[Boot] node_id=%s  ssid=%s  poll=%us%s\n",
                  config.d.node_id,
                  strlen(config.d.wifi_ssid) ? config.d.wifi_ssid : "(not set)",
                  activeInterval,
                  config.d.testing_mode ? " [TEST MODE]" : "");

    queueStore.begin();
    Serial.printf("[Boot] Queue: %u pending entries\n", queueStore.pendingCount());

    gStateMutex = xSemaphoreCreateMutex();
    configASSERT(gStateMutex != NULL);

    digitalWrite(PIN_LED_STATUS, LOW);

    // Create tasks with proper stack sizes for production
    // Stack sizes tested and validated for no overflow
    xTaskCreatePinnedToCore(sensorTask, "sensor", 4096, NULL, 3, NULL, 0);
    xTaskCreatePinnedToCore(commsTask,  "comms",  8192, NULL, 2, NULL, 0);
    xTaskCreatePinnedToCore(bleTask,    "ble",    10240, NULL, 1, NULL, 1);
    xTaskCreatePinnedToCore(healthTask, "health", 4096, NULL, 1, NULL, 1);

    // Register main task with watchdog for health monitoring
    watchdog.registerTask("main", xTaskGetCurrentTaskHandle(), 15000);

    // Feed watchdog on startup
    watchdog.feed("main");

    Serial.println("[Boot] OK — tasks started with watchdog protection");
}

void loop() {
    // Idle — all work is done in FreeRTOS tasks above
    // Still need to feed watchdog to prevent main loop timeout
    watchdog.feed("main");
    vTaskDelay(pdMS_TO_TICKS(10000));
}
