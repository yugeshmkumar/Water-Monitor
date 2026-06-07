#include "queue_store.h"
#include <Preferences.h>
#include <LittleFS.h>

const char* QueueStore::FILE_PATH = "/q.bin";
static const size_t ENTRY_SIZE    = sizeof(QueueEntry);  // 16 bytes

QueueStore queueStore;

// ─────────────────────────────────────────────────────────────
// Public
// ─────────────────────────────────────────────────────────────

void QueueStore::begin() {
    _loadMeta();
    _ensureFile();
}

void QueueStore::write(float dist, uint8_t pct) {
    QueueEntry e = {};
    e.seq         = _nextSeq++;
    e.ts          = (uint32_t)(millis() / 1000);
    e.distance_cm = dist;
    e.level_pct   = pct;
    e.sensor_ok   = 1;
    e.sent        = 0;

    _writeEntry(_tail, e);
    _tail = (_tail + 1) % MAX_ENTRIES;

    if (_count < MAX_ENTRIES) {
        _count++;
    } else {
        // Ring overflow: drop the oldest entry, adjust pending count accordingly
        QueueEntry oldest;
        uint16_t droppedIdx = _head;
        _head = (_head + 1) % MAX_ENTRIES;
        if (_readEntry(droppedIdx, oldest) && !oldest.sent) {
            _pending = (_pending > 0) ? _pending - 1 : 0;
        }
    }
    _pending++;
    _saveMeta();
}

uint16_t QueueStore::pendingCount() {
    return _pending;
}

void QueueStore::getUnsent(JsonArray out, uint16_t max) {
    File f = LittleFS.open(FILE_PATH, "r");
    if (!f) return;

    // Snapshot _pendingAck so entries that have been acked-but-not-yet-flushed
    // are not re-sent to the client on the very next flush call.
    uint32_t pendingAck = _pendingAck;

    uint16_t found = 0;
    uint16_t idx   = _head;

    for (uint16_t i = 0; i < _count && found < max; i++) {
        QueueEntry e;
        f.seek((size_t)idx * ENTRY_SIZE);
        if (f.read((uint8_t*)&e, ENTRY_SIZE) == ENTRY_SIZE
            && !e.sent
            && e.seq > pendingAck) {   // skip entries already pending-ack
            JsonObject obj     = out.add<JsonObject>();
            obj["seq"]         = e.seq;
            obj["ts"]          = e.ts;
            obj["distance_cm"] = serialized(String(e.distance_cm, 1));
            obj["level_pct"]   = e.level_pct;
            obj["sensor_ok"]   = (bool)e.sensor_ok;
            found++;
        }
        idx = (idx + 1) % MAX_ENTRIES;
    }
    f.close();
}

void QueueStore::ackUpTo(uint32_t seq) {
    // Open file once for the entire operation — each close flushes LittleFS dirty pages,
    // so 50 individual _writeEntry() calls = 50 potential flash erase cycles.
    // One open/close = one flush, which is orders of magnitude faster.
    File f = LittleFS.open(FILE_PATH, "r+");
    if (!f) return;

    uint16_t acked = 0;
    uint16_t idx   = _head;

    for (uint16_t i = 0; i < _count; i++) {
        QueueEntry e;
        size_t offset = (size_t)idx * ENTRY_SIZE;
        f.seek(offset);
        if (f.read((uint8_t*)&e, ENTRY_SIZE) == ENTRY_SIZE && e.seq <= seq && !e.sent) {
            e.sent = 1;
            f.seek(offset);
            f.write((const uint8_t*)&e, ENTRY_SIZE);
            acked++;
        }
        idx = (idx + 1) % MAX_ENTRIES;
    }

    // Advance head past consecutive sent entries using the same open file handle
    while (_count > 0) {
        QueueEntry e;
        f.seek((size_t)_head * ENTRY_SIZE);
        if (f.read((uint8_t*)&e, ENTRY_SIZE) != ENTRY_SIZE || !e.sent) break;
        _head = (_head + 1) % MAX_ENTRIES;
        _count--;
    }

    f.close();  // single flush — all modified pages committed in one go

    _pending = (_pending >= acked) ? _pending - acked : 0;
    _saveMeta();
}

void QueueStore::setPendingAck(uint32_t seq) {
    // Called from async_tcp handler — must return immediately without touching flash.
    _pendingAck = seq;
}

void QueueStore::processPending() {
    if (_pendingAck == 0) return;
    uint32_t seq = _pendingAck;
    _pendingAck  = 0;
    ackUpTo(seq);
}

void QueueStore::clear() {
    _head    = 0;
    _tail    = 0;
    _count   = 0;
    _pending = 0;
    _saveMeta();

    // Delete the persistent queue file to ensure true factory reset
    if (LittleFS.exists(FILE_PATH)) {
        LittleFS.remove(FILE_PATH);
        Serial.println("[Queue] Deleted persistent queue file (/q.bin)");
    }

    // Recreate empty queue file
    _ensureFile();
}

// ─────────────────────────────────────────────────────────────
// Private
// ─────────────────────────────────────────────────────────────

void QueueStore::_loadMeta() {
    Preferences p;
    p.begin("qmeta", true);
    _nextSeq = p.getUInt("nseq", 1);
    _head    = (uint16_t)p.getUInt("head", 0);
    _tail    = (uint16_t)p.getUInt("tail", 0);
    _count   = (uint16_t)p.getUInt("cnt",  0);
    _pending = (uint16_t)p.getUInt("pend", 0);
    p.end();
}

void QueueStore::_saveMeta() {
    Preferences p;
    p.begin("qmeta", false);
    p.putUInt("nseq", _nextSeq);
    p.putUInt("head", _head);
    p.putUInt("tail", _tail);
    p.putUInt("cnt",  _count);
    p.putUInt("pend", _pending);
    p.end();
}

void QueueStore::_ensureFile() {
    if (LittleFS.exists(FILE_PATH)) return;

    File f = LittleFS.open(FILE_PATH, "w", true);
    if (!f) {
        Serial.println("[Queue] Failed to create queue file");
        return;
    }
    QueueEntry empty = {};
    for (uint16_t i = 0; i < MAX_ENTRIES; i++) {
        f.write((const uint8_t*)&empty, ENTRY_SIZE);
    }
    f.close();
    Serial.printf("[Queue] Allocated %u entries (%u KB)\n",
                  MAX_ENTRIES, (uint32_t)(MAX_ENTRIES * ENTRY_SIZE / 1024));
}

bool QueueStore::_readEntry(uint16_t idx, QueueEntry& e) {
    File f = LittleFS.open(FILE_PATH, "r");
    if (!f) return false;
    f.seek((size_t)idx * ENTRY_SIZE);
    bool ok = (f.read((uint8_t*)&e, ENTRY_SIZE) == ENTRY_SIZE);
    f.close();
    return ok;
}

void QueueStore::_writeEntry(uint16_t idx, const QueueEntry& e) {
    File f = LittleFS.open(FILE_PATH, "r+");
    if (!f) return;
    f.seek((size_t)idx * ENTRY_SIZE);
    f.write((const uint8_t*)&e, ENTRY_SIZE);
    f.close();
}
