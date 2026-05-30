# Round 2 Audit Fix Plan

**Status:** Approved — 22 issues ready for fixing  
**Date:** 2026-05-30  
**Total Phases:** 4  
**Total Time:** 20-25 hours  

---

## Phase Execution Order

### ✅ Phase 1: Documentation (1.5-2 hrs)
- DOC-1: device_state.h documentation
- DOC-2: api_server.h documentation  
- DOC-3: error_handler.h documentation
- DOC-4: queue_store.h documentation
- DOC-5: state.h documentation

**Review Cycle:** After Phase 1 completion

### ⏳ Phase 2: Firmware Cleanup (30 min)
- FW-1: queue_store.cpp magic number
- FW-2: sensor.cpp magic numbers (7)
- FW-3: api_server.cpp magic number

**Review Cycle:** After Phase 2 completion

### ⏳ Phase 3: iOS Service Refactoring (4-6 hrs)
- SVC-1: ConnectionManager split (largest)
- SVC-2: InsightsEngine split
- SVC-3: BLEService refactoring
- SVC-4: WiFiService refactoring
- ARCH-1: Architecture improvement (included)

**Review Cycle:** After Phase 3 completion

### ⏳ Phase 4: iOS View Refactoring (6-8 hrs)
- VIEW-1: TankCalibrationView split (largest, 568 lines)
- VIEW-2: InsightsView split
- VIEW-3: DeviceHealthCheckView split
- VIEW-4: AddDeviceView refactoring
- VIEW-5: ConfigWizardView completion
- VIEW-6: DeviceDetailView completion
- VIEW-7: HistoryView refactoring
- VIEW-8: DashboardView refactoring

**Review Cycle:** After Phase 4 completion

---

## Review Cycle Process

After each phase:
1. Comprehensive audit of fixes
2. Check for regressions
3. Validate fixes are working
4. Identify any new issues
5. Create commit with fixes

**Target:** Zero issues after each review cycle

---

## Success Criteria

- [ ] All 22 issues fixed
- [ ] No regressions introduced
- [ ] 4 review cycles completed
- [ ] Zero issues in final review
- [ ] All commits documented

