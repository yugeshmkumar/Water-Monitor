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

static void sensorTask(void* pv) {
    pinMode(PIN_TRIG, OUTPUT);
    pinMode(PIN_ECHO, INPUT);
    digitalWrite(PIN_TRIG, LOW);
    Serial.println("[Sensor] Task started");

    // Wait for sensor module to stabilize after power-on
    vTaskDelay(pdMS_TO_TICKS(500));

    // Auto-calibration tracking
    float lastLevel = 50.0f;  // last known level %
    uint32_t cycleStartTs = 0;

    while (true) {
        float    dist = readDistanceCM();
        bool     ok   = (dist > 0.0f);
        uint32_t ts   = millis() / 1000;

        if (!ok) {
            // Still seeking stable readings — normal during startup or after filter reset
            // Don't spam logs, just wait
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }

        Serial.printf("[Sensor] Valid reading: %.1f cm → %u%%\n", dist,
                      (uint8_t)computeLevelPct(dist, config.d.tank_empty_cm, config.d.tank_full_cm));

        uint8_t pct = (uint8_t)computeLevelPct(dist,
                                                config.d.tank_empty_cm,
                                                config.d.tank_full_cm);

        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(100))) {
            gState.distance_cm = dist;
            gState.level_pct   = pct;
            gState.sensor_ok   = true;
            gState.last_read_ts = ts;
            xSemaphoreGive(gStateMutex);
        }

        queueStore.write(dist, pct);
        bleServer.notifyLevel(dist, pct, ts);

        digitalWrite(PIN_LED, HIGH);
        delay(30);
        digitalWrite(PIN_LED, LOW);

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

    // Initial WiFi connect attempt
    if (wifiConnect()) {
        apiServer.begin();
        serverStarted = true;
    }

    while (true) {
        bool wifiNow = (WiFi.status() == WL_CONNECTED);

        if (!wifiNow && strlen(config.d.wifi_ssid) > 0) {
            Serial.println("[WiFi] Reconnecting...");
            if (wifiConnect()) {
                wifiNow = true;
                if (!serverStarted) {
                    apiServer.begin();
                    serverStarted = true;
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
                snap = gState;
                xSemaphoreGive(gStateMutex);
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
    bleServer.begin();
    while (true) {
        bleServer.loop();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

// ─── Arduino entry points ─────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(200);
    Serial.println("\n[Boot] Water Level Monitor v1.0 — Node A (XIAO ESP32-C6)");

    pinMode(PIN_LED, OUTPUT);
    digitalWrite(PIN_LED, HIGH);  // on during init sequence

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

    digitalWrite(PIN_LED, LOW);

    xTaskCreate(sensorTask, "sensor", 4096, NULL, 3, NULL);
    xTaskCreate(commsTask,  "comms",  8192, NULL, 2, NULL);
    xTaskCreate(bleTask,    "ble",    10240, NULL, 1, NULL);

    Serial.println("[Boot] OK — tasks started");
}

void loop() {
    // Idle — all work is done in FreeRTOS tasks above
    vTaskDelay(pdMS_TO_TICKS(10000));
}
