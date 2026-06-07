# Water Monitor Phase 1B — KiCad Schematic Completion Guide

**Date:** 2026-06-07  
**Status:** Ready for KiCad entry  
**Reference Files:**
- `SCHEMATIC_NETLIST.txt` — Complete net list and connections
- `SCHEMATIC_DIAGRAM.txt` — ASCII circuit diagram  
- `water-monitor-rev-g.kicad_sch` — Template schematic file (partial)

---

## 🚀 Quick Start (30 minutes)

### Option A: Import Template (Recommended)
1. Download KiCad (free): https://www.kicad.org/download/
2. Open KiCad project manager
3. Create new project in `firmware/tank-sensor/kicad/` folder
4. Copy `water-monitor-rev-g.kicad_sch` into project
5. Open the schematic file and follow **"Complete the Schematic"** section below

### Option B: Build from Scratch
1. Create new KiCad project
2. Follow **"Component Addition"** section below step-by-step

---

## 📋 COMPONENT ADDITION (In Order)

### Sheet 1: Power Distribution

#### Step 1: Add Power Connector
- **Menu:** Place → Connector → Conn_01x02_Pin
- **Label:** J1 (GX12 power connector)
- **Position:** (50.8 mm, 25.4 mm)
- **Orientation:** Normal (0°)
- **Purpose:** External 5V/2A input

#### Step 2: Add Polyfuse
- **Symbol:** Device → R (use as placeholder for polyfuse)
- **Label:** F1
- **Value:** TRA110 30V 1.1A
- **Position:** (76.2 mm, 25.4 mm)
- **Orientation:** Vertical (90°)
- **Purpose:** Soft inrush current limiting

#### Step 3: Add TVS Diode
- **Symbol:** Device → D (diode symbol)
- **Label:** D1
- **Value:** SMBJ5V0A
- **Position:** (101.6 mm, 25.4 mm)
- **Orientation:** Vertical (90°)
- **Purpose:** Reverse polarity protection

#### Step 4: Add Schottky Diode
- **Symbol:** Device → D
- **Label:** D2
- **Value:** 1N5819
- **Position:** (76.2 mm, 38.1 mm)
- **Orientation:** Vertical (90°)
- **Purpose:** Back-feed isolation

#### Step 5: Add P-FET
- **Symbol:** Device → Q_PMOS_GSD (or similar)
- **Label:** Q1
- **Value:** AO3401A
- **Position:** (127 mm, 25.4 mm)
- **Orientation:** Normal (0°)
- **Purpose:** Soft-start control

#### Step 6: Add Gate Pull-Up Resistor
- **Symbol:** Device → R
- **Label:** R5
- **Value:** 100kΩ 1/4W 5%
- **Position:** (127 mm, 38.1 mm)
- **Orientation:** Vertical (90°)
- **Purpose:** P-FET gate pull-up

#### Step 7: Add Decoupling Capacitors
Add 6 capacitors at these positions:

**C1 (Bulk)**
- **Symbol:** Device → C
- **Value:** 680µF/16V
- **Position:** (50.8 mm, 50.8 mm)
- **Purpose:** Bulk energy storage

**C2, C3 (Mid-Range)**
- **Symbol:** Device → C
- **Value:** 100µF/16V
- **Positions:** 
  - C2: (76.2 mm, 50.8 mm)
  - C3: (101.6 mm, 50.8 mm)
- **Purpose:** Mid-range decoupling

**C4, C5, C6 (High-Frequency)**
- **Symbol:** Device → C
- **Value:** 100nF
- **Positions:**
  - C4: (50.8 mm, 63.5 mm)
  - C5: (76.2 mm, 63.5 mm)
  - C6: (101.6 mm, 63.5 mm)
- **Purpose:** HF bypass

---

### Sheet 2: Sensor Interface (UART)

#### Step 8: Add M12 Sensor Connector
- **Symbol:** Connector_Generic → Conn_01x04_Pin
- **Label:** J2
- **Value:** M12_4PIN_SENSOR
- **Position:** (152.4 mm, 25.4 mm)
- **Orientation:** Normal (0°)
- **Pin Assignment:**
  - Pin 1: +5V (sensor power)
  - Pin 2: GND (sensor ground)
  - Pin 3: RX (sensor data return)
  - Pin 4: TX (sensor trigger)

#### Step 9: Add Ferrite Bead
- **Symbol:** Device → L (inductor, as placeholder)
- **Label:** FB
- **Value:** 1kΩ@100MHz
- **Position:** (127 mm, 50.8 mm)
- **Orientation:** Horizontal (0°)
- **Purpose:** UART RX isolation

#### Step 10: Add Series Resistors (TX/RX Protection)
**R1 (TX Series)**
- **Symbol:** Device → R
- **Label:** R1
- **Value:** 100Ω 1/4W 5%
- **Position:** (127 mm, 63.5 mm)
- **Orientation:** Vertical (90°)

**R2 (RX Series)**
- **Symbol:** Device → R
- **Label:** R2
- **Value:** 100Ω 1/4W 5%
- **Position:** (127 mm, 76.2 mm)
- **Orientation:** Vertical (90°)

#### Step 11: Add Voltage Divider (5V → 3.3V)
**R3 (Upper Leg)**
- **Symbol:** Device → R
- **Label:** R3
- **Value:** 10kΩ 1/4W 5%
- **Position:** (152.4 mm, 50.8 mm)
- **Orientation:** Vertical (90°)

**R4 (Lower Leg)**
- **Symbol:** Device → R
- **Label:** R4
- **Value:** 20kΩ 1/4W 5%
- **Position:** (152.4 mm, 63.5 mm)
- **Orientation:** Vertical (90°)

---

### Sheet 3: Microcontroller & Control

#### Step 12: Add XIAO ESP32-C6
- **Symbol:** MCU → XIAO_ESP32C6 (or create custom symbol)
- **Label:** U1
- **Value:** XIAO ESP32-C6
- **Position:** (76.2 mm, 88.9 mm)
- **Orientation:** Normal (0°)
- **Critical Pins:**
  - VCC (pin 1) → +5V rail
  - GND (pins 20) → GND star
  - GPIO21 (D3) → UART TX
  - GPIO20 (D9) → UART RX
  - GPIO8 (D0) → Reset button

#### Step 13: Add Reset Button
- **Symbol:** Device → SW_Push
- **Label:** SW1
- **Value:** TACTILE_6MM
- **Position:** (101.6 mm, 101.6 mm)
- **Orientation:** Normal (0°)
- **Purpose:** Factory reset trigger

---

## ⚡ WIRING CONNECTIONS

### Power Rails

#### +5V Rail (from polyfuse output F1.2)
Connect to:
- [ ] D1.A (TVS anode)
- [ ] C1.+ (bulk capacitor)
- [ ] C2.+ (decoupling 1)
- [ ] C3.+ (decoupling 2)
- [ ] Q1.S (P-FET source)
- [ ] J2.1 (sensor +5V)
- [ ] U1.VCC (XIAO 5V input)

**Implementation:**
1. Place net label "+5V" on each connection
2. KiCad auto-connects same-labeled nets

#### GND Rail (Star point at J1.2)
Connect to:
- [ ] D1.K (TVS cathode)
- [ ] D2.K (Schottky cathode)
- [ ] C1.- (all capacitor negatives)
- [ ] C2.-, C3.-, C4.-, C5.-, C6.-
- [ ] Q1.G → through R5 → GND
- [ ] J2.2 (sensor ground)
- [ ] U1.GND (XIAO ground pins)
- [ ] SW1.2 (button return)

**Implementation:**
1. Create net label "GND" on all ground connections
2. Consider adding "GND_STAR" label at J1.2 for clarity

### Signal Nets

#### UART_TX (GPIO21 output)
Connection path: U1.GPIO21 → R3.1 → R4.1 → J2.4

**Steps:**
1. Add net label "UART_TX_OUT" at U1.GPIO21 pin
2. Add net label "UART_TX_DIV" at R3-R4 junction
3. Wire R1.2 to J2.4, add net label "UART_TX"

#### UART_RX (GPIO20 input)
Connection path: J2.3 → FB → R2 → U1.GPIO20

**Steps:**
1. Add net label "UART_RX" at J2.3 (sensor RX output)
2. Wire J2.3 → FB → R2 → U1.GPIO20
3. Add intermediate labels for clarity

#### RESET (GPIO8 input)
Connection path: SW1.1 → U1.GPIO8

**Steps:**
1. Add net label "RESET" at SW1.1
2. Wire to U1.GPIO8
3. Add note: "Pull-up already internal in XIAO"

---

## 🏷️ NET LABELS (Complete List)

Add these labels to create automatic net connectivity:

```
Power Nets:
  +5V        → All power nodes
  GND        → All ground nodes
  GND_STAR   → J1.2 (polyfuse return)

Signal Nets:
  UART_TX_OUT    → U1.GPIO21
  UART_TX_DIV    → R3-R4 junction
  UART_TX        → J2.4
  UART_RX        → J2.3, R2, U1.GPIO20
  
Control Nets:
  RESET          → SW1.1, U1.GPIO8
  SOFT_START     → Q1.D
  SOFT_START_RC  → Q1.G, R5
```

---

## ✅ FINAL CHECKLIST

Before generating netlist:

- [ ] All components placed and labeled correctly
- [ ] All power (+5V) nets connected and labeled
- [ ] All ground (GND) nets connected and labeled
- [ ] UART nets complete: TX, RX, divider
- [ ] Reset button wired to GPIO8
- [ ] No dangling (unconnected) pins
- [ ] All resistor values correct (especially divider R3=10k, R4=20k)
- [ ] All capacitor values correct
- [ ] Decoupling capacitors placed in correct order
- [ ] Polyfuse (F1) between power and TVS/Schottky
- [ ] TVS (D1) and Schottky (D2) oriented correctly
- [ ] P-FET (Q1) gate connected through R5 to ground
- [ ] Ferrite bead on UART RX line only
- [ ] Series resistors (R1, R2) on UART lines
- [ ] Voltage divider (R3, R4) configured as 5V → 3.3V

---

## 📊 VERIFICATION & EXPORT

### Electrical Rules Check (ERC)
1. **Menu:** Tools → Electrical Rules Check
2. **Action:** Run check, fix any errors
3. **Common errors:**
   - Unconnected pins → OK if intentional (WiFi antenna, unused GPIO)
   - Conflicting net names → Rename to match

### Generate Netlist
1. **Menu:** Tools → Generate Netlist
2. **Format:** Spice (for simulation) OR KiCad native (for PCB)
3. **Save as:** `water-monitor-rev-g.net`
4. **Next step:** PCB layout (Phase 1B-2)

### Export to PDF
1. **Menu:** File → Print / Export as PDF
2. **Options:** Include all layers, high DPI (600 DPI)
3. **Save as:** `WATER_MONITOR_REV_G_SCHEMATIC.pdf`
4. **Use for:** Documentation, manufacturing reference

---

## 🎨 SCHEMATIC STYLE GUIDE

### Colors & Symbols
- **Power (+5V):** Red lines, +5V labels in red boxes
- **Ground (GND):** Black lines, GND labels in black boxes
- **Signals:** Green lines, signal labels in green boxes
- **NC (No Connect):** X symbol at unconnected pins

### Layout
- **Power supply:** Top section (left to right: J1 → F1 → D1 → Q1)
- **Decoupling:** Bottom section (capacitor cascade)
- **Sensor interface:** Right section (J2, FB, R1-R4)
- **Microcontroller:** Center-right (U1, SW1)

### Documentation
- Add text annotations for:
  - "GND STAR POINT" at J1.2 junction
  - "5V → 3.3V DIVIDER" near R3-R4
  - "SOFT-START RC" near Q1-R5
  - "UART ISOLATION" near FB

---

## 📦 COMPLETE SCHEMATIC STATS

```
Total Components: 19
├─ Connectors: 2 (J1, J2)
├─ Resistors: 6 (F1, R1-R5)
├─ Capacitors: 6 (C1-C6)
├─ Diodes: 2 (D1, D2)
├─ Transistors: 1 (Q1)
├─ Inductors (Ferrite): 1 (FB)
├─ ICs: 1 (U1)
└─ Switches: 1 (SW1)

Total Nets: 8
├─ Power: +5V, GND
├─ Signals: UART_TX, UART_RX, RESET
├─ Internal: SOFT_START, SOFT_START_RC, UART_TX_DIV

Total Pins: 42
├─ Power: 20 pins
├─ Ground: 12 pins
├─ Signals: 10 pins
```

---

## 🔧 TROUBLESHOOTING

### "Unconnected Pin" Error
**Cause:** Pin has no net assigned  
**Fix:** Add net label or wire to connected net

### "Conflicting Net Names"
**Cause:** Same net called "+5V" and "+5V_IN" in different places  
**Fix:** Standardize net names (use "+5V" everywhere)

### "ERC Warning: Power symbol not connected"
**Cause:** +5V or GND symbol not wired  
**Fix:** This is normal for power rails using net labels. Suppress warning.

### Symbol Not Found
**Cause:** Component symbol doesn't exist in library  
**Fix:** Create custom symbol or substitute similar component

---

## 📚 Reference Documentation

- **HARDWARE_REV_G.md** — Electrical specifications, pin assignments
- **SCHEMATIC_NETLIST.txt** — Complete connection list
- **SCHEMATIC_DIAGRAM.txt** — ASCII circuit diagrams
- **SR04M-2 Datasheet** — Sensor UART protocol, timing
- **AO3401A Datasheet** — P-FET specs, soft-start RC calculation
- **XIAO ESP32-C6 Pinout** — GPIO assignment, recommended uses

---

## 🎯 NEXT STEPS

1. ✅ Complete schematic in KiCad (this guide)
2. ⏳ Generate netlist
3. ⏳ Create PCB layout (Phase 1B-2, ~1 week)
4. ⏳ Generate Gerber files for manufacturing
5. ⏳ Order PCB from fab (JLC.PCB, Seeedstudio, etc.)
6. ⏳ Assemble prototype (soldering, testing)
7. ⏳ Firmware integration & field testing (Phase 1B-4)

---

**Status:** Schematic template ready for completion  
**Estimated Time:** 30-60 minutes with KiCad  
**Support:** Reference files above for any questions  

✅ **Ready to begin!**
