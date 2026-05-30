# Codebase Audit — Round 2

**Branch:** `audit/comprehensive-round-2`  
**Date:** 2026-05-30  
**Total Issues:** 22

---

## Priority Levels

### 🔴 CRITICAL (0)
None identified

### 🟠 HIGH (0)
None identified

### 🟡 MEDIUM (22)
All identified issues

---

## Issues by Category

### Architecture (1 issue)

**ARCH-1: ConnectionManager has too many responsibilities**
- Current state: 25 properties, 367 lines
- Handles: WiFi (36 refs), BLE (41 refs), Queue (5 refs)
- Recommendation: Split into WiFiManager, BLEManager, QueueManager sub-services
- Impact: Medium — affects testability and maintainability

---

### Documentation (5 issues)

**DOC-1: device_state.h underdocumented**
- Current: 17% documentation ratio
- Issue: Header-only interface lacks usage examples
- Recommendation: Add doc comments for all functions

**DOC-2: api_server.h underdocumented**
- Current: 12% documentation ratio
- Issue: API endpoint structure not documented
- Recommendation: Add endpoint documentation

**DOC-3: error_handler.h underdocumented**
- Current: 11% documentation ratio
- Issue: Error codes and recovery logic unclear
- Recommendation: Document all error paths

**DOC-4: queue_store.h underdocumented**
- Current: 12% documentation ratio
- Issue: Circular buffer implementation details missing
- Recommendation: Document buffer management

**DOC-5: state.h underdocumented**
- Current: 15% documentation ratio
- Issue: Global state structure and mutex usage unclear
- Recommendation: Add usage guidelines

---

### Firmware Code Quality (3 issues)

**FW-1: queue_store.cpp — magic numbers in comparisons**
- Found: 1 numeric comparison in conditional
- Issue: Unclear what value is being compared
- Recommendation: Extract to named constant

**FW-2: sensor.cpp — magic numbers in comparisons**
- Found: 7 numeric comparisons in conditionals
- Issue: Distance thresholds, array indices not named
- Recommendation: Extract all numeric comparisons to constants

**FW-3: api_server.cpp — magic numbers in comparisons**
- Found: 1 numeric comparison in conditional
- Issue: Similar to FW-1
- Recommendation: Extract to constant

---

### iOS Code Quality (13 issues)

#### Large View Components (need splitting)

**IOS-1: DashboardView.swift — 185 lines**
- Contains: Status display, level gauge, stats, actions
- Recommendation: Split into sub-components

**IOS-2: DeviceDetailView.swift — 320 lines**
- Contains: Full device dashboard, all controls
- Recommendation: Already partially split, complete the refactoring

**IOS-3: ConfigWizardView.swift — 317 lines**
- Contains: WiFi setup, tank dimensions, pin assignment
- Recommendation: Split into separate step views

**IOS-4: DeviceHealthCheckView.swift — 289 lines**
- Contains: Connectivity diagnosis, troubleshooting steps
- Recommendation: Split diagnosis logic from UI

**IOS-5: AddDeviceView.swift — 224 lines**
- Contains: BLE scan, config wizard, health check
- Recommendation: Split into phases

**IOS-6: DeviceConfigView.swift — 151 lines**
- Contains: All device settings
- Recommendation: Group related settings into sub-views

**IOS-7: TankCalibrationView.swift — 568 lines (LARGEST)**
- Contains: Sensor streaming, calibration logic, AI filtering, results
- Recommendation: This is the most complex view — split into:
  - CalibrationSetupView
  - CalibrationStreamView
  - CalibrationResultsView

**IOS-8: InsightsView.swift — 427 lines**
- Contains: Multiple insight types, charts, statistics
- Recommendation: Split by insight type (predictions, trends, usage)

**IOS-9: HistoryView.swift — 245 lines**
- Contains: Time range picker, chart, filtering
- Recommendation: Extract chart component

#### Service Layer Issues (too many responsibilities)

**IOS-10: BLEService.swift — 15 properties**
- Handles: Central manager, discovery, connection, GATT operations
- Recommendation: Extract discovery into BLEDiscovery service

**IOS-11: ConnectionManager.swift — 25 properties (MOST CRITICAL SERVICE ISSUE)**
- Handles: WiFi connection, BLE fallback, queue draining, state caching
- Recommendation: Split into:
  - TransportSelector (WiFi vs BLE choice logic)
  - QueueDrainManager (queue sync)
  - DeviceStateCache (current readings)

**IOS-12: InsightsEngine.swift — 28 properties**
- Handles: Statistical analysis, predictions, trend detection
- Recommendation: Extract into:
  - TrendAnalyzer
  - PredictionEngine
  - UsageCalculator

**IOS-13: WiFiService.swift — 14 properties**
- Handles: Network discovery, connection, WebSocket, REST
- Recommendation: Extract WebSocket into separate service

---

### Testing Coverage (0 explicit issues, but noted)

- Firmware tests: 3 files (good baseline)
- iOS tests: 1 file (needs expansion)
- Note: No test coverage metrics available

---

## Industry Best Practices — Gaps

| Practice | Current | Recommended |
|----------|---------|-------------|
| Component Size | 3-600 lines | < 150 lines |
| Service Properties | 3-28 properties | < 8 properties |
| Documentation Ratio | 11-65% | > 40% |
| Test-to-Code Ratio | ~1:50 | ~1:10-15 |
| Error Code Coverage | 8 codes | > 20 codes |

---

## Fix Strategy

### Phase 1: Documentation (5 issues) ⚡ QUICK WINS
- Add doc comments to all firmware headers
- ~1-2 hours of work

### Phase 2: Firmware Cleanup (3 issues)
- Extract remaining magic numbers
- ~30 minutes

### Phase 3: iOS Service Refactoring (4 issues)
- Split large services into focused managers
- BLEService → BLEService + BLEDiscovery
- ConnectionManager → TransportSelector + QueueDrainManager + StateCache
- WiFiService → WiFiService + WebSocketService
- InsightsEngine → TrendAnalyzer + PredictionEngine + UsageCalculator
- ~4-6 hours

### Phase 4: iOS View Refactoring (8 issues)
- Split large view files
- TankCalibrationView → 3 sub-views (biggest task)
- InsightsView → 3 sub-views
- Other views → 2 sub-views each
- ~6-8 hours

---

## Questions for Review

1. **Scope**: Should we tackle all 22 issues or prioritize?
2. **TankCalibrationView**: This 568-line file is the largest — should it be first?
3. **Testing**: Should we add tests as we refactor?
4. **Documentation**: Should we add inline code comments while refactoring?

---

## Review Checklist

- [ ] All 22 issues reviewed and understood
- [ ] Prioritization agreed
- [ ] Proceed to fix cycle 1
