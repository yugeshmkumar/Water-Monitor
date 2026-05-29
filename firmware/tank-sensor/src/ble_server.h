#pragma once
#include <NimBLEDevice.h>

// Service and characteristic UUIDs.
// Service UUID matches the architecture spec; chars use the same Bluetooth base expansion.
#define BLE_SVC_UUID  "0000AA01-0000-1000-8000-00805F9B34FB"
#define BLE_CHR_AA01  ((uint16_t)0xAA01)  // Level reading  — Read, Notify
#define BLE_CHR_AA02  ((uint16_t)0xAA02)  // Device status  — Read, Notify
#define BLE_CHR_AA03  ((uint16_t)0xAA03)  // Config read    — Read
#define BLE_CHR_AA04  ((uint16_t)0xAA04)  // Config write   — Write
#define BLE_CHR_AA05  ((uint16_t)0xAA05)  // Command        — Write
#define BLE_CHR_AA06  ((uint16_t)0xAA06)  // Command result — Read, Notify

class BLEServerWrapper {
public:
    void begin();
    void loop();  // updates AA03 when config changes; restarts advertising if needed

    // Called from sensorTask after each successful reading
    void notifyLevel(float distCM, uint8_t levelPct, uint32_t ts);
    // Called from commsTask to push status updates
    void notifyStatus(bool wifiOk, bool sensorOk, int8_t rssi, uint16_t queueDepth);
    // Called from command handler to push AA06 result
    void sendCommandResult(const char* resultJson);

private:
    NimBLEServer*         _server    = nullptr;
    NimBLECharacteristic* _charAA01  = nullptr;
    NimBLECharacteristic* _charAA02  = nullptr;
    NimBLECharacteristic* _charAA03  = nullptr;
    NimBLECharacteristic* _charAA04  = nullptr;
    NimBLECharacteristic* _charAA05  = nullptr;
    NimBLECharacteristic* _charAA06  = nullptr;
    bool                  _configDirty = false;

    void _updateConfigChar();
    friend class CfgWriteCallbacks;
    friend class CmdCallbacks;
    friend class SrvCallbacks;
};

extern BLEServerWrapper bleServer;
