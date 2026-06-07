# Firmware Changelog

All notable changes to the Water Monitor firmware are documented here.

## [Phase 1B - Current] - 2026-06-07

### 🔴 Critical Fixes
- **nvs_flash_erase() error checking** — Factory reset now checks NVS erase status before restarting. If erase fails, device returns HTTP 500 and does not restart (prevents NVS corruption).

### 🟡 Important Fixes
- **Persistent queue file deletion** — Factory reset now properly deletes `/q.bin` file from LittleFS. Previously only cleared RAM pointers, leaving 2000+ stale entries on flash.

### 🟠 Minor Fixes
- **Main task watchdog registration** — Main task now registered with watchdog for complete health monitoring. Previously fed watchdog but wasn't tracked.
- **Float math consistency** — Changed `fabs()` to `fabsf()` for embedded system best practices.

### ✨ Features
- **Dual poll intervals** — Added `test_poll_interval_s` config for faster polling during development (default 3s vs 10s production).
  - **API Change**: BLE config characteristic now sends both `poll_interval_s` and `test_poll_interval_s` independently
  - iOS app must be updated to handle both fields
  - REST API unchanged (still supports partial updates)

- **Factory reset endpoint** — New POST `/api/cmd {"cmd": "factory_reset"}` endpoint completely resets device to factory defaults.

- **Temporal filtering** — Replaced Kalman filter with statistical ML validator (dual-criterion: mean + trend prediction).

### 🔧 Technical Details

#### BLE API Contract Change
**Old BLE Config Format (AA03 characteristic):**
```json
{
  "poll_interval_s": 10,  // either normal or test value depending on testing_mode
  "testing_mode": false
}
```

**New BLE Config Format (AA03 characteristic):**
```json
{
  "poll_interval_s": 10,       // always the normal polling interval
  "testing_mode": false,       // testing mode flag
  "test_poll_interval_s": 3    // always present (separate field)
}
```

**Migration Notes:**
- iOS app must handle both poll interval fields independently
- `poll_interval_s` is used during normal operation
- `test_poll_interval_s` is used when `testing_mode` is true
- Existing iOS apps that don't handle `test_poll_interval_s` will ignore it (safe)
- Any iOS app that strict-parses the JSON might fail until updated

#### Factory Reset Behavior
The factory reset endpoint (`POST /api/cmd {"cmd": "factory_reset"}`) now performs a complete device reset:

1. **NVS Erasure** — All configuration erased
   - Tank calibration reset
   - WiFi credentials cleared
   - All preferences reset to defaults
   - **Error handling**: If NVS erase fails, returns HTTP 500 and does NOT restart

2. **Queue Deletion** — All pending measurements cleared
   - RAM queue pointers reset to 0
   - Persistent `/q.bin` file deleted from LittleFS
   - Empty queue file recreated

3. **Device Restart** — After both operations complete successfully

**Testing**: Manual factory reset via REST API confirms NVS erased and queue file deleted.

#### Watchdog Registration Complete
All tasks now properly registered with watchdog:
- `sensor` — 15 second deadline (reads every 10s + margin)
- `comms` — 20 second deadline (WiFi retry every 50s + margin)
- `ble` — 10 second deadline (BLE advertising + margin)
- `health` — 60 second deadline (health check every 60s + margin)
- `main` — 15 second deadline (idle loop with periodic feeds)

Health monitoring can now detect if any task stops feeding the watchdog.

### 📊 Code Quality Impact
- **Coverage**: All critical error paths now checked
- **Reliability**: Factory reset is now atomic (both NVS and queue cleared)
- **Diagnostics**: Main task health now tracked (previously invisible)
- **Consistency**: Float math uses appropriate types

### ⚠️ Known Limitations
- Queue file deletion is synchronous (takes <100ms, safe for async context but blocks HTTP response slightly)
- NVS erase is hardware-dependent (may take 100-500ms on some flash modules)
- No rollback if queue deletion fails after NVS erase (rare, but theoretically possible)

## Previous Phases

[Earlier release notes would go here if applicable]
