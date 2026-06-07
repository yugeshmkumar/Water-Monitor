# Bill of Materials — PROTOTYPE BUILD (Phase 1C)

**Purpose:** Bringup and electrical validation  
**Status:** DNP = Do Not Populate (saves cost/BOM on prototype)  
**Populate Status:** Yes/No/Optional (clear for builder)

---

## Component List

| Ref | Part | Value/Package | Qty | Mount | Populate | Cost | Notes |
|-----|------|---------------|-----|-------|----------|------|-------|
| **U1** | Seeed XIAO ESP32-C6 | Module on 0.1" sockets | 1 | TH | ✅ YES | $15 | Main MCU |
| **U2** | SR04M-2 (AJ-SR04M) | Ultrasonic, **120 kΩ resistor required** | 1 | Via J2 | ✅ YES | $12 | **CRITICAL: Verify 120 kΩ mode resistor soldered on sensor board before use** |
| **U_temp** | DS18B20 | Temperature sensor, TO-92 | 1 | TH | 🟡 OPTIONAL | $1 | For temperature compensation (±0.09% distance error reduction) |
| **F1** | RXE110 | Polyfuse 1.1 A radial | 1 | TH | ✅ YES | $0.50 | Limits inrush current |
| **Q1** | NDP6020P | Logic-level P-FET, TO-220 | 1 | TH | ✅ YES | $1 | Reverse-polarity protection; **orientation critical: Drain←in, Source→out, Gate←GND via R5** |
| **R5** | 100 kΩ ¼ W | Q1 gate resistor | 1 | TH | ✅ YES | $0.05 | Soft-start RC timing |
| **D1** | SMBJ5V0A | 600 W TVS, DO-214AB | 1 | TH | ✅ YES | $0.30 | **Rev G: Replaces P6KE6.8A for better thermal derating** |
| **D2** | 1N5819 | 1 A Schottky, axial | 1 | TH | ✅ YES | $0.10 | Back-feed isolation (prevents adapter damage on USB power) |
| **C1** | 680 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.40 | Bulk energy storage |
| **C2** | 100 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.20 | XIAO 5V pin decoupling |
| **C3** | 100 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.20 | Sensor rail decoupling |
| **C4** | 100 nF | Ceramic disc, 5 mm pitch | 1 | TH | ✅ YES | $0.05 | Adapter input node HF bypass |
| **C5** | 100 nF | Ceramic disc | 1 | TH | ✅ YES | $0.05 | XIAO supply node HF bypass |
| **C6** | 100 nF | Ceramic disc | 1 | TH | ✅ YES | $0.05 | Sensor supply node HF bypass |
| **FB1** | Ferrite bead | 600 Ω @ 100 MHz, leaded | 1 | TH | ✅ YES | $0.20 | Sensor rail isolation from XIAO rail |
| **R1** | 100 Ω ¼ W | Sensor RX series resistor | 1 | TH | ✅ YES | $0.05 | GPIO21 protection (ESP→Sensor) |
| **R2** | 100 Ω ¼ W | Sensor TX series resistor | 1 | TH | ✅ YES | $0.05 | GPIO20 protection (Sensor→ESP) |
| **R3** | 10 kΩ ¼ W | TX divider (to GND) | 1 | TH | ✅ YES | $0.05 | Voltage divider lower leg (5V→1.67V) |
| **R4** | 20 kΩ ¼ W | TX divider (to sensor TX) | 1 | TH | ✅ YES | $0.05 | Voltage divider upper leg |
| **R6** | 4.7 kΩ ¼ W | DS18B20 pull-up | 1 | TH | 🟡 IF U_temp | $0.05 | One-wire pull-up (only if DS18B20 fitted) |
| **SW1** | Tactile switch | 6 mm, 2-pin | 1 | TH | ✅ YES | $0.20 | Reset/setup button (10 s hold = factory reset) |
| **J1** | Screw terminal OR GX12 | 2-pin power entry, radial | 1 | Panel | ✅ YES | $1 | Weatherproof power input connector |
| **J2** | M12 4-pin connector | Sensor UART interface | 1 | Panel | ✅ YES | $2 | Industrial standard sensor interface |
| **U3** | TPL5010 | Watchdog IC, SOT-23-6 SMD | 1 | SMD | ❌ **DNP** | $0.80 | **Prototype only: Do NOT populate.** Optional on production rev 1 |
| **D3** | PESD5V0 | ESD protection diode, SMD | 1 | SMD | ❌ **DNP** | $0.10 | **Prototype only: Do NOT populate.** Needed on production (field ESD risk) |
| **D4** | PESD3V3 | ESD protection diode, SMD | 1 | SMD | ❌ **DNP** | $0.10 | **Prototype only: Do NOT populate.** Needed on production (GPIO20 latch-up prevention) |
| **PCB** | 2-layer, 100 × 60 mm | HASL, 1.6 mm FR-4 | 1 | Fab | ✅ YES | $5–10 | Gerber files from hardware/ directory |
| **Enclosure** | IP65 ABS plastic box | ≥100 × 70 × 50 mm | 1 | Mech | ✅ YES | $8 | Houses PCB + power supply (must be dry) |
| **Cable Glands** | PG7 / PG9 | Waterproof cable entries | 2 | Mech | ✅ YES | $0.50 | Sensor cable + power cable entry holes |
| **Power Supply** | 5V / 2A USB adapter | BIS/ISI certified, 5V ±5% | 1 | Ext | ✅ YES | $12 | External (NOT included in kit) |

---

## Summary

**Total Components to Populate:** 26 items  
**DNP Components (save cost):** 3 items (U3, D3, D4)  
**Optional Components:** 1 item (U_temp DS18B20)

**Total Cost (Prototype):** ~$50–60 per unit  
(excluding external power supply)

---

## Assembly Notes

### Solder Order (by height, lowest first)
1. Diodes (D1, D2) — flat profile
2. Resistors (R1–R6) — thin
3. Capacitors (C1–C6)
4. Polyfuse (F1)
5. P-FET (Q1, TO-220)
6. Tactile button (SW1)
7. Connectors (J1, J2) — last
8. XIAO module on sockets — very last

### Critical: DO NOT POPULATE (Prototype)
- [ ] U3 (TPL5010 watchdog) — Leave this empty
- [ ] D3 (PESD5V0 ESD) — Leave this empty
- [ ] D4 (PESD3V3 ESD) — Leave this empty

These are **populated only on Production Revision 1**, not prototype.

---

## Pre-Build Checklist

- [ ] Count all components against this BOM
- [ ] **Verify SR04M-2 has 120 kΩ resistor soldered on board** (most critical!)
- [ ] Check polarity of diodes (D1, D2)
- [ ] Confirm P-FET Q1 orientation: Drain ← supply input (not source!)
- [ ] Verify ferrite bead FB1 is NOT a capacitor
- [ ] Check capacitor voltage ratings (all ≥16V)

---

**Status:** Ready for Phase 1C prototype build  
**Related File:** See [BOM_PRODUCTION.md](BOM_PRODUCTION.md) for production version with ESD populated

