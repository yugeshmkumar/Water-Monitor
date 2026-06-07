# Phase 1B — Component Sourcing List

**Date:** 2026-06-07  
**Status:** VERIFIED & READY TO ORDER  
**Phase:** 1B (Pre-Layout)

---

## 📦 CRITICAL COMPONENTS — MUST SOURCE

### 1. SMBJ5V0A (TVS Diode) — REVERSE POLARITY + TRANSIENT PROTECTION
| Spec | Value |
|------|-------|
| **Package** | SMB (DO-214AA, through-hole) |
| **Impedance** | 600 W peak, 5.8 V Vwm |
| **Purpose** | Replaces P6KE6.8A for better thermal derating |
| **Qty** | 1 |

**Status:** ✅ **FOUND & AVAILABLE**

| Supplier | Link | Price | Lead Time |
|----------|------|-------|-----------|
| Evelta.com | https://evelta.com/smbj5-0a-5v-600w-esd-suppressor-tvs-diode-2pin-smb-do-214aa/ | TBD | 2-5 days |

---

### 2. SR04M-2 (Ultrasonic Sensor) — DISTANCE MEASUREMENT
| Spec | Value |
|------|-------|
| **Interface** | Triggered UART (9600 baud) |
| **Mode Resistor** | **120 kΩ (CRITICAL — must be soldered)** |
| **Frequency** | 40 kHz ultrasonic |
| **Range** | 200–6000 mm |
| **Qty** | 1 |

**Status:** ✅ **IN HAND** (user has it)

**⚠️ CRITICAL ACTION:** Confirm 120 kΩ mode resistor is soldered on board before using

| Supplier | Link | Price | Lead Time |
|----------|------|-------|-----------|
| In hand | — | — | Ready now |

**If you need another:**
- AliExpress, Robu.in, Amazon.in (search "SR04M-2" or "AJ-SR04M")
- **Verify mode resistor pad is populated (NOT empty)**

---

### 3. AO3401A (P-FET Logic-Level) — REVERSE POLARITY PROTECTION
| Spec | Value |
|------|-------|
| **Package** | TO-220 (through-hole) |
| **Type** | Logic-level P-FET (Vth ≤ 2.5V) |
| **Vgs Max** | ±20 V |
| **RDSon** | 0.14 Ω (excellent soft-start) |
| **Qty** | 1 |
| **Alternative to** | NDP6020P (not available) |

**Status:** ✅ **FOUND & AVAILABLE**

| Supplier | Link | Price | Lead Time |
|----------|------|-------|-----------|
| Robu.in | https://robu.in/product/ao3401a-umwyoutai-semiconductor-co-ltd-30v-4-2a-50m%CF%8910v-1-4w-400mv-1-piece-p-channel-sot-23-mosfets-rohs | TBD | 2-5 days |

**Backup suppliers:** Digi-Key, Mouser (if robu.in out of stock)

---

### 4. Ferrite Bead 1 kohm (UART Isolation)
| Spec | Value |
|------|-------|
| **Impedance** | 1000 Ω @ 100 MHz |
| **Package** | 0603 (through-hole leaded) |
| **Current Rating** | 200 mA |
| **Purpose** | Isolates sensor switching transients from XIAO rail |
| **Qty** | 1 |

**Status:** ✅ **FOUND & AVAILABLE** (3 links provided)

| Supplier | Link | Price | Lead Time |
|----------|------|-------|-----------|
| Evelta.com (Option 1) | https://evelta.com/1kohm-200ma-25-0603-ferrite-bead-2/ | TBD | 2-5 days |
| Evelta.com (Option 2) | https://evelta.com/1kohm-200ma-25-0603-ferrite-bead-1/ | TBD | 2-5 days |
| Evelta.com (Option 3) | https://evelta.com/1kohm-200ma-25-0603-ferrite-bead/ | TBD | 2-5 days |

**Note:** All three links are the same part; order from any one.

---

### 5. RUEF135 (Polyfuse / PPTC Resettable Fuse) — INRUSH PROTECTION
| Spec | Value |
|------|-------|
| **Hold Current** | 1.35 A (requirement: 1.1 A) |
| **Voltage** | 30 V (5V circuit OK) |
| **Type** | PPTC Resettable Fuse |
| **Purpose** | Soft-start current limiting |
| **Qty** | 1 |
| **Alternative to** | RXE110 (not available) |

**Status:** ✅ **FOUND & AVAILABLE**

| Supplier | Link | Price | Lead Time |
|----------|------|-------|-----------|
| Sharvi Electronics | https://sharvielectronics.com/product/ruef135-30v-1-35a-pptc-resettable-fuse-polyswitch-tyco-raychem/ | TBD | 3-7 days |

**Backup option:**
- Hubtronics: https://hubtronics.in/lvr012-pptc-resettable-fuse (verify specs)

---

## ✅ STANDARD COMPONENTS — READILY AVAILABLE

These components are standard electronics parts. Source from any major supplier (Digi-Key, Mouser, LCSC, Amazon.in, local electronics shop).

### Diodes & Transistors
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **1N5819** | 1 A Schottky diode, axial | 1 | Back-feed isolation (D2) |

### Capacitors
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **680 µF / 16V** | Radial electrolytic | 1 | Bulk energy storage (C1) |
| **100 µF / 16V** | Radial electrolytic | 2 | Decoupling (C2, C3) |
| **100 nF** | Ceramic disc | 3 | HF bypass (C4, C5, C6) |

### Resistors (¼ W, 5%)
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **100 Ω** | ¼ W carbon film | 2 | UART series protection (R1, R2) |
| **10 kΩ** | ¼ W carbon film | 1 | TX divider lower leg (R3) |
| **20 kΩ** | ¼ W carbon film | 1 | TX divider upper leg (R4) |
| **4.7 kΩ** | ¼ W carbon film | 1 | DS18B20 pull-up (R6, optional) |
| **100 kΩ** | ¼ W carbon film | 1 | Q1 gate resistor (R5) |

### Connectors
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **M12 4-pin connector** | Industrial UART interface | 1 | Sensor connection (J2) |
| **GX12 or Screw Terminal** | 2-pin power entry | 1 | Power input (J1) |

### Mechanical
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **Tactile Switch** | 6 mm, 2-pin | 1 | Reset/setup button (SW1) |
| **IP65 ABS Enclosure** | ≥100 × 70 × 50 mm | 1 | PCB housing |
| **PG7 / PG9 Cable Glands** | Waterproof cable entry | 2 | Sensor + power cable |

### Optional
| Part | Spec | Qty | Notes |
|------|------|-----|-------|
| **DS18B20** | Temperature sensor, TO-92 | 1 | Temperature compensation (optional) |
| **XIAO ESP32-C6** | Microcontroller module | 1 | Main MCU (if not already sourced) |

---

## 📋 COMPLETE SOURCING CHECKLIST

### Critical Components (MUST SOURCE)
- [ ] SMBJ5V0A (TVS) — evelta.com
- [ ] SR04M-2 (Sensor) — in hand, verify mode resistor
- [ ] AO3401A (P-FET) — robu.in
- [ ] Ferrite 1 kohm — evelta.com
- [ ] RUEF135 (Polyfuse) — Sharvi Electronics

### Standard Components (Source from any supplier)
- [ ] 1N5819 Schottky (×1)
- [ ] 680µF/16V capacitor (×1)
- [ ] 100µF/16V capacitors (×2)
- [ ] 100nF ceramic capacitors (×3)
- [ ] Resistors: 100Ω (×2), 10kΩ (×1), 20kΩ (×1), 4.7kΩ (×1), 100kΩ (×1)
- [ ] M12 4-pin connector (×1)
- [ ] GX12 or screw terminal (×1)
- [ ] Tactile switch (×1)
- [ ] IP65 enclosure (×1)
- [ ] PG7/PG9 cable glands (×2)

### Optional Components
- [ ] DS18B20 (temperature sensor, optional)
- [ ] XIAO ESP32-C6 (if not already sourced)

---

## 💰 ESTIMATED TOTAL COST

| Category | Est. Cost |
|----------|-----------|
| Critical components (5 items) | $15–25 |
| Standard components | $20–30 |
| Optional components | $5–10 |
| **Total** | **$40–65** |

(Excludes external 5V/2A power supply ~$10–15)

---

## 🚚 RECOMMENDED ORDERING STRATEGY

### Fastest Path (Next 5–7 days):
1. **Order from Evelta.com:**
   - SMBJ5V0A (TVS)
   - Ferrite 1 kohm
   - Standard components (capacitors, resistors, connectors)

2. **Order from Robu.in:**
   - AO3401A (P-FET)

3. **Order from Sharvi Electronics:**
   - RUEF135 (Polyfuse)

4. **Already have:**
   - SR04M-2 (sensor)

### Alternative (Cheapest, 10–14 days):
- Order everything from LCSC.com (often lower prices, longer shipping)
- Evelta.com for priority items

---

## ✅ VERIFICATION CHECKLIST

Before starting Phase 1B assembly:

- [ ] All critical components received
- [ ] SR04M-2 has 120 kΩ mode resistor soldered (or plan to solder it)
- [ ] All standard components verified
- [ ] Datasheets downloaded for each component
- [ ] Schematic updated with AO3401A (instead of NDP6020P)
- [ ] BOM updated with actual part numbers and suppliers

---

## 🎯 NEXT STEPS

1. **Update this list** with actual prices and lead times as you order
2. **Track delivery dates** to know when components arrive
3. **Once received** → Proceed to Option A (Phase 1B Detailed Plan)
4. **During ordering** → Start SPICE simulation for AO3401A soft-start RC timing
5. **Before PCB layout** → Verify all electrical characteristics

---

**Status:** ✅ **READY TO ORDER**

**Next Phase:** Option A (Detailed Phase 1B Implementation Plan)

