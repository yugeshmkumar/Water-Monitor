# Phase 4: iOS View Splitting Analysis

**Status:** Identified 8 large views for refactoring  
**Target:** Break into focused, single-purpose components  
**Principle:** Each view handles one feature/concern

---

## Views Requiring Refactoring

| View | Lines | Issues | Target Split |
|------|-------|--------|---------------|
| **TankCalibrationView** | 567 | Too complex: calibration modes, AI filtering, real-time streaming | Split into 3-4 sub-views |
| **InsightsView** | 426 | Mixed: insights display + data analysis + formatting | Split into 3 sub-views |
| **DeviceDetailView** | 319 | Combines: status display, controls, settings, health check | Split into 2-3 sub-views |
| **DeviceHealthCheckView** | 288 | Could separate test results from status display | Split into 2 sub-views |
| **ConfigWizardView** | 316 | Multi-step wizard in single file | Split into 3 step views |
| **HistoryView** | 244 | Combines: chart display, time range picker, filtering | Split into 2-3 sub-views |
| **AddDeviceView** | 223 | Multi-phase: BLE scan → config → health check | Consider sub-view extraction |
| **DashboardView** | 184 | Status display + controls could be separated | Moderate complexity, check |

---

## Detailed Refactoring Plan

### VIEW-1: TankCalibrationView (567 lines) → 4 Components

**Current Responsibilities:**
1. Calibration mode UI (quick vs auto)
2. Real-time sensor streaming
3. AI filtering logic (median, stability scoring)
4. Two-point calibration math
5. Sensor test and retry logic

**Proposed Split:**
```
TankCalibrationView (coordinator, 100 lines)
├─ CalibrationModeSelector (80 lines) — choose quick/auto
├─ SensorStreamingDisplay (120 lines) — real-time sensor data
├─ CalibrationDataProcessor (150 lines) — AI filtering, stability
└─ CalibrationResultsDisplay (100 lines) — show empty/full distances
```

**Benefits:**
- Sensor streaming testable independently
- AI filtering logic reusable
- Each component has single purpose
- Much easier to maintain

---

### VIEW-2: InsightsView (426 lines) → 3 Components

**Current Responsibilities:**
1. Display predicted tank capacity
2. Show usage trends and patterns
3. Format and display insights data
4. Handle time-based calculations

**Proposed Split:**
```
InsightsView (coordinator, 80 lines)
├─ PredictionCard (100 lines) — time to empty, drain rate
├─ UsagePatternsCard (120 lines) — daily consumption, peak hours
└─ TrendsForecastCard (100 lines) — 7-day usage forecast
```

**Benefits:**
- Each insight type isolated
- Cards can be used elsewhere
- Easier to test calculations
- Clearer data flow

---

### VIEW-3: DeviceDetailView (319 lines) → 3 Components

**Current Responsibilities:**
1. Device status display (level, last seen)
2. Control buttons (calibrate, settings, reboot)
3. Device info section
4. Health check integration

**Proposed Split:**
```
DeviceDetailView (coordinator, 100 lines)
├─ DeviceStatusCard (80 lines) — level gauge, last reading, connection
├─ DeviceControlPanel (90 lines) — calibrate, settings, reboot buttons
└─ DeviceInfoSection (50 lines) — RSSI, firmware, queue depth
```

**Benefits:**
- Status display testable
- Controls isolated from data
- Info section reusable
- Cleaner component structure

---

### VIEW-4: DeviceHealthCheckView (288 lines) → 2 Components

**Current Responsibilities:**
1. Connectivity troubleshooting UI
2. Test result display and formatting
3. Retry logic and failure states

**Proposed Split:**
```
DeviceHealthCheckView (coordinator, 80 lines)
├─ ConnectivityTester (120 lines) — BLE/WiFi test execution
└─ HealthCheckResults (90 lines) — display pass/fail, error messages
```

**Benefits:**
- Test logic separated from UI
- Results display reusable
- Easier to add new tests

---

### VIEW-5: ConfigWizardView (316 lines) → 3 Components

**Current Responsibilities:**
1. Multi-step wizard state management
2. WiFi credential step
3. Tank dimension step
4. Pin assignment step

**Proposed Split:**
```
ConfigWizardView (coordinator, 80 lines)
├─ ConfigWizardStep1_WiFi (90 lines) — SSID/password entry
├─ ConfigWizardStep2_TankDims (80 lines) — empty/full distance
└─ ConfigWizardStep3_Pins (70 lines) — pin selection
```

**Benefits:**
- Each step independently testable
- Easy to reorder or skip steps
- Single responsibility per step
- Simpler logic flow

---

### VIEW-6: HistoryView (244 lines) → 3 Components

**Current Responsibilities:**
1. Time range picker (24h/7d)
2. Chart display (Swift Charts)
3. Data filtering and formatting

**Proposed Split:**
```
HistoryView (coordinator, 60 lines)
├─ HistoryTimeRangePicker (50 lines) — 24h/7d selector
├─ HistoryChart (100 lines) — chart rendering
└─ HistoryStatsPanel (30 lines) — min/max/avg display
```

**Benefits:**
- Time range picker reusable
- Chart logic isolated
- Stats calculation testable
- Easier to add new chart types

---

### VIEW-7: AddDeviceView (223 lines) → 2-3 Components

**Current Responsibilities:**
1. Phase state management (scan → config → health check)
2. BLE device discovery display
3. Configuration wizard
4. Health check integration

**Current Structure:**
- Already somewhat modular (phases are separate)
- Could benefit from extracting phase components

**Proposed:**
```
AddDeviceView (coordinator, 80 lines)
├─ AddDevicePhase_BLEScan (100 lines) — device discovery
└─ AddDevicePhase_ConfigAndCheck (100 lines) — config + health check
```

**Benefits:**
- Phases more testable
- Scan logic reusable
- Clearer phase transitions

---

### VIEW-8: DashboardView (184 lines) → 2 Components

**Current Responsibilities:**
1. Circular gauge display
2. Status grid (connection, last reading, test mode)
3. Control buttons

**Proposed Split:**
```
DashboardView (coordinator, 60 lines)
├─ LevelGaugeDisplay (90 lines) — circular gauge, percentage
└─ StatusGridPanel (40 lines) — stats grid
```

**Benefits:**
- Gauge component reusable
- Status grid reusable in other contexts
- Simpler main view

---

## Summary of Extractions

| Component | New Files | Total | Benefit |
|-----------|-----------|-------|---------|
| TankCalibrationView | 4 | 450 lines | Complex logic separated |
| InsightsView | 3 | 300 lines | Each insight type isolated |
| DeviceDetailView | 3 | 220 lines | Status/controls/info separate |
| DeviceHealthCheckView | 2 | 210 lines | Test logic isolated |
| ConfigWizardView | 3 | 240 lines | Each step independent |
| HistoryView | 3 | 240 lines | Time range/chart/stats separate |
| AddDeviceView | 2 | 180 lines | Phases more testable |
| DashboardView | 2 | 190 lines | Gauge/status reusable |

**Total New Components:** 22 new view files (focused, <100 lines each)
**Original 8 Views:** Simplified to coordinators (60-100 lines each)

---

## Implementation Order (Phases 4a-4c)

### Phase 4a: Large Complex Views (3 views)
1. TankCalibrationView → 4 components
2. InsightsView → 3 components
3. ConfigWizardView → 3 components

### Phase 4b: Medium Complex Views (3 views)
1. DeviceDetailView → 3 components
2. DeviceHealthCheckView → 2 components
3. HistoryView → 3 components

### Phase 4c: Simpler Views (2 views)
1. AddDeviceView → 2 components
2. DashboardView → 2 components

---

## Key Principles

✓ **Coordinator Pattern:** Each parent view becomes a light coordinator  
✓ **Single Responsibility:** Each component handles one concern  
✓ **Reusability:** Components like LevelGaugeDisplay can be used elsewhere  
✓ **Testability:** Smaller components easier to unit test  
✓ **Maintainability:** Changes isolated to relevant component  

---

## Expected Results After Phase 4

- 22 new focused view components created
- 8 large views reduced to coordinators (60-100 lines each)
- ~1,800 lines of UI logic redistributed
- Each component has single, clear purpose
- Estimated 30-40% average size reduction per view
- Components ready for reuse across screens
