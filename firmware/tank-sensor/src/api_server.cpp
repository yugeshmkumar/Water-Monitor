#include "api_server.h"
#include "config.h"
#include "sensor.h"
#include "queue_store.h"
#include "state.h"
#include "constants.h"
#include <ArduinoJson.h>
#include <AsyncJson.h>
#include <ESPmDNS.h>
#include <ElegantOTA.h>
#include <WiFi.h>

// HTTPUpdate for OTA-from-URL (requires WiFiClient)
#include <HTTPUpdate.h>

ApiServer apiServer;

// ─────────────────────────────────────────────────────────────
// OTA-from-URL task
// ─────────────────────────────────────────────────────────────

static char _otaUrl[OTA_URL_MAX_LEN] = "";

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
        MDNS.addService("http", "tcp", HTTP_SERVER_PORT);
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
    if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(SEMAPHORE_TIMEOUT_MS))) {
        snap = gState;
        xSemaphoreGive(gStateMutex);
    }

    // Send complete status matching /api/status format for consistency
    char buf[HTTP_RESPONSE_BUFFER_SIZE];
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
        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(SEMAPHORE_TIMEOUT_MS))) {
            snap = gState;
            xSemaphoreGive(gStateMutex);
        }
        char buf[HTTP_RESPONSE_BUFFER_SIZE];
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
        if (xSemaphoreTake(gStateMutex, pdMS_TO_TICKS(SEMAPHORE_TIMEOUT_MS))) {
            snap = gState;
            xSemaphoreGive(gStateMutex);
        }
        char buf[HTTP_RESPONSE_BUFFER_SIZE];
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
        req->send(HTTP_STATUS_OK, "application/json", buf);
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
            bool ok = config.applyPartialJson(body.c_str());
            if (ok) resetSensorFilter();   // tank range may have changed
            req->send(ok ? HTTP_STATUS_OK : HTTP_STATUS_BAD_REQUEST, "application/json",
                      ok ? "{\"ok\":true}" : "{\"ok\":false,\"error\":\"parse_error\"}");
        }));

    // POST /api/queue/flush — return up to 50 unsent entries
    _http.on("/api/queue/flush", HTTP_POST, [](AsyncWebServerRequest* req) {
        JsonDocument doc;
        JsonArray arr = doc.to<JsonArray>();
        queueStore.getUnsent(arr, QUEUE_FLUSH_MAX_ENTRIES);
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
                req->send(HTTP_STATUS_BAD_REQUEST, "application/json", "{\"ok\":false,\"error\":\"missing seq_up_to\"}");
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
            char resultBuf[COMMAND_RESULT_BUFFER_SIZE];
            handlePinCommand(body.c_str(), resultBuf, sizeof(resultBuf));

            // Deferred reboot: send response first
            bool isReboot = (strcmp(json["cmd"] | "", "reboot") == 0);
            req->send(200, "application/json", resultBuf);
            if (isReboot) {
                delay(REBOOT_DELAY_MS);
                ESP.restart();
            }
        }));

    // GET /api/ota/check — returns current version; app provides update URL
    _http.on("/api/ota/check", HTTP_GET, [](AsyncWebServerRequest* req) {
        char buf[VERSION_BUFFER_SIZE];
        snprintf(buf, sizeof(buf),
                 "{\"current\":\"%s\",\"node_id\":\"%s\"}",
                 config.d.firmware_version, config.d.node_id);
        req->send(HTTP_STATUS_OK, "application/json", buf);
    });

    // POST /api/ota/start — {"url":"http://..."}
    _http.addHandler(new AsyncCallbackJsonWebHandler("/api/ota/start",
        [](AsyncWebServerRequest* req, JsonVariant& json) {
            const char* url = json["url"] | "";
            if (!url || strlen(url) == 0) {
                req->send(HTTP_STATUS_BAD_REQUEST, "application/json", "{\"ok\":false,\"error\":\"missing url\"}");
                return;
            }
            strlcpy(_otaUrl, url, sizeof(_otaUrl));
            req->send(HTTP_STATUS_ACCEPTED, "application/json", "{\"ok\":true,\"status\":\"update_started\"}");
            xTaskCreate(otaTask, "ota", OTA_TASK_STACK_SIZE, NULL, OTA_TASK_PRIORITY, NULL);
        }));

    // Catch-all 404
    _http.onNotFound([](AsyncWebServerRequest* req) {
        req->send(HTTP_STATUS_NOT_FOUND, "application/json", "{\"error\":\"not_found\"}");
    });
}
