#include "ble_server.h"
#include "config.h"
#include "sensor.h"
#include "state.h"
#include <ArduinoJson.h>
#include <WiFi.h>


BLEServerWrapper bleServer;

// ─────────────────────────────────────────────────────────────
// Callbacks (file-local)
// ─────────────────────────────────────────────────────────────

class SrvCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer*, NimBLEConnInfo&) override {
        Serial.println("[BLE] Client connected");
    }
    void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int) override {
        Serial.println("[BLE] Client disconnected — restarting advertising");
        NimBLEDevice::startAdvertising();
    }
};

class CfgReadCallbacks : public NimBLECharacteristicCallbacks {
    void onRead(NimBLECharacteristic* c, NimBLEConnInfo&) override {
        // Build minimal AA03 JSON (avoid 512-byte characteristic limit)
        // Full config available via REST API /api/config
        char buf[480];
        snprintf(buf, sizeof(buf),
                 "{\"tank_empty_cm\":%.1f,\"tank_full_cm\":%.1f,"
                 "\"tank_volume_l\":%u,\"node_id\":\"%s\","
                 "\"poll_interval_s\":%u,\"testing_mode\":%s,\"test_poll_interval_s\":%u,"
                 "\"ip\":\"%s\",\"mac\":\"%s\",\"hostname\":\"%s.local\","
                 "\"firmware_version\":\"%s\"}",
                 config.d.tank_empty_cm, config.d.tank_full_cm,
                 config.d.tank_volume_l, config.d.node_id,
                 config.d.poll_interval_s,
                 config.d.testing_mode ? "true" : "false",
                 config.d.test_poll_interval_s,
                 WiFi.localIP().toString().c_str(),
                 WiFi.macAddress().c_str(),
                 config.d.node_id,
                 config.d.firmware_version);
        Serial.printf("[BLE] AA03 read request, sending %zu bytes\n", strlen(buf));
        c->setValue(buf);
        Serial.printf("[BLE] AA03 sent: %s\n", buf);
    }
};

class CfgWriteCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override {
        std::string val = c->getValue();
        if (val.empty()) return;
        if (config.applyPartialJson(val.c_str())) {
            Serial.println("[BLE] Config updated via AA04");
            bleServer._configDirty = true;
            resetSensorFilter();   // tank range may have changed — clear stale history
        } else {
            Serial.println("[BLE] AA04 write: JSON parse error");
        }
    }
};

class CmdCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override {
        std::string val = c->getValue();
        if (val.empty()) return;

        char resultBuf[128];
        handlePinCommand(val.c_str(), resultBuf, sizeof(resultBuf));
        bleServer.sendCommandResult(resultBuf);

        // Deferred reboot — send result first, then restart
        JsonDocument doc;
        if (deserializeJson(doc, val) == DeserializationError::Ok) {
            if (strcmp(doc["cmd"] | "", "reboot") == 0) {
                delay(500);
                ESP.restart();
            }
        }
    }
};

// ─────────────────────────────────────────────────────────────
// BLEServerWrapper
// ─────────────────────────────────────────────────────────────

void BLEServerWrapper::begin() {
    NimBLEDevice::init(config.d.node_id);
    NimBLEDevice::setMTU(517);  // Enable larger packets for config transfer

    _server = NimBLEDevice::createServer();
    _server->setCallbacks(new SrvCallbacks());

    NimBLEService* svc = _server->createService(NimBLEUUID(BLE_SVC_UUID));

    _charAA01 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA01),
                    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

    _charAA02 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA02),
                    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

    _charAA03 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA03),
                    NIMBLE_PROPERTY::READ);
    _charAA03->setCallbacks(new CfgReadCallbacks());

    _charAA04 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA04),
                    NIMBLE_PROPERTY::WRITE);
    _charAA04->setCallbacks(new CfgWriteCallbacks());

    _charAA05 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA05),
                    NIMBLE_PROPERTY::WRITE);
    _charAA05->setCallbacks(new CmdCallbacks());

    _charAA06 = svc->createCharacteristic(NimBLEUUID(BLE_CHR_AA06),
                    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

    _server->start();

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setName(config.d.node_id);
    adv->addServiceUUID(NimBLEUUID(BLE_SVC_UUID));
    adv->start();

    Serial.printf("[BLE] Advertising as \"%s\"\n", config.d.node_id);
}

void BLEServerWrapper::loop() {
    if (_configDirty) {
        _updateConfigChar();
        _configDirty = false;
    }
}

void BLEServerWrapper::notifyLevel(float distCM, uint8_t levelPct, uint32_t ts) {
    if (!_charAA01 || !_server->getConnectedCount()) return;

    char buf[80];
    snprintf(buf, sizeof(buf),
             "{\"level_pct\":%u,\"distance_cm\":%.1f,\"ts\":%lu}",
             levelPct, distCM, (unsigned long)ts);
    _charAA01->setValue(buf);
    _charAA01->notify();
}

void BLEServerWrapper::notifyStatus(bool wifiOk, bool sensorOk,
                                    int8_t rssi, uint16_t queueDepth) {
    if (!_charAA02 || !_server->getConnectedCount()) return;

    char buf[96];
    snprintf(buf, sizeof(buf),
             "{\"wifi_ok\":%s,\"sensor_ok\":%s,\"rssi\":%d,\"queue_depth\":%u}",
             wifiOk ? "true" : "false",
             sensorOk ? "true" : "false",
             rssi, queueDepth);
    _charAA02->setValue(buf);
    _charAA02->notify();
}

void BLEServerWrapper::sendCommandResult(const char* resultJson) {
    if (!_charAA06) return;
    _charAA06->setValue(resultJson);
    _charAA06->notify();
}

void BLEServerWrapper::_updateConfigChar() {
    if (!_charAA03) return;
    // Send minimal config over BLE (rest available via REST API)
    // Avoid 512-byte characteristic size limit by sending only essential fields
    char buf[320];
    snprintf(buf, sizeof(buf),
             "{\"tank_empty_cm\":%.1f,\"tank_full_cm\":%.1f,"
             "\"tank_volume_l\":%u,\"node_id\":\"%s\","
             "\"poll_interval_s\":%u,\"testing_mode\":%s,\"test_poll_interval_s\":%u}",
             config.d.tank_empty_cm, config.d.tank_full_cm,
             config.d.tank_volume_l, config.d.node_id,
             config.d.poll_interval_s,
             config.d.testing_mode ? "true" : "false",
             config.d.test_poll_interval_s);
    _charAA03->setValue(buf);
}
