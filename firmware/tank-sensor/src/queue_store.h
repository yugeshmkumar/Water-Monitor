#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>

// Fixed-size binary entry stored in LittleFS circular buffer.
struct __attribute__((packed)) QueueEntry {
    uint32_t seq;
    uint32_t ts;          // seconds since boot
    float    distance_cm;
    uint8_t  level_pct;
    uint8_t  sensor_ok;
    uint8_t  sent;
    uint8_t  _pad;        // alignment to 16 bytes
};
static_assert(sizeof(QueueEntry) == 16, "QueueEntry must be 16 bytes");

class QueueStore {
public:
    void     begin();
    void     write(float dist, uint8_t pct);
    uint16_t pendingCount();
    void     getUnsent(JsonArray out, uint16_t max = 50);
    void     ackUpTo(uint32_t seq);
    // Called from async_tcp handler — just records the seq, returns immediately.
    // Call processPending() from a non-async task to do the actual flash write.
    void     setPendingAck(uint32_t seq);
    void     processPending();
    void     clear();

private:
    static const uint16_t MAX_ENTRIES = 2000;
    static const char*    FILE_PATH;

    uint32_t _nextSeq    = 1;
    uint16_t _count      = 0;
    uint16_t _pending    = 0;
    uint16_t _head       = 0;
    uint16_t _tail       = 0;
    volatile uint32_t _pendingAck = 0;  // set by async_tcp, consumed by commsTask

    void _loadMeta();
    void _saveMeta();
    void _ensureFile();
    bool _readEntry(uint16_t idx, QueueEntry& e);
    void _writeEntry(uint16_t idx, const QueueEntry& e);
};

extern QueueStore queueStore;
