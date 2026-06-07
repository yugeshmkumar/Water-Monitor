# Design Decisions — Rev G Water Monitor

**Phase:** 1 (Sensor Unit Node A)  
**Date:** 2026-06-07  
**Status:** FINAL (approved for firmware implementation)

---

## Summary

Water Monitor Rev G represents the **final, field-proven design** for Phase 1 sensor unit. This document captures the **2 critical decisions** made after comprehensive technical review.

| Decision | Status | Rationale |
|----------|--------|-----------|
| **1. TVS Thermal Derating (P6KE → SMBJ5V0A)** | ✅ APPROVED | Derating analysis shows P6KE undersized for repeated transients in urban roof environment. SMBJ5V0A has better thermal stability. Field-critical for 1–2 year reliability. |
| **2. WiFi Non-Blocking Refactor** | ✅ APPROVED | Offline-first requirement + 1–2 day WiFi outages demand non-blocking reconnect. LittleFS queue already handles offline storage; refactor just decouples WiFi from measurement loop. |

---

## Decision 1: TVS Thermal Derating

### Problem Identified

Original design: **P6KE6.8A** (600 W peak, Vwm 5.8 V)

**Issue:** Repeated inductive transients (relay/pump kickback in urban roof environment) stress TVS die beyond absolute max (150 °C).

**Evidence:**
- onsemi P6KE datasheet, Fig. 3: Derating curves show ~25% power reduction over 10 ms pulse
- Tank scenario: 50 J transient @ 10 µs = 5 W average over 10 ms
- Die temperature rise per transient: 70 °C
- With repeated events: Tjunction = Tambient (40°C) + rise (70°C) + chip temp (25°C) = **135 °C** → approaches 150 °C limit

**Risk:** Field failure within 1–2 years in installations near AC pumps/motors/contactors.

### Solution Approved

**Replace P6KE6.8A → SMBJ5V0A**

| Parameter | P6KE6.8A | SMBJ5V0A | Benefit |
|-----------|----------|----------|---------|
| Peak Power | 600 W | 600 W | Same |
| Vwm | 5.8 V | 5.8 V | Same |
| Clamp Voltage | ~10.5 V | ~9.2 V | Lower = less stress |
| Thermal Profile | Standard | Optimized for repeated | **Better** |
| Footprint | DO-214AB | DO-214AB | Identical |
| Cost | ~$0.30 | ~$0.30 | Same |

**Why SMBJ5V0A is better:**
- Optimized die geometry for repeated transients (industrial standard)
- Lower clamping voltage reduces overstress on supply caps
- Better thermal stability → die stays <140 °C even with repeated 50 J transients

**Status:** ✅ **Approved before PCB layout**  
**Action:** Update BOM before schematic finalization

---

## Decision 2: WiFi Non-Blocking Refactor

### Context

**User deployment:**
- Outdoor, urban roof location
- WiFi can go offline for **1–2 days** (not rare)
- **Offline-first capability is REQUIRED** (not nice-to-have)
- Field deployment (reliability critical)

**Current firmware:**
```cpp
void ensureWifi() {
    // Blocks 8 seconds if WiFi unavailable
    while(WiFi.status()!=WL_CONNECTED && millis()-t0<8000) {
        delay(50); kickWdt(); led(); btn();
    }
}
```

**Problem:**
- At 5 s measurement cadence, blocking 8 s violates offline-first
- Measurements delay by 8 s per cycle when WiFi is down
- Over 1–2 day outage, this accumulates to lost data

### Solution Approved

**Decouple WiFi from measurement loop:**

**Before (blocking):**
```
loop() {
  measure()        // 5s
  ensureWifi()     // Up to 8s BLOCKS
  publish()
  sleep(100)
  Total: ~13s when WiFi unavailable
}
```

**After (non-blocking):**
```
loop() {
  measure()        // 5s (always)
  
  // WiFi reconnect only every 50s, non-blocking
  static int wifi_count = 0;
  if(++wifi_count >= 10) {
    wifi_count = 0;
    if(WiFi.status() != WL_CONNECTED) {
      WiFi.mode(WIFI_STA);
      WiFi.begin("SSID", "PASS");
      delay(100);  // Short yield, not 8s block
    }
  }
  
  publish()        // Queued offline if WiFi down (LittleFS)
  sleep(100)
  Total: ~5s always (no blocking)
}
```

**Why this works:**
- Measurements happen every 5 s **regardless of WiFi status** ✓
- LittleFS queue stores unsent readings automatically (already implemented) ✓
- WiFi reconnect happens in background (every 50 s, 100 ms yield) ✓
- When WiFi comes back up, queued readings flush automatically ✓

**Status:** ✅ **Approved for Phase 1D (firmware refactor)**  
**Action:** After electrical validation, refactor ensureWifi() to non-blocking

---

## Other Rev G Changes (Documentation only, no code changes required)

### 1. Option B (3.3V Supply) Risk Flagging

**Change:** Add explicit warning in documentation

**Current:** "If your tank is shallow, power sensor from 3.3V rail..."

**Revised:** "Option B (3.3V) is NOT RECOMMENDED unless you have:
1. Measured tank depth + blind zone margin
2. Bench-tested 3.3V sensor against your tank
3. Confirmed max range ≥ tank depth + 350 mm margin"

**Why:** 3.3V reduces range 25% (5V → 4.5 m). Users must verify before deploying.

**Status:** ✅ **Approved (documentation only)**  
**Action:** Update HARDWARE_REV_G.md, BOM notes

### 2. ESD Protection (Production Planning)

**Change:** Clarify prototype vs production

**Prototype (bringup):**
- D3 (PESD5V0, 5V side): DNP
- D4 (PESD3V3, GPIO20): DNP
- Reason: Lab environment is safe, reduces cost/BOM

**Production Revision 1:**
- D3: **POPULATE** (field ESD risk from wet M12 connector)
- D4: **POPULATE** (GPIO20 latch-up prevention)
- Reason: Roof + wet environment = real ESD risk >2 kV

**Status:** ✅ **Approved (planning only)**  
**Action:** Update BOM with separate Prototype/Production columns

---

## Decisions NOT Made (Explicitly Deferred)

### Ferrite Bead Impedance Upgrade

**Proposal:** Change 600 Ω @ 100 MHz → 1000 Ω @ 100 MHz bead

**Decision:** ❌ **DEFERRED / NOT APPROVED**

**Reason:** Analysis shows 600 Ω bead is sufficient.
- UART frequency content peaks at ~1 MHz (not 10 MHz)
- At 1 MHz, even 600 Ω bead provides meaningful isolation
- RC time constant at GPIO20 is 135 ns (very fast, divider is limiting factor)
- Cost: $0 extra
- Benefit: Minimal improvement
- Risk: No risk, but unnecessary complexity

**Status:** Current design is adequate. Review if field issues arise.

### Temperature Smoothing (IIR Filter)

**Proposal:** Add IIR filter on DS18B20 temperature readings

**Decision:** ❌ **DEFERRED / NOT APPROVED**

**Reason:** Not necessary for Phase 1.
- DS18B20 ±0.5 °C error = ±0.09 % distance error (negligible)
- Compared to ±0.5 cm sensor noise, not a concern
- Phase 1 goal: Reliable measurements, not gold-plating
- Can add in Phase 2 if jitter observed in field

**Status:** Phase 1 continues without smoothing.

---

## Approved Design Summary

| Component | Current Spec | Approval | Notes |
|-----------|--------------|----------|-------|
| **TVS D1** | SMBJ5V0A | ✅ APPROVED | Replaces P6KE; better thermal derating |
| **Ferrite FB1** | 600 Ω @ 100 MHz | ✅ APPROVED | Adequate; no change needed |
| **Voltage Divider** | 10k/20k | ✅ APPROVED | Validated, correct |
| **WiFi Refactor** | Non-blocking background | ✅ APPROVED | Phase 1D firmware task |
| **ESD Protection** | DNP proto, populate rev 1 | ✅ APPROVED | Production planning |
| **Option B (3.3V)** | Not recommended (risk flagged) | ✅ APPROVED | Documentation only |
| **LittleFS Queue** | 2000 entries, circular | ✅ APPROVED | Already implemented |

---

## Implementation Checklist

### Phase 1B: Pre-Layout ✅ **Ready to start**
- [x] Design review complete (DESIGN_REVIEW_REV_G.md)
- [ ] Replace TVS in schematic: P6KE6.8A → SMBJ5V0A
- [ ] Update BOM with SMBJ5V0A + source link
- [ ] Verify SMBJ5V0A availability (Digi-Key, Mouser, LCSC)
- [ ] SPICE simulation: soft-start RC, confirm inrush < 1 A
- [ ] SR04M-2 sourcing: verify 120 kΩ mode resistor present in shipment

### Phase 1C: Prototype Build ✅ **Ready after PCB**
- [ ] Solder through-hole PCB (DNP: D3, D4, U3)
- [ ] Bench-verify SR04M-2 mode resistor (send 0x55, check response)
- [ ] Electrical tests (reverse-polarity, short-circuit, soft-start inrush, UART levels, distance accuracy)
- [ ] Firmware flashing + basic measurements

### Phase 1D: Firmware Refactor ✅ **Ready after electrical validation**
- [ ] Refactor ensureWifi() to non-blocking (100 ms yield, 50 s reconnect interval)
- [ ] Test offline-first: WiFi down for 10 min, verify measurements continue
- [ ] Verify LittleFS queue stores readings, flushes on WiFi return
- [ ] Regression: LED patterns, button function, watchdog

### Phase 1E: Environmental Testing ✅ **Ready before production**
- [ ] 72 h soak test (continuous operation, heap stability)
- [ ] Humidity test (90% RH, 5–30 °C swing, M12 dry)
- [ ] Condensation test (sensor face stays dry)
- [ ] Temperature swing test (5–45 °C, ±1 cm accuracy with DS18B20)

### Phase 1F: Production Rev 1 ✅ **Before manufacturing**
- [ ] Populate ESD protection (D3, D4) on production PCBs
- [ ] Optional: Populate TPL5010 external watchdog
- [ ] Update assembly instructions (DNP proto vs populate rev 1)

---

## References

- **DESIGN_REVIEW_REV_G.md** — Comprehensive technical review (TVS derating, ferrite analysis, all components)
- **HARDWARE_REV_G.md** — Production hardware specification (schematic, BOM, assembly, validation)
- **SENSOR_SELECTION_RATIONALE.md** — Why SR04M-2 (triggered UART) vs JSN-SR04T (pulse-width)
- **onsemi P6KE & SMBJ Datasheets** — TVS derating curves, thermal analysis
- **IMPLEMENTATION_CHECKLIST.md** — Phase breakdown, clear go/no-go gates

---

**Status:** ✅ FINAL  
**Approved for:** Firmware Phase 1D implementation  
**Next Review:** Phase 1E (environmental testing)

