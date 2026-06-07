# Bill of Materials — PRODUCTION BUILD (Phase 1F, Revision 1)

**Purpose:** Field deployment and mass production  
**Status:** All ESD protection populated; optional watchdog for extended reliability  
**Production Phase:** After Phase 1E environmental testing complete

---

## Component List

| Ref | Part | Value/Package | Qty | Mount | Populate | Cost | Notes |
|-----|------|---------------|-----|-------|----------|------|-------|
| **U1** | Seeed XIAO ESP32-C6 | Module on 0.1" sockets | 1 | TH | ✅ YES | $15 | Main MCU |
| **U2** | SR04M-2 (AJ-SR04M) | Ultrasonic, **120 kΩ resistor** | 1 | Via J2 | ✅ YES | $12 | **MANDATORY: Mode resistor must be soldered** |
| **U_temp** | DS18B20 | Temperature sensor, TO-92 | 1 | TH | ✅ YES | $1 | Recommended for ±4% accuracy improvement |
| **F1** | RXE110 | Polyfuse 1.1 A radial | 1 | TH | ✅ YES | $0.50 | Inrush current limiting |
| **Q1** | NDP6020P | Logic-level P-FET, TO-220 | 1 | TH | ✅ YES | $1 | Reverse-polarity protection |
| **R5** | 100 kΩ ¼ W | Q1 gate resistor | 1 | TH | ✅ YES | $0.05 | Soft-start timing |
| **D1** | SMBJ5V0A | 600 W TVS, DO-214AB | 1 | TH | ✅ YES | $0.30 | **Production standard (better derating than P6KE)** |
| **D2** | 1N5819 | 1 A Schottky, axial | 1 | TH | ✅ YES | $0.10 | Back-feed isolation |
| **C1** | 680 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.40 | Bulk energy storage |
| **C2** | 100 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.20 | XIAO decoupling |
| **C3** | 100 µF / 16 V | Radial electrolytic | 1 | TH | ✅ YES | $0.20 | Sensor decoupling |
| **C4** | 100 nF | Ceramic disc, 5 mm | 1 | TH | ✅ YES | $0.05 | HF bypass (input) |
| **C5** | 100 nF | Ceramic disc | 1 | TH | ✅ YES | $0.05 | HF bypass (XIAO supply) |
| **C6** | 100 nF | Ceramic disc | 1 | TH | ✅ YES | $0.05 | HF bypass (sensor supply) |
| **FB1** | Ferrite bead | 600 Ω @ 100 MHz, leaded | 1 | TH | ✅ YES | $0.20 | Sensor/XIAO isolation |
| **R1** | 100 Ω ¼ W | Sensor RX series | 1 | TH | ✅ YES | $0.05 | ESP→Sensor protection |
| **R2** | 100 Ω ¼ W | Sensor TX series | 1 | TH | ✅ YES | $0.05 | Sensor→ESP protection |
| **R3** | 10 kΩ ¼ W | TX divider lower | 1 | TH | ✅ YES | $0.05 | Voltage divider |
| **R4** | 20 kΩ ¼ W | TX divider upper | 1 | TH | ✅ YES | $0.05 | Voltage divider |
| **R6** | 4.7 kΩ ¼ W | DS18B20 pull-up | 1 | TH | ✅ YES | $0.05 | One-wire pull-up (for U_temp) |
| **SW1** | Tactile switch | 6 mm, 2-pin | 1 | TH | ✅ YES | $0.20 | Reset/setup button |
| **J1** | Screw/GX12 connector | 2-pin power | 1 | Panel | ✅ YES | $1 | Weatherproof power entry |
| **J2** | M12 4-pin connector | Sensor UART | 1 | Panel | ✅ YES | $2 | Industrial interface |
| **U3** | TPL5010 | Watchdog IC, SOT-23-6 | 1 | SMD | 🟡 **OPTIONAL** | $0.80 | **Recommended for extended field reliability; can DNP to reduce cost** |
| **D3** | PESD5V0 | ESD diode, SMD | 1 | SMD | ✅ **POPULATE** | $0.10 | **REQUIRED: Field ESD risk (wet M12 connector on roof)** |
| **D4** | PESD3V3 | ESD diode, SMD | 1 | SMD | ✅ **POPULATE** | $0.10 | **REQUIRED: Prevents GPIO20 latch-up from transients** |
| **PCB** | 2-layer, 100 × 60 mm | HASL, 1.6 mm FR-4 | 1 | Fab | ✅ YES | $5–10 | Final production PCB |
| **Enclosure** | IP65 ABS box | ≥100 × 70 × 50 mm | 1 | Mech | ✅ YES | $8 | Field-grade protection |
| **Cable Glands** | PG7 / PG9 | Waterproof entries | 2 | Mech | ✅ YES | $0.50 | Sensor + power cable sealing |
| **Power Supply** | 5V / 2A adapter | BIS/ISI certified, ±5% | 1 | Ext | ✅ YES | $12 | External (NOT in kit) |

---

## Key Differences from Prototype

| Component | Prototype | Production | Reason |
|-----------|-----------|------------|--------|
| **D3 PESD5V0** | ❌ DNP | ✅ POPULATE | ESD protection critical in wet field environment |
| **D4 PESD3V3** | ❌ DNP | ✅ POPULATE | Prevents GPIO20 latch-up in transient-rich environment (urban roof) |
| **U3 TPL5010** | ❌ DNP | 🟡 OPTIONAL | Extended reliability; recommended but can omit for cost savings |
| **Testing** | Electrical validation | Field deployment | Production must pass 72h soak + humidity + condensation |

---

## Summary

**Total Components:** 29 items  
**Populate Count:** 26 (all required) + 1 optional (U3 watchdog)  
**DNP Count:** 0 (none in production)

**Production Cost (with ESD, without watchdog):** ~$60–65 per unit  
**Production Cost (with ESD + watchdog):** ~$61–66 per unit  
(excluding external power supply)

---

## Assembly Instructions

### SMD Component Soldering (D3, D4, U3)

**Method 1: Reflow (Recommended for volume)**
1. Apply solder paste to D3, D4, U3 pads
2. Place components (DO-214AB and SOT-23-6 footprints)
3. Reflow in oven (standard lead-free profile, 260°C peak)
4. Cool and inspect

**Method 2: Hand Solder (1–5 units)**
1. Tin one pad per component with solder iron
2. Use tweezers to hold component while heating tinned pad
3. Solder remaining leads

### Quality Check (Production)

- [ ] **Visual inspection:** All SMD solder joints are shiny, no bridges
- [ ] **Continuity test:** D3/D4 continuity confirmed (use multimeter in diode mode)
- [ ] **Watchdog test (if U3 populated):** TPL5010 watchdog strobing on GPIO19 (oscilloscope check)
- [ ] **ESD test:** Zener clamps verified with curve tracer (if available)

---

## Field Deployment Checklist

Before shipping to customer:
- [ ] All components soldered and tested per electrical validation suite
- [ ] 72h soak test passed (no hangs, stable heap, reasonable sensor readings)
- [ ] Humidity test passed (M12 connector dry, no water ingress)
- [ ] Temperature swing test passed (readings ±1 cm across 5–45°C with DS18B20)
- [ ] Firmware programmed with correct WiFi SSID/pass (if pre-configured)
- [ ] Unit labeled with serial number, build date, firmware version
- [ ] Enclosure gasket intact, cable glands tight

---

**Status:** Production-ready after Phase 1E validation  
**Related File:** See [BOM_PROTOTYPE.md](BOM_PROTOTYPE.md) for prototype version (D3/D4 DNP)

