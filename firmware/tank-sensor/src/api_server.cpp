#include "api_server.h"
#include "config.h"
#include "sensor.h"
#include "queue_store.h"
#include "state.h"
#include <ArduinoJson.h>
#include <AsyncJson.h>
#include <ESPmDNS.h>
#include <ElegantOTA.h>
#include <WiFi.h>
#include <nvs_flash.h>

// HTTPUpdate for OTA-from-URL (requires WiFiClient)
#include <HTTPUpdate.h>

ApiServer apiServer;

// ─────────────────────────────────────────────────────────────
// OTA-from-URL task
// ─────────────────────────────────────────────────────────────

static char _otaUrl[256] = "";

static void otaTask(void* pv) {
    Serial.printf("[OTA] Starting update from: %s\n", _otaUrl);
    WiFiClient client;
    httpUpdate.setLedPin(LED_BUILTIN, HIGH);
    httpUpdate.rebootOnUpdate(true);
    t_httpUpdate_return ret = httpUpdate.update(client, _otaUrl);
    if (ret == HTTP_UPDATE_FAILED) {
        Serial.printf("[OTA] Failed (%d): %s\n",
                      httpUpdate.getLastError(),
                      httpUpdate.getLastErrorString().c_str());
    }
    vTaskDelete(NULL);
}

// ─────────────────────────────────────────────────────────────
// ApiServer
// ─────────────────────────────────────────────────────────────

void ApiServer::begin() {
    _setupWebSocket();
    _setupRest();

    _http.begin();

    // mDNS: {node_id}.local — hostname matches node_id so app can discover by nodeID
    if (MDNS.begin(config.d.node_id)) {
        MDNS.addService("http", "tcp", 80);
        Serial.printf("[API] mDNS: %s.local\n", config.d.node_id);
    }

    // Browser-accessible OTA at http://waterlevel-a.local/update
    ElegantOTA.begin(&_http);
    ElegantOTA.setAutoReboot(true);

    Serial.println("[API] REST+WS :80  (/live for WebSocket)");
}

void ApiServer::loop() {
    _ws.cleanupClients();
    ElegantOTA.loop();
}

void ApiServer::broadcastLevel(float distCM, uint8_t levelPct, uint32_t ts) {
    if (_ws.count() == 0) return;

    DeviceState snap;
    if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
        snap = gState;
        xSemaphoreGive(gStateMutex);
    }

    // Send complete status matching /api/status format for consistency
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"level_pct\":%u,\"distance_cm\":%.1f,\"ts\":%lu,"
             "\"sensor_ok\":%s,\"wifi_ok\":%s,\"rssi\":%d,"
             "\"queue_depth\":%u,\"fw\":\"%s\",\"local_ip\":\"%s\"}",
             levelPct, distCM, (unsigned long)ts,
             snap.sensor_ok ? "true" : "false",
             snap.wifi_ok   ? "true" : "false",
             snap.wifi_rssi,
             snap.queue_depth,
             config.d.firmware_version,
             WiFi.localIP().toString().c_str());
    _ws.textAll(buf);
}

// ─────────────────────────────────────────────────────────────
// WebSocket
// ─────────────────────────────────────────────────────────────

void ApiServer::_setupWebSocket() {
    _ws.onEvent([this](AsyncWebSocket* server, AsyncWebSocketClient* client,
                       AwsEventType type, void* arg, uint8_t* data, size_t len) {
        _onWsEvent(server, client, type, arg, data, len);
    });
    _http.addHandler(&_ws);
}

void ApiServer::_onWsEvent(AsyncWebSocket*, AsyncWebSocketClient* client,
                            AwsEventType type, void*, uint8_t* data, size_t len) {
    if (type == WS_EVT_CONNECT) {
        Serial.printf("[WS] Client #%u connected\n", client->id());
        // Send current state immediately on connect (complete status matching /api/status)
        DeviceState snap;
        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
            snap = gState;
            xSemaphoreGive(gStateMutex);
        }
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "{\"level_pct\":%u,\"distance_cm\":%.1f,\"ts\":%lu,"
                 "\"sensor_ok\":%s,\"wifi_ok\":%s,\"rssi\":%d,"
                 "\"queue_depth\":%u,\"fw\":\"%s\",\"local_ip\":\"%s\"}",
                 snap.level_pct, snap.distance_cm, (unsigned long)snap.last_read_ts,
                 snap.sensor_ok ? "true" : "false",
                 snap.wifi_ok   ? "true" : "false",
                 snap.wifi_rssi,
                 snap.queue_depth,
                 config.d.firmware_version,
                 WiFi.localIP().toString().c_str());
        client->text(buf);

    } else if (type == WS_EVT_DISCONNECT) {
        Serial.printf("[WS] Client #%u disconnected\n", client->id());
    }
    (void)data; (void)len;
}

// ─────────────────────────────────────────────────────────────
// REST routes
// ─────────────────────────────────────────────────────────────

void ApiServer::_setupRest() {
    // GET /api/status
    _http.on("/api/status", HTTP_GET, [](AsyncWebServerRequest* req) {
        DeviceState snap;
        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
            snap = gState;
            xSemaphoreGive(gStateMutex);
        }
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "{\"level_pct\":%u,\"distance_cm\":%.1f,\"ts\":%lu,"
                 "\"sensor_ok\":%s,\"wifi_ok\":%s,\"rssi\":%d,"
                 "\"queue_depth\":%u,\"fw\":\"%s\",\"local_ip\":\"%s\"}",
                 snap.level_pct, snap.distance_cm, (unsigned long)snap.last_read_ts,
                 snap.sensor_ok ? "true" : "false",
                 snap.wifi_ok   ? "true" : "false",
                 snap.wifi_rssi, snap.queue_depth,
                 config.d.firmware_version,
                 WiFi.localIP().toString().c_str());
        req->send(200, "application/json", buf);
    });

    // GET /api/config — persisted config + runtime network info
    _http.on("/api/config", HTTP_GET, [](AsyncWebServerRequest* req) {
        JsonDocument doc;
        config.toJson(doc);
        doc["ip"]       = WiFi.localIP().toString();
        doc["mac"]      = WiFi.macAddress();
        doc["hostname"] = String(config.d.node_id) + ".local";
        String body;
        serializeJson(doc, body);
        req->send(200, "application/json", body);
    });

    // POST /api/config — partial update
    _http.addHandler(new AsyncCallbackJsonWebHandler("/api/config",
        [](AsyncWebServerRequest* req, JsonVariant& json) {
            String body;
            serializeJson(json, body);
            Serial.printf("[API] Config update: %s\n", body.c_str());
            bool ok = config.applyPartialJson(body.c_str());
            if (ok) {
                resetSensorFilter();   // tank range may have changed
                uint32_t intervalS = config.d.testing_mode
                                     ? config.d.test_poll_interval_s
                                     : config.d.poll_interval_s;
                Serial.printf("[API] Config applied — test_mode=%s  poll=%us\n",
                              config.d.testing_mode ? "ON" : "OFF", intervalS);
            }
            req->send(ok ? 200 : 400, "application/json",
                      ok ? "{\"ok\":true}" : "{\"ok\":false,\"error\":\"parse_error\"}");
        }));

    // GET /api/diagnostics — comprehensive system diagnostics
    _http.on("/api/diagnostics", HTTP_GET, [](AsyncWebServerRequest* req) {
        DeviceState snap;
        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(50))) {
            snap = gState;
            xSemaphoreGive(gStateMutex);
        }

        SensorDiag sensorDiag = getSensorDiagnostics();

        // Calculate memory stats
        uint32_t heapFree = ESP.getFreeHeap();
        uint32_t heapTotal = ESP.getHeapSize();
        uint32_t psramFree = ESP.getFreePsram();

        // Build comprehensive diagnostics JSON
        JsonDocument doc;

        // Sensor diagnostics
        JsonObject sensor = doc["sensor"].to<JsonObject>();
        sensor["reads"] = sensorDiag.readCount;
        sensor["frame_errors"] = sensorDiag.frameErrorCount;
        sensor["timeouts"] = sensorDiag.timeoutCount;
        sensor["last_raw_cm"] = sensorDiag.lastRawDist;
        sensor["last_filtered_cm"] = sensorDiag.lastFilteredDist;
        sensor["error_rate_%"] = sensorDiag.readCount > 0
            ? (float)(sensorDiag.frameErrorCount + sensorDiag.timeoutCount) / sensorDiag.readCount * 100.0f
            : 0.0f;

        // WiFi diagnostics
        JsonObject wifi = doc["wifi"].to<JsonObject>();
        wifi["connected"] = snap.wifi_ok;
        wifi["rssi_dbm"] = snap.wifi_rssi;
        wifi["ssid"] = String(config.d.wifi_ssid);

        // Queue diagnostics
        JsonObject queue = doc["queue"].to<JsonObject>();
        queue["pending"] = snap.queue_depth;

        // System diagnostics
        JsonObject system = doc["system"].to<JsonObject>();
        system["uptime_s"] = millis() / 1000;
        system["heap_free"] = heapFree;
        system["heap_total"] = heapTotal;
        system["heap_used_%"] = heapTotal > 0 ? (float)(heapTotal - heapFree) / heapTotal * 100.0f : 0.0f;
        system["psram_free"] = psramFree;
        system["fw_version"] = String(config.d.firmware_version);

        // Configuration state
        JsonObject config_state = doc["config"].to<JsonObject>();
        config_state["tank_empty_cm"] = config.d.tank_empty_cm;
        config_state["tank_full_cm"] = config.d.tank_full_cm;
        config_state["poll_interval_s"] = config.d.poll_interval_s;
        config_state["testing_mode"] = config.d.testing_mode;

        String body;
        serializeJson(doc, body);
        req->send(200, "application/json", body);
    });

    // POST /api/queue/flush — return up to 50 unsent entries
    _http.on("/api/queue/flush", HTTP_POST, [](AsyncWebServerRequest* req) {
        JsonDocument doc;
        JsonArray arr = doc.to<JsonArray>();
        queueStore.getUnsent(arr, 50);
        String out;
        serializeJson(doc, out);
        req->send(200, "application/json", out);
    });

    // POST /api/queue/ack — {"seq_up_to": 1042}
    // Uses setPendingAck() — never touches flash inside async_tcp.
    // commsTask calls queueStore.processPending() to do the actual LittleFS write.
    _http.addHandler(new AsyncCallbackJsonWebHandler("/api/queue/ack",
        [](AsyncWebServerRequest* req, JsonVariant& json) {
            uint32_t seq = json["seq_up_to"] | 0u;
            if (seq == 0) {
                req->send(400, "application/json", "{\"ok\":false,\"error\":\"missing seq_up_to\"}");
                return;
            }
            queueStore.setPendingAck(seq);
            req->send(200, "application/json", "{\"ok\":true}");
        }));

    // POST /api/command — same payload as BLE AA05
    _http.addHandler(new AsyncCallbackJsonWebHandler("/api/command",
        [](AsyncWebServerRequest* req, JsonVariant& json) {
            String body;
            serializeJson(json, body);
            char resultBuf[128];
            handlePinCommand(body.c_str(), resultBuf, sizeof(resultBuf));

            // Deferred commands: send response first, then act
            bool isReboot = (strcmp(json["cmd"] | "", "reboot") == 0);
            bool isFactoryReset = (strcmp(json["cmd"] | "", "factory_reset") == 0);

            req->send(200, "application/json", resultBuf);

            delay(500);
            if (isFactoryReset) {
                Serial.println("[API] Factory reset requested — clearing NVS and queue...");
                // Clear all NVS data
                nvs_flash_erase();
                // Clear queue
                queueStore.clear();
                delay(500);
                ESP.restart();
            } else if (isReboot) {
                ESP.restart();
            }
        }));

    // GET /api/ota/check — returns current version; app provides update URL
    _http.on("/api/ota/check", HTTP_GET, [](AsyncWebServerRequest* req) {
        char buf[128];
        snprintf(buf, sizeof(buf),
                 "{\"current\":\"%s\",\"node_id\":\"%s\"}",
                 config.d.firmware_version, config.d.node_id);
        req->send(200, "application/json", buf);
    });

    // POST /api/ota/start — {"url":"http://..."}
    _http.addHandler(new AsyncCallbackJsonWebHandler("/api/ota/start",
        [](AsyncWebServerRequest* req, JsonVariant& json) {
            const char* url = json["url"] | "";
            if (!url || strlen(url) == 0) {
                req->send(400, "application/json", "{\"ok\":false,\"error\":\"missing url\"}");
                return;
            }
            strlcpy(_otaUrl, url, sizeof(_otaUrl));
            req->send(202, "application/json", "{\"ok\":true,\"status\":\"update_started\"}");
            xTaskCreate(otaTask, "ota", 8192, NULL, 5, NULL);
        }));

    // Catch-all 404
    _http.onNotFound([](AsyncWebServerRequest* req) {
        req->send(404, "application/json", "{\"error\":\"not_found\"}");
    });
}
