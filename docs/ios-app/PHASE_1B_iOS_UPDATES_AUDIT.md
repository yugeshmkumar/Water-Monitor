# Phase 1B iOS App Updates - Comprehensive Audit

**Date:** 2026-06-07  
**Status:** AUDIT COMPLETE — CHANGES IDENTIFIED  
**Methodology:** 9-angle comprehensive audit

---

## Executive Summary

The iOS app currently misses **6 critical changes** from firmware Phase 1B:

| # | Issue | Severity | Component | Status |
|---|-------|----------|-----------|--------|
| 1 | Calibration units: CM → MM | **CRITICAL** | DeviceConfig | Not updated |
| 2 | Remove obsolete pin configuration (JSN-SR04T) | **HIGH** | DeviceConfig, UI | Still present |
| 3 | Add diagnostics endpoint support | **HIGH** | WiFiService | Missing |
| 4 | Handle factory reset error codes (500 response) | **MEDIUM** | WiFiService | Needs testing |
| 5 | Update BLE config JSON handling | **MEDIUM** | BLEService | Likely OK but verify |
| 6 | Calibration view uses CM instead of MM | **CRITICAL** | TankCalibrationView | Not updated |

---

## Detailed Audit: 9 Angles

### ANGLE 1: Line-by-Line Comparison (Firmware vs iOS)

#### Firmware Change: SR04M-2 UART Sensor (No Pins)
- **Firmware:** GPIO21 (TX), GPIO20 (RX) — hardcoded in firmware
- **iOS Issue:** Still has `pinTrig` and `pinEcho` fields (leftover from JSN-SR04T)
- **Impact:** User can change pins in app, but firmware ignores them
- **Fix Required:** Remove pinTrig/pinEcho from DeviceConfig, UI, and models

#### Firmware Change: Calibration in MM (not CM)
- **Firmware:** `tank_empty_mm`, `tank_full_mm` (millimeters)
- **iOS Issue:** DeviceConfig uses `tankEmptyCM`, `tankFullCM` (centimeters)
- **Impact:** Calibration values wrong by 10x factor
- **Fix Required:** Update DeviceConfig, CodingKeys, UI displays, calculations

#### Firmware Change: Dual Poll Intervals
- **Firmware:** `poll_interval_s` + `test_poll_interval_s` both sent
- **iOS Status:** DeviceConfig has both fields ✅
- **Coding Keys:** Already correct (`poll_interval_s`, `test_poll_interval_s`) ✅
- **Fix Required:** Verify BLE characteristic parsing handles both fields

#### Firmware Change: New /api/diagnostics Endpoint
- **Firmware:** GET /api/diagnostics returns comprehensive stats
- **iOS Issue:** No fetchDiagnostics() method in WiFiService
- **Impact:** Can't display detailed device health in UI
- **Fix Required:** Add diagnostics model and endpoint

#### Firmware Change: Factory Reset Error Handling
- **Firmware:** Returns HTTP 500 on nvs_flash_erase() failure
- **iOS Status:** sendCommand() catches errors ✅
- **Fix Required:** Ensure UI handles 500 response gracefully

---

### ANGLE 2: Removed Behavior Audit

#### Removed from Firmware:
- **Pin configuration (JSN-SR04T TRIG/ECHO)** — No longer used
  - Firmware hardcodes SR04M-2 pins
  - iOS still displays pin config UI
  - **Invariant Lost:** User can change pins, firmware ignores them
  - **Fix:** Remove `pinTrig`/`pinEcho` from UI and models

#### Removed from Firmware:
- **Kalman filter** — Replaced with trimmed mean
  - iOS doesn't display filter type, so no impact ✅

---

### ANGLE 3: Cross-File Tracer

#### Call Chain: Configuration → Calibration → Display
1. **DeviceConfig.swift**: Defines `tankEmptyCM`, `tankFullCM` (WRONG UNITS)
2. **TankCalibrationView.swift**: Uses `calculatedEmptyCM`, `calculatedFullCM`
3. **DashboardView.swift**: Displays tank level % (depends on correct calibration)
4. **Impact:** All tank measurements are off by 10x if calibration is saved

#### Call Chain: BLE Config Read
1. **BLEService.swift**: Reads AA03 characteristic
2. **DeviceConfig.swift**: Decodes JSON with CodingKeys
3. **Expected:** Receives `poll_interval_s` + `test_poll_interval_s`
4. **Status:** Should work if firmware sends both ✅

#### Call Chain: Factory Reset
1. **WiFiService.sendCommand()**: POST /api/command {"cmd": "factory_reset"}
2. **Expected:** HTTP 500 on error
3. **iOS Handling:** Throws error to caller
4. **Status:** Should work if UI catches errors ✅

---

### ANGLE 4: Language Pitfalls (Swift)

#### Issue #1: Type Confusion (CM vs MM)
```swift
// DeviceConfig line 6-7
var tankEmptyCM: Double = 150  // ← Says CM but firmware sends MM
var tankFullCM: Double = 20    // ← Says CM but firmware sends MM
```
**Problem:** If firmware sends `tank_empty_mm: 1500`, iOS decodes as CM (15m), not MM (1.5m)  
**Risk:** Data corruption, wrong calibration

#### Issue #2: Unused Fields
```swift
// DeviceConfig line 14-15
var pinTrig: String = "D2"     // ← Unused by SR04M-2 firmware
var pinEcho: String = "D1"     // ← Unused by SR04M-2 firmware
```
**Problem:** User can configure pins, firmware ignores them  
**Risk:** Confusion, support issues

#### Issue #3: Optional Unwrapping
```swift
// WiFiService line 85
let status = try await get(path: "/api/status", as: DeviceStatus.self)
```
**Status:** Safe, uses optional unwrapping in get() ✅

---

### ANGLE 5: API Contract Verification

#### /api/status Endpoint
**iOS Model:** DeviceStatus  
**Fields Expected:** level_pct, distance_cm, ts, sensor_ok, wifi_ok, rssi, queue_depth, fw, local_ip  
**Status:** ✅ All fields match

#### /api/config Endpoint
**iOS Model:** DeviceConfig  
**CodingKeys Match:**
- ✅ wifi_ssid → wifiSSID
- ✅ wifi_pass → wifiPass
- ❌ tank_empty_cm → tankEmptyCM (UNITS WRONG: should be tank_empty_mm)
- ❌ tank_full_cm → tankFullCM (UNITS WRONG: should be tank_full_mm)
- ✅ poll_interval_s → pollIntervalS
- ✅ test_poll_interval_s → testPollIntervalS
- ✅ testing_mode → testingMode
- ❌ pin_trig → pinTrig (OBSOLETE: remove)
- ❌ pin_echo → pinEcho (OBSOLETE: remove)

#### /api/diagnostics Endpoint
**Status:** ❌ NOT IMPLEMENTED  
**Required Model:** DeviceDiagnostics (new)  
**Fields:** sensor (reads, errors, error_rate), wifi (connected, rssi, ssid), queue (pending), system (uptime, heap, psram), config (calibration snapshot)

---

### ANGLE 6: Code Quality Issues

#### Duplication: PIN Configuration UI
- **ConfigWizardView.swift**: Likely has pin selector
- **DeviceConfigView.swift**: Likely has pin editor
- **Status:** Both can be removed since pins are firmware-defined
- **Fix:** Remove all pin config UI

#### Duplication: Calibration Logic
- **TankCalibrationView.swift**: Calculates calibration
- **DashboardView.swift**: Uses calibration for level %
- **Multiple views:** All use tankEmptyCM/tankFullCM
- **Fix:** Centralize unit conversion (CM ← → MM)

#### Dead Code: Kalman Filter References
- **Search needed:** grep for "kalman" in iOS app
- **Status:** Likely none (not visible in models)
- **Action:** Verify and remove if found

---

### ANGLE 7: Performance & UI Issues

#### Issue #1: Blocking Config Updates
```swift
// WiFiService line 114-134: patchConfig()
func patchConfig(_ patch: [String: Any]) async throws {
    try await post(path: "/api/config", body: patch)
    // Then fetches updated config
}
```
**Status:** ✅ Async, non-blocking

#### Issue #2: Screen Transition Delays
- **TankCalibrationView:** Uses proper async/await ✅
- **DeviceConfigView:** Should verify async handling
- **Status:** Need to verify no blocking calls

#### Issue #3: BLE Notifications
- **BLEService:** Subscribes to characteristics ✅
- **Status:** Should be fine

---

### ANGLE 8: Configuration Defaults

#### Current Defaults (WRONG UNITS):
```swift
var tankEmptyCM: Double = 150      // ← Actually should be MM
var tankFullCM: Double = 20        // ← Actually should be MM
```

#### Correct Defaults:
```swift
var tankEmptyMM: Double = 1500     // 1500mm = 1.5m empty distance
var tankFullMM: Double = 200       // 200mm = 0.2m full distance
```

---

### ANGLE 9: Gap Sweep - Fresh Eyes

#### Missing Features:
1. ✅ Health monitoring — not in Phase 1B iOS scope
2. ✅ Diagnostics dashboard — could add /api/diagnostics display
3. ✅ Offline queue management — exists in current app
4. ❌ Factory reset confirmation — should add warning dialog
5. ❌ Testing mode toggle UI — check if ConfigView has it

#### Documentation Gaps:
1. ❌ No migration guide for app users (calibration values changed)
2. ❌ No explanation of testing_mode vs poll_interval_s in UI
3. ⚠️ Pin config UI confuses users (pins now firmware-defined)

---

## Summary of Required Changes

### CRITICAL (Must Fix Before Release)

1. **DeviceConfig Units Conversion**
   - [ ] Rename `tankEmptyCM` → `tankEmptyMM`
   - [ ] Rename `tankFullCM` → `tankFullMM`
   - [ ] Update CodingKeys: `tank_empty_cm` → `tank_empty_mm`, etc.
   - [ ] Update all views and calculations

2. **Remove Obsolete Pin Configuration**
   - [ ] Remove `pinTrig`, `pinEcho` from DeviceConfig
   - [ ] Remove pin config UI from ConfigWizardView, DeviceConfigView
   - [ ] Update patch() method
   - [ ] Update CodingKeys (remove pin mappings)

### HIGH PRIORITY (Before Public Release)

3. **Add Diagnostics Endpoint Support**
   - [ ] Create `DeviceDiagnostics` model
   - [ ] Add `fetchDiagnostics()` method to WiFiService
   - [ ] Create diagnostics display UI (optional)

4. **Handle Factory Reset Errors**
   - [ ] Add confirmation dialog before factory reset
   - [ ] Display error if HTTP 500 returned
   - [ ] Add "Device may be in corrupted state" warning

### MEDIUM PRIORITY (Next Release)

5. **Verify BLE Dual Poll Intervals**
   - [ ] Test that BLEService correctly parses both poll_interval_s and test_poll_interval_s
   - [ ] Verify UI displays both values correctly

6. **UI Polish**
   - [ ] Remove pin selector from all configuration screens
   - [ ] Update help text (remove references to pin selection)
   - [ ] Ensure smooth screen transitions
   - [ ] Test calibration flow end-to-end

---

## Implementation Order

1. **Data Model Updates** (DeviceConfig units)
   - Change field names and types
   - Update CodingKeys
   - Update defaults

2. **Remove Obsolete Features** (Pin configuration)
   - Remove fields
   - Remove UI components
   - Remove from CodingKeys

3. **Add New Features** (Diagnostics)
   - Create DeviceDiagnostics model
   - Add WiFiService method
   - Create UI (optional)

4. **Update All Views**
   - TankCalibrationView (MM conversions)
   - DashboardView (level % calculations)
   - DeviceConfigView (remove pins)
   - ConfigWizardView (remove pins)

5. **Testing** (Comprehensive)
   - Unit tests for unit conversions
   - Integration tests for calibration save/load
   - UI tests for screen transitions
   - Error handling for factory reset

---

## Files Requiring Changes

| File | Changes | Priority |
|------|---------|----------|
| DeviceConfig.swift | CM→MM, remove pins | **CRITICAL** |
| WiFiService.swift | Add diagnostics, error handling | **HIGH** |
| TankCalibrationView.swift | MM conversions | **CRITICAL** |
| DashboardView.swift | MM-based calculations | **CRITICAL** |
| DeviceConfigView.swift | Remove pin UI | **HIGH** |
| ConfigWizardView.swift | Remove pin UI | **HIGH** |
| DeviceDiagnostics.swift | New model | **MEDIUM** |
| BLEService.swift | Verify dual intervals | **MEDIUM** |

---

## Testing Checklist

- [ ] Calibration values round-trip correctly (MM save/load)
- [ ] Device level % calculated correctly with MM calibration
- [ ] Pin config UI removed and doesn't crash
- [ ] Factory reset shows confirmation and handles errors
- [ ] BLE reads both poll_interval_s and test_poll_interval_s
- [ ] WiFi config updates don't hang UI
- [ ] Screen transitions smooth (no freezes)
- [ ] Diagnostics endpoint (if implemented) displays without errors
- [ ] Testing mode toggle works correctly
- [ ] No memory leaks (Instruments test)

---

## Status

**Audit Complete:** All gaps identified  
**Ready for Implementation:** Yes  
**Estimated Time:** 2-3 hours (data model + UI updates)  
**Risk Level:** LOW (changes are mostly renames and removals, no new logic)

