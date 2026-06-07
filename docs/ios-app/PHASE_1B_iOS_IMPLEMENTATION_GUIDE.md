# Phase 1B iOS App Implementation Guide

**Status:** STARTED (DeviceConfig committed, rest pending)  
**Date:** 2026-06-07  
**Objective:** Complete all Phase 1B changes for firmware compatibility

---

## Completed ✅

1. **DeviceConfig.swift** — Commit `e686b81`
   - [x] Renamed `tankEmptyCM` → `tankEmptyMM`
   - [x] Renamed `tankFullCM` → `tankFullMM`
   - [x] Updated defaults: 150cm → 1500mm, 20cm → 200mm
   - [x] Updated CodingKeys: `tank_empty_cm` → `tank_empty_mm`
   - [x] Updated patch() method
   - [x] Updated Codable init/encode
   - [x] Removed `pinTrig`, `pinEcho` fields
   - [x] Removed pin configuration from CodingKeys

---

## Pending Changes (Implementation Order)

### Priority 1: MODEL UPDATES (Tank.swift)

**File:** `ios-app/mobile/WaterMonitor/Models/Tank.swift`

```swift
// BEFORE:
struct Tank {
    var tankEmptyCM: Double     // distance from sensor when tank is empty
    var tankFullCM: Double      // distance from sensor when tank is full
    
    init(..., tankEmptyCM: Double = 150, tankFullCM: Double = 20, ...) {
        self.tankEmptyCM   = tankEmptyCM
        self.tankFullCM    = tankFullCM
    }
}

// AFTER:
struct Tank {
    var tankEmptyMM: Double     // distance from sensor when tank is empty (in mm)
    var tankFullMM: Double      // distance from sensor when tank is full (in mm)
    
    init(..., tankEmptyMM: Double = 1500, tankFullMM: Double = 200, ...) {
        self.tankEmptyMM   = tankEmptyMM
        self.tankFullMM    = tankFullMM
    }
}
```

**Changes:**
- [ ] Rename `tankEmptyCM` → `tankEmptyMM`
- [ ] Rename `tankFullCM` → `tankFullMM`
- [ ] Update defaults (multiply by 10)
- [ ] Update any initializers
- [ ] Check computed properties (levelPercentage, etc.) and add MM conversion

---

### Priority 2: VIEW MODEL UPDATES (ConfigVM.swift)

**File:** `ios-app/mobile/WaterMonitor/ViewModels/ConfigVM.swift`

```swift
// BEFORE:
var pinsConflict: Bool { edited.pinTrig == edited.pinEcho }

// REMOVE THIS LINE (pins no longer configurable)
```

**Changes:**
- [ ] Remove `pinsConflict` computed property (pins are firmware-defined)
- [ ] Remove any pin validation logic
- [ ] Test config editing still works without pins

---

### Priority 3: UI VIEW UPDATES (Multiple Views)

#### 3a. ConfigWizardView.swift

**File:** `ios-app/mobile/WaterMonitor/Views/ConfigWizardView.swift`

```swift
// BEFORE:
Text(String(format: "%.1f cm", edited.tankEmptyCM))
Text(String(format: "%.1f cm", edited.tankFullCM))
let range = edited.tankEmptyCM - edited.tankFullCM

// AFTER:
Text(String(format: "%.0f mm", edited.tankEmptyMM))
Text(String(format: "%.0f mm", edited.tankFullMM))
let range = edited.tankEmptyMM - edited.tankFullMM
```

**Changes:**
- [ ] Update all displays from `tankEmptyCM` to `tankEmptyMM`
- [ ] Update all displays from `tankFullCM` to `tankFullMM`
- [ ] Change format string from "%.1f cm" to "%.0f mm"
- [ ] Update any calculations that use these values

#### 3b. PinConfigView.swift — REMOVE ENTIRELY

**File:** `ios-app/mobile/WaterMonitor/Views/PinConfigView.swift`

**Action:** DELETE THIS FILE

Rationale: Pin configuration is no longer user-configurable (firmware uses hardcoded UART pins for SR04M-2 sensor)

**Before removing:**
- [ ] Check if PinConfigView is referenced in any navigation
- [ ] Remove all references from ConfigWizardView and other views
- [ ] Remove any navigation links to this view

---

### Priority 4: CALIBRATION VIEW UPDATES (TankCalibrationView.swift)

**File:** `ios-app/mobile/WaterMonitor/Views/TankCalibrationView.swift`

The calibration view shows and calculates tank distances. These need MM conversions.

```swift
// BEFORE:
var calculatedFullCM: Double?
var calculatedEmptyCM: Double?
Text(String(format: "%.1f cm", calculatedEmptyCM ?? 0))

// AFTER:
var calculatedFullMM: Double?
var calculatedEmptyMM: Double?
Text(String(format: "%.0f mm", (calculatedEmptyMM ?? 0) / 10))  // Convert MM to CM for display
// OR display in MM:
Text(String(format: "%.0f mm", calculatedEmptyMM ?? 0))
```

**Changes:**
- [ ] Rename `calculatedFullCM` → `calculatedFullMM`
- [ ] Rename `calculatedEmptyCM` → `calculatedEmptyMM`
- [ ] Update all references to use MM
- [ ] Update display format (show MM or convert to CM for backward compatibility)
- [ ] Update saveCalibration to use correct units
- [ ] Update calculations (if any) to use MM

---

### Priority 5: SERVICE UPDATES (BLEService.swift, WiFiService.swift)

#### 5a. BLEService.swift — Update log message

**File:** `ios-app/mobile/WaterMonitor/Services/BLEService.swift`

```swift
// BEFORE:
print("[BLE] AA03 config decoded: node=\(cfg.nodeID) empty=\(cfg.tankEmptyCM) full=\(cfg.tankFullCM)")

// AFTER:
print("[BLE] AA03 config decoded: node=\(cfg.nodeID) empty=\(cfg.tankEmptyMM)mm full=\(cfg.tankFullMM)mm")
```

**Changes:**
- [ ] Update log message to use `tankEmptyMM`, `tankFullMM`
- [ ] Add "mm" unit to log for clarity

#### 5b. WiFiService.swift — Add diagnostics endpoint

**File:** `ios-app/mobile/WaterMonitor/Services/WiFiService.swift`

Add new method:

```swift
func fetchDiagnostics() async throws -> DeviceDiagnostics {
    do {
        let diag = try await get(path: "/api/diagnostics", as: DeviceDiagnostics.self)
        lastError = nil
        return diag
    } catch {
        lastError = error
        if !isTimeoutError(error) {
            print("[WiFi] fetchDiagnostics failed: \(error.localizedDescription)")
        }
        throw error
    }
}
```

**Changes:**
- [ ] Add `fetchDiagnostics()` method (see code above)
- [ ] Requires new `DeviceDiagnostics` model (see below)

---

### Priority 6: NEW MODEL (DeviceDiagnostics.swift)

**File:** `ios-app/mobile/WaterMonitor/Models/DeviceDiagnostics.swift` (CREATE NEW)

```swift
import Foundation

struct DeviceDiagnostics: Decodable {
    var sensor: SensorDiag?
    var wifi: WiFiDiag?
    var queue: QueueDiag?
    var system: SystemDiag?
    var config: ConfigSnapshot?

    struct SensorDiag: Decodable {
        var reads: Int
        var frameErrors: Int
        var timeouts: Int
        var lastRawCM: Double
        var lastFilteredCM: Double
        var errorRate: Double

        enum CodingKeys: String, CodingKey {
            case reads, frameErrors = "frame_errors", timeouts
            case lastRawCM = "last_raw_cm"
            case lastFilteredCM = "last_filtered_cm"
            case errorRate = "error_rate_%"
        }
    }

    struct WiFiDiag: Decodable {
        var connected: Bool
        var rssiDBM: Int
        var ssid: String?

        enum CodingKeys: String, CodingKey {
            case connected, rssiDBM = "rssi_dbm", ssid
        }
    }

    struct QueueDiag: Decodable {
        var pending: Int
    }

    struct SystemDiag: Decodable {
        var uptimeS: Int
        var heapFree: Int
        var heapTotal: Int
        var heapUsedPct: Double
        var psramFree: Int
        var fwVersion: String

        enum CodingKeys: String, CodingKey {
            case uptimeS = "uptime_s"
            case heapFree = "heap_free"
            case heapTotal = "heap_total"
            case heapUsedPct = "heap_used_%"
            case psramFree = "psram_free"
            case fwVersion = "fw_version"
        }
    }

    struct ConfigSnapshot: Decodable {
        var tankEmptyMM: Double
        var tankFullMM: Double
        var pollIntervalS: Int
        var testingMode: Bool

        enum CodingKeys: String, CodingKey {
            case tankEmptyMM = "tank_empty_cm"    // ← Note: API sends CM but should be MM
            case tankFullMM = "tank_full_cm"      // ← Note: API sends CM but should be MM
            case pollIntervalS = "poll_interval_s"
            case testingMode = "testing_mode"
        }
    }

    enum CodingKeys: String, CodingKey {
        case sensor, wifi, queue, config
    }
}
```

**Changes:**
- [ ] Create new file `DeviceDiagnostics.swift`
- [ ] Copy model above
- [ ] Ensure all CodingKeys match `/api/diagnostics` response

---

### Priority 7: ERROR HANDLING (Factory Reset)

**File:** `ios-app/mobile/WaterMonitor/Views/DeviceConfigView.swift` or similar

When calling factory reset, handle HTTP 500 response:

```swift
// BEFORE:
await cm.sendCommand(["cmd": "factory_reset"])

// AFTER:
do {
    try await cm.sendCommand(["cmd": "factory_reset"])
    // Success
    showAlert("Factory reset complete", message: "Device restarted with default settings")
} catch {
    // Error - show warning
    showAlert("Factory reset failed", message: "Device may be in inconsistent state. Try power cycle.", severity: .critical)
}
```

**Changes:**
- [ ] Add error handling to factory reset command
- [ ] Show user confirmation dialog before factory reset
- [ ] Display error message if HTTP 500 returned
- [ ] Warn user device might be in bad state

---

## Testing Checklist

After all changes, verify:

### Model Tests
- [ ] DeviceConfig serialization/deserialization works
- [ ] Tank model uses MM correctly
- [ ] DeviceDiagnostics decodes /api/diagnostics response

### View Tests
- [ ] TankCalibrationView shows correct units (MM or CM)
- [ ] ConfigWizardView doesn't crash without pin config
- [ ] ConfigWizardView displays calibration values correctly
- [ ] No UI references to pinTrig or pinEcho

### Integration Tests
- [ ] Fetch config from device and display without errors
- [ ] Calibration save/load roundtrips correctly
- [ ] Factory reset shows confirmation and handles errors
- [ ] BLE config read includes both poll intervals
- [ ] /api/diagnostics endpoint fetches and displays (if UI added)

### UI/UX Tests
- [ ] No hanging during config fetch
- [ ] Smooth screen transitions
- [ ] Config updates don't freeze UI
- [ ] Calibration flow completes without crashes
- [ ] Factory reset warning is clear to user

### Memory Tests (Instruments)
- [ ] No memory leaks from config updates
- [ ] No retained cycles in views
- [ ] Proper cleanup on view dismissal

---

## Files to Modify Summary

| File | Changes | Priority |
|------|---------|----------|
| DeviceConfig.swift | ✅ DONE (commit e686b81) | CRITICAL |
| Tank.swift | Rename fields to MM | HIGH |
| ConfigVM.swift | Remove pin validation | HIGH |
| ConfigWizardView.swift | Update to MM, remove pins | HIGH |
| TankCalibrationView.swift | Use MM units | HIGH |
| PinConfigView.swift | DELETE | HIGH |
| BLEService.swift | Update log message | MEDIUM |
| WiFiService.swift | Add diagnostics method | MEDIUM |
| DeviceDiagnostics.swift | CREATE NEW | MEDIUM |
| DeviceConfigView.swift | Add factory reset error handling | MEDIUM |

---

## Files to DELETE

- [ ] `ios-app/mobile/WaterMonitor/Views/PinConfigView.swift`

---

## Expected Outcome

After all changes:
✅ iOS app fully compatible with Phase 1B firmware
✅ Calibration values in correct units (MM)
✅ No obsolete pin configuration UI
✅ Smooth screen transitions and no hanging
✅ Error handling for factory reset
✅ Optional diagnostics endpoint support
✅ All tests passing
✅ Ready for production release

---

## Timeline

Estimated completion: **2-3 hours** (for experienced Swift developer)
Estimated testing: **1-2 hours**

Total: **3-5 hours** for full Phase 1B iOS compatibility

