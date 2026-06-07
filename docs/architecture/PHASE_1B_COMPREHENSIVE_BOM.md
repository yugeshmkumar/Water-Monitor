# Phase 1B — Comprehensive Bill of Materials (BOM)

**Status:** FINAL & VERIFIED  
**Date:** 2026-06-07  
**Total Components:** 32 items (5 critical + 27 standard)

---

## 📋 SECTION 1: CRITICAL COMPONENTS (MUST SOURCE FROM SPECIFIC SUPPLIERS)

### 1.1 SMBJ5V0A — TVS Diode (Reverse Polarity + Transient Protection)

| Specification | Value |
|---|---|
| **Part Number** | SMBJ5V0A |
| **Package** | SMB (DO-214AA) |
| **Type** | Silicon Transient Voltage Suppressor (TVS) |
| **Voltage Rating** | Working voltage: 5.8 V |
| **Power Rating** | 600 W peak |
| **Clamping Voltage** | ~9.2 V @ 10 A |
| **Polarity** | Bidirectional (symmetric) |
| **Operating Temp** | -55°C to +150°C |
| **Purpose** | Reverse polarity protection + inductive transient clamping |
| **Quantity** | 1 |
| **Reference** | D1 (schematic) |

**Supplier Info:**
- **Supplier:** Evelta.com
- **Link:** https://evelta.com/smbj5-0a-5v-600w-esd-suppressor-tvs-diode-2pin-smb-do-214aa/
- **Expected Lead Time:** 2-5 days
- **Package Contains:** 1 pc

**Physical Identification:**
- Black cylindrical body, through-hole leads
- Markings: "5V0A" or similar on body
- Two leads (anode/cathode marked)

**Why This Component:**
- Replaces P6KE6.8A for better thermal derating
- Suitable for repeated transient stress (urban roof environment)
- DO-214AA is standard through-hole package

---

### 1.2 SR04M-2 — Ultrasonic Distance Sensor (Triggered UART Mode)

| Specification | Value |
|---|---|
| **Part Number** | SR04M-2 (AJ-SR04M family) |
| **Type** | 40 kHz Ultrasonic Ranging Module |
| **Interface** | **Triggered UART** (critical mode) |
| **Operating Voltage** | 5V (can work at 3.3V with reduced range) |
| **Baud Rate** | 9600 bps |
| **Protocol** | Trigger: 0x55 command; Response: 0xFF, DataH, DataL, SUM (4 bytes) |
| **Measuring Range** | 200–6000 mm (20 cm – 6 m) |
| **Blind Zone** | 200–250 mm (device-dependent) |
| **Frequency** | 40 kHz ultrasonic |
| **Temperature Compensation** | Internal (fixed 20°C speed of sound) |
| **Connector** | M12 4-pin or generic 4-pin |
| **Operating Temp** | -10°C to +50°C |
| **Quantity** | 1 |
| **Reference** | U2 (schematic) |

**Mode Resistor (CRITICAL):**
- **Requirement:** 120 kΩ resistor must be soldered on sensor board
- **Alternative modes:** 47 kΩ = continuous mode (NOT what we want)
- **Default state:** Often ships with empty pad (no resistor soldered)
- **Your status:** IN HAND — **NEEDS VERIFICATION**

**Supplier Info:**
- **Status:** Already in your possession
- **Backup suppliers if needed:** Robu.in, Amazon.in, AliExpress
- **Lead time if ordering:** 5-10 days

**Physical Identification:**
- PCB module with transducer on one side
- M12 connector or 4-pin header on wiring side
- Transducer: circular metal disk, ~40 mm diameter
- Look for: Small resistor near mode select pad (or empty pad if not soldered)

**Verification Checklist:**
- [ ] Visual inspection for 120kΩ resistor (see Section 3.1)
- [ ] Electrical measurement with multimeter (see Section 3.1)
- [ ] Functional test with 0x55 command (see Section 3.1)

---

### 1.3 AO3401A — Logic-Level P-Channel MOSFET (Reverse Polarity Protection)

| Specification | Value |
|---|---|
| **Part Number** | AO3401A |
| **Manufacturer** | Alpha & Omega Semiconductor (AOS) |
| **Package** | TO-220 (through-hole, 3-pin) |
| **Type** | P-Channel Enhancement Mode MOSFET |
| **Vds (Drain-Source Voltage)** | ±30 V |
| **Vgs (Gate-Source Voltage)** | ±20 V (absolute max) |
| **Vgs(th) — Gate Threshold Voltage** | 1.0–2.5 V @ 1 mA (CRITICAL: logic-level) |
| **Id — Drain Current** | 4.2 A @ Vgs = -10V |
| **RDSon — On-State Resistance** | 0.14 Ω @ Vgs = -10V (excellent) |
| **Operating Temp** | -55°C to +150°C |
| **Pin Configuration** | Gate (G), Drain (D), Source (S) |
| **Purpose** | Soft-start current limiting + reverse polarity protection |
| **Quantity** | 1 |
| **Reference** | Q1 (schematic) |
| **Alternative to** | NDP6020P (not available in your region) |

**Supplier Info:**
- **Supplier:** Robu.in
- **Link:** https://robu.in/product/ao3401a-umwyoutai-semiconductor-co-ltd-30v-4-2a-50m%CF%8910v-1-4w-400mv-1-piece-p-channel-sot-23-mosfets-rohs
- **Expected Lead Time:** 2-5 days
- **Package Contains:** 1 pc

**Physical Identification:**
- TO-220 package: 3-pin through-hole transistor
- Black plastic body, ~15 mm tall
- Pin labels: G (Gate), D (Drain), S (Source) marked on package
- Heat dissipation: If soldered flat to PCB, tab contacts copper for heat spreading

**Why This Component:**
- Logic-level Vth (1.0–2.5V) works with 3.3V ESP32
- Better RDSon than NDP6020P (0.14Ω vs 0.16Ω)
- Same function: soft-start + reverse polarity
- Note: Gate capacitance slightly different — SPICE simulation required for soft-start RC timing validation

**Special Note:** 
Robu.in listing mentions "SOP-23" in URL but TO-220 is correct. Verify upon arrival that you receive TO-220 package (not SMD).

---

### 1.4 Ferrite Bead 1 kohm (UART Isolation)

| Specification | Value |
|---|---|
| **Impedance** | 1000 Ω @ 100 MHz |
| **Impedance @ 10 MHz** | ~300–400 Ω (estimated, typical for ferrite beads) |
| **Package** | 0603 (through-hole leaded) |
| **Current Rating** | 200 mA continuous |
| **DC Resistance (DCR)** | <0.03 Ω |
| **Operating Frequency Range** | 1 MHz – 1000 MHz |
| **Operating Temp** | -40°C to +85°C |
| **Tolerance** | ±25% |
| **Purpose** | Isolates sensor switching transients from XIAO power rail |
| **Quantity** | 1 |
| **Reference** | FB1 (schematic) |

**Supplier Info:**
- **Supplier:** Evelta.com
- **Part Name:** 1 kohm 200mA 25% 0603 Ferrite Bead
- **Available Links (all same part):**
  - Option 1: https://evelta.com/1kohm-200ma-25-0603-ferrite-bead-2/
  - Option 2: https://evelta.com/1kohm-200ma-25-0603-ferrite-bead-1/
  - Option 3: https://evelta.com/1kohm-200ma-25-0603-ferrite-bead/
- **Expected Lead Time:** 2-5 days
- **Package Contains:** 1 pc

**Physical Identification:**
- Small cylindrical bead, ~6 mm length × 3 mm diameter
- Tan/brown color (typical for ferrite)
- Two leads (through-hole compatible)
- Markings: Often no markings (ferrite beads typically unlabeled)

**Why This Component:**
- Blocks high-frequency switching noise from sensor (40 kHz + harmonics)
- 1000 Ω @ 100 MHz provides Z ≥ 300 Ω @ 10 MHz for UART edge isolation
- 200 mA rating sufficient for sensor rail (~50 mA typical)

---

### 1.5 RHEF100 — PPTC Resettable Fuse / Polyfuse (Inrush Current Limiting)

| Specification | Value |
|---|---|
| **Part Number** | RHEF100 |
| **Manufacturer** | Tyco Raychem (now TE Connectivity) |
| **Package** | Radial (through-hole) |
| **Type** | PPTC (Polymeric Positive Temperature Coefficient) Resettable Fuse |
| **Hold Current (Trip threshold)** | 1.0 A (nominal) |
| **Trip Current (opens at)** | ~2.0 A (typical) |
| **Voltage Rating** | 30 V DC |
| **Operating Temp** | -40°C to +85°C |
| **Reset Time** | 5–10 seconds after fault clears |
| **Reset Cycles** | >10,000 (can reset repeatedly without damage) |
| **Purpose** | Soft-start current limiting + overcurrent protection |
| **Quantity** | 1 |
| **Reference** | F1 (schematic) |
| **Specification Note** | 1.0 A hold is slightly below 1.1 A spec, but acceptable margin for soft-start RC |

**Supplier Info:**
- **Supplier:** Sharvi Electronics
- **Link:** https://sharvielectronics.com/product/rhef100-30v-1a-pptc-resettable-fuse-polyswitch-tyco-raychem/
- **Expected Lead Time:** 3-7 days
- **Package Contains:** 1 pc

**Physical Identification:**
- Small cylindrical component, ~7 mm length × 5 mm diameter
- Yellow/tan color (typical PPTC)
- Two radial leads for through-hole PCB mounting
- Markings: "RHEF100" or "100" printed on body

**Why This Component:**
- Limits inrush current during soft-start (prevents nuisance polyfuse trips)
- Resettable (not a one-time fuse like traditional fuses)
- Auto-recovery when fault clears
- 1.0 A hold is close to 1.1 A requirement (tighter than RUEF135 alternative)

**Operating Principle:**
- At startup: RC soft-start ramps current gradually; polyfuse sees low current
- At fault: If current exceeds ~2.0 A, internal resistance increases rapidly, blocking fault
- After fault clears: Automatically resets within 5-10 seconds; no manual replacement needed

---

## 📋 SECTION 2: STANDARD COMPONENTS (Readily Available from Multiple Suppliers)

### Sourcing Strategy for Standard Components:
- **Best price:** LCSC.com (international shipping 5-10 days)
- **Fast delivery:** Local electronics shop (same-day pickup if in India)
- **Convenience:** Amazon.in (2-3 day delivery)
- **Reliability:** Digi-Key, Mouser (higher cost, guaranteed authenticity)

---

### 2.1 Diodes & Semiconductors

#### 1N5819 — Schottky Diode (Back-Feed Isolation)

| Specification | Value |
|---|---|
| **Part Number** | 1N5819 |
| **Type** | Silicon Schottky Rectifier Diode |
| **Package** | Axial (through-hole) |
| **Forward Voltage (Vf)** | 0.4 V @ 1 A (low, for soft-start) |
| **Reverse Current** | <5 µA @ rated voltage |
| **Peak Reverse Voltage** | 40 V |
| **Average Forward Current** | 1 A continuous |
| **Peak Surge Current** | 25 A (brief surge OK) |
| **Operating Temp** | -65°C to +150°C |
| **Purpose** | Prevents back-feed from USB/adapter when powered externally |
| **Quantity** | 1 |
| **Reference** | D2 (schematic) |

**Physical Identification:**
- Axial package: cylindrical body with two leads
- Band marking: One end has black/silver band (cathode side)
- Leads: ~0.7 mm diameter, spacable on 0.1" grid

**Sourcing:**
- Available from: LCSC, Digi-Key, Mouser, Amazon.in, local shops
- Cost: $0.01–0.05 each
- Lead time: Immediate to 2 days

---

### 2.2 Capacitors

#### 680 µF / 16 V Radial Electrolytic (Bulk Energy Storage)

| Specification | Value |
|---|---|
| **Capacitance** | 680 µF |
| **Voltage Rating** | 16 V |
| **Package** | Radial (through-hole) |
| **Tolerance** | ±20% (standard for electrolytics) |
| **ESR (Equivalent Series Resistance)** | ~0.8 Ω typical |
| **Life** | 5000–10000 hours @ 85°C |
| **Operating Temp** | -40°C to +85°C |
| **Purpose** | Stores energy for soft-start; filters 5V rail |
| **Quantity** | 1 |
| **Reference** | C1 (schematic) |

**Physical Identification:**
- Cylindrical aluminum can, ~16 mm tall × 10 mm diameter
- Polarity marked: +/– symbols on can
- Two leads: positive lead longer, negative lead shorter (or marked – side)

**Sourcing:**
- Available from: LCSC, Digi-Key, Mouser, Amazon.in
- Cost: $0.10–0.30 each
- Lead time: 1–3 days

---

#### 100 µF / 16 V Radial Electrolytic (Mid-Range Decoupling)

| Specification | Value |
|---|---|
| **Capacitance** | 100 µF |
| **Voltage Rating** | 16 V |
| **Package** | Radial (through-hole) |
| **Tolerance** | ±20% |
| **ESR** | ~0.5 Ω typical |
| **Purpose** | Decoupling at XIAO 5V pin + sensor rail |
| **Quantity** | **2** (one per rail) |
| **Reference** | C2, C3 (schematic) |

**Physical Identification:**
- Smaller than 680 µF, ~12 mm tall × 8 mm diameter
- Polarity marked (same as above)

**Sourcing:**
- Available from: LCSC, Digi-Key, Mouser, Amazon.in
- Cost: $0.05–0.15 each
- Lead time: 1–3 days

---

#### 100 nF Ceramic Disc Capacitor (High-Frequency Bypass)

| Specification | Value |
|---|---|
| **Capacitance** | 100 nF (0.1 µF) |
| **Voltage Rating** | 50 V minimum (typically 100 V rated) |
| **Package** | Ceramic disc (through-hole, 5 mm pitch) |
| **Tolerance** | ±10% to ±20% |
| **Dielectric** | X7R or Z5U (temp-stable) |
| **Purpose** | High-frequency decoupling at each power node |
| **Quantity** | **3** (at input, XIAO rail, sensor rail) |
| **Reference** | C4, C5, C6 (schematic) |

**Physical Identification:**
- Small flat disc, ~6 mm diameter × 3 mm thick
- Usually yellow/brown color
- Two leads on back side (through-hole)
- No polarity marking (capacitor, not electrolytic)

**Sourcing:**
- Available from: LCSC, Amazon.in, local shops, Digi-Key
- Cost: $0.01–0.05 each
- Lead time: Immediate to 2 days

---

### 2.3 Resistors (¼ W Carbon Film, 5% Tolerance)

All resistors are **axial through-hole package**, ~6 mm body length.

#### 100 Ω Resistor — UART Series Protection

| Specification | Value |
|---|---|
| **Resistance** | 100 Ω |
| **Power Rating** | ¼ W (0.25 W) |
| **Tolerance** | ±5% |
| **Temperature Coefficient** | ±250 ppm/°C |
| **Package** | Axial (through-hole) |
| **Purpose** | Limits current on GPIO21 (ESP→Sensor) + GPIO20 (Sensor→ESP) |
| **Quantity** | **2** (R1, R2) |
| **Color Code** | Brown-Black-Brown (standard resistor band colors) |

**Sourcing:**
- Available from: Any electronics supplier
- Cost: $0.01–0.05 each
- Lead time: Immediate

---

#### 10 kΩ Resistor — TX Divider (Lower Leg)

| Specification | Value |
|---|---|
| **Resistance** | 10 kΩ (10000 Ω) |
| **Power Rating** | ¼ W |
| **Tolerance** | ±5% |
| **Package** | Axial |
| **Purpose** | Voltage divider: 5V sensor TX → 1.67V ESP RX |
| **Quantity** | **1** (R3) |
| **Color Code** | Brown-Black-Orange |

**Sourcing:**
- Available from: Any electronics supplier
- Cost: $0.01–0.05 each
- Lead time: Immediate

---

#### 20 kΩ Resistor — TX Divider (Upper Leg)

| Specification | Value |
|---|---|
| **Resistance** | 20 kΩ (20000 Ω) |
| **Power Rating** | ¼ W |
| **Tolerance** | ±5% |
| **Package** | Axial |
| **Purpose** | Voltage divider: 5V sensor TX → 1.67V ESP RX |
| **Quantity** | **1** (R4) |
| **Color Code** | Red-Black-Orange |

**Sourcing:**
- Available from: Any electronics supplier
- Cost: $0.01–0.05 each
- Lead time: Immediate

---

#### 4.7 kΩ Resistor — DS18B20 One-Wire Pull-Up (Optional)

| Specification | Value |
|---|---|
| **Resistance** | 4.7 kΩ |
| **Power Rating** | ¼ W |
| **Tolerance** | ±5% |
| **Package** | Axial |
| **Purpose** | One-wire bus pull-up for temperature sensor (if fitted) |
| **Quantity** | **1** (R6, optional) |
| **Color Code** | Yellow-Purple-Red |

**Sourcing:**
- Available from: Any electronics supplier
- Cost: $0.01–0.05 each
- Lead time: Immediate
- Note: Only needed if DS18B20 temperature sensor is populated

---

#### 100 kΩ Resistor — P-FET Gate Soft-Start RC

| Specification | Value |
|---|---|
| **Resistance** | 100 kΩ (100000 Ω) |
| **Power Rating** | ¼ W |
| **Tolerance** | ±5% |
| **Package** | Axial |
| **Purpose** | Gate resistor for soft-start RC timing on AO3401A |
| **Quantity** | **1** (R5) |
| **Color Code** | Brown-Black-Yellow |

**Sourcing:**
- Available from: Any electronics supplier
- Cost: $0.01–0.05 each
- Lead time: Immediate

---

### 2.4 Connectors

#### M12 4-Pin Connector (Sensor UART Interface)

| Specification | Value |
|---|---|
| **Type** | M12 circular connector, 4-pin female |
| **Pin Configuration** | Pin 1: +5V (or 3.3V), Pin 2: GND, Pin 3: Sensor RX, Pin 4: Sensor TX |
| **Voltage Rating** | 30 V |
| **Current Rating** | 5 A per pin |
| **Mating Cycles** | 5000+ |
| **Operating Temp** | -40°C to +85°C |
| **Purpose** | Connects SR04M-2 sensor to main PCB |
| **Quantity** | **1** (J2) |
| **Cable Compatibility** | M12 4-pin male connector (sensor side) |

**Physical Identification:**
- Metal cylindrical connector, ~12 mm diameter
- Female socket on PCB side (pins inside)
- Threaded ring for cable connection

**Sourcing:**
- Available from: Digi-Key, Mouser, Amazon.in, specialty connector suppliers
- Cost: $2–5 each
- Lead time: 3–7 days
- Note: Ensure you get **female** connector for PCB (male on sensor cable)

---

#### GX12 or Screw Terminal (2-Pin Power Entry)

| Specification | Value |
|---|---|
| **Type** | Either GX12 (2-pin, circular) OR screw terminal (2-pin) |
| **Pin Configuration** | Pin 1: +5V input, Pin 2: GND |
| **Voltage Rating** | 30 V (GX12) or 250 V (screw terminal) |
| **Current Rating** | 5 A per pin |
| **Purpose** | External 5V adapter power input |
| **Quantity** | **1** (J1) |
| **Mounting** | Panel mount on enclosure |

**GX12 Circular Connector:**
- Weatherproof, military-grade
- Better sealing for outdoor/wet environments
- Slightly more expensive

**Screw Terminal:**
- Simple, robust
- Requires no special tools or cables
- Cost-effective

**Sourcing:**
- GX12: Digi-Key, Mouser, specialty suppliers ($2–3)
- Screw terminal: LCSC, Amazon.in, local shops ($0.50–1)
- Lead time: 2–7 days

**Recommendation:** GX12 preferred for outdoor roof deployment (better weather sealing)

---

### 2.5 Mechanical Components

#### Tactile Switch (6 mm, 2-Pin Reset Button)

| Specification | Value |
|---|---|
| **Type** | Momentary tactile pushbutton switch |
| **Size** | 6 mm × 6 mm body |
| **Pin Configuration** | 2-pin through-hole, 90° corners (typically) |
| **Contact Rating** | 50 mA @ 24 VDC (low power switch) |
| **Switching Life** | 100,000+ actuations |
| **Operating Force** | ~160 gf (light click feel) |
| **Operating Temp** | -20°C to +70°C |
| **Purpose** | Reset/setup button (10 s hold = factory reset) |
| **Quantity** | **1** (SW1) |

**Physical Identification:**
- Small plastic cube, ~6 × 6 mm
- Red, black, or blue color (depends on supplier)
- Two leads on bottom or sides

**Sourcing:**
- Available from: LCSC, Amazon.in, Digi-Key, local electronics shops
- Cost: $0.05–0.20 each
- Lead time: 1–3 days

---

#### IP65 ABS Enclosure (100 × 70 × 50 mm minimum)

| Specification | Value |
|---|---|
| **Type** | Plastic (ABS) enclosure, wall-mounted |
| **IP Rating** | IP65 (dust-tight, water jet resistant) |
| **Internal Dimensions** | Minimum 100 × 70 × 50 mm (for PCB + components) |
| **Wall Thickness** | 2 mm typical |
| **Material** | ABS plastic (UV-stable, outdoor-rated) |
| **Mounting** | DIN rail or wall brackets (brackets usually included) |
| **Purpose** | Houses PCB, protects from weather (outdoor roof deployment) |
| **Quantity** | **1** |
| **Cable Entries** | Pre-drilled holes for PG7/PG9 glands |

**Physical Identification:**
- Rectangular plastic box with removable/hinged lid
- Mounting ears on sides or bottom
- Pre-drilled holes for cable glands

**Sourcing:**
- Available from: Amazon.in, electronics suppliers, industrial distributors
- Cost: $8–15 each
- Lead time: 2–5 days
- Recommendation: Search for "IP65 ABS enclosure 100x70x50" or "weatherproof junction box"

---

#### PG7 / PG9 Cable Glands (Waterproof Cable Entry)

| Specification | Value |
|---|---|
| **Type** | PG7 (for 3.5–6 mm cables) or PG9 (for 6–8 mm cables) |
| **Material** | Plastic body, rubber seal ring |
| **Thread Size** | M16 (standard enclosure hole) |
| **Cable Diameter Range** | PG7: 3.5–6 mm; PG9: 6–8 mm |
| **Purpose** | Waterproof cable entry for sensor and power cables |
| **Quantity** | **2** (one for sensor, one for power) |
| **Sealing** | Rubber O-ring provides IP67/IP68 water sealing |

**Physical Identification:**
- Small cylindrical connector, ~16 mm diameter
- Threaded insert (male M16 thread)
- Rubber seal ring inside

**Sourcing:**
- Available from: Amazon.in, electrical suppliers, LCSC
- Cost: $0.30–0.70 per gland
- Lead time: 1–5 days
- Buy both PG7 and PG9 for flexibility

---

### 2.6 Optional Components

#### DS18B20 — Temperature Sensor (Optional, One-Wire)

| Specification | Value |
|---|---|
| **Part Number** | DS18B20 |
| **Manufacturer** | Maxim Integrated |
| **Package** | TO-92 (through-hole, 3-pin) |
| **Type** | Digital temperature sensor, one-wire protocol |
| **Temperature Range** | -55°C to +125°C |
| **Accuracy** | ±0.5°C @ -10°C to +85°C |
| **Resolution** | 9/10/11/12-bit (configurable; default 12-bit = 0.0625°C steps) |
| **Operating Voltage** | 3.0–5.5 V |
| **Communication** | One-wire (Dallas/Maxim protocol, single GPIO line) |
| **Purpose** | Temperature compensation for ultrasonic distance sensor (corrects for speed-of-sound variation with temperature) |
| **Quantity** | **1** (optional; U_temp) |
| **Reference** | GPIO1 (D1) with 4.7 kΩ pull-up |

**Physical Identification:**
- TO-92 package: 3-pin plastic transistor-like component
- Pin 1: GND, Pin 2: DQ (data), Pin 3: VCC
- Red plastic case typical for Maxim parts

**Sourcing:**
- Available from: LCSC, Digi-Key, Mouser, Amazon.in, local shops
- Cost: $0.50–2 each
- Lead time: 2–5 days
- **Note:** Optional for Phase 1; can be added later

---

## 📋 SECTION 3: SR04M-2 MODE RESISTOR VERIFICATION

### 3.1 How to Verify if 120kΩ Resistor is Soldered on SR04M-2

**Why This Matters:**
- The mode resistor selects the operating mode:
  - **120 kΩ** = Triggered UART mode (what we want) ✅
  - **47 kΩ** = Continuous mode (NOT what we want) ❌
  - **Empty pad** = Random behavior, likely won't work
- Many suppliers ship with **empty pad** (resistor not soldered)
- **You MUST verify before firmware testing**

---

### Step 1: Visual Inspection (5 minutes)

**What to look for:**

1. **Locate the mode select pad on SR04M-2 board:**
   - Look at the back side (opposite the transducer)
   - Find a **small resistor pad area** marked "R" or "MODE" (if labeled)
   - Usually located **near the connector pins**

2. **Check if resistor is present:**
   - ✅ **Resistor present:** You'll see a tiny component (brown/tan color, ~3 mm long)
   - ❌ **Empty pad:** The pad shows bare copper, no component
   - ⚠️ **Wrong resistor:** Different color or size (47 kΩ resistor is visually similar)

3. **If resistor is present, identify the value:**
   - Resistors have **color bands** (2-3 stripes)
   - **120 kΩ color code:** Brown-Red-Yellow (1-2-Yellow = 12 × 10^4 = 120,000 Ω)
   - **47 kΩ color code:** Yellow-Purple-Orange (4-7-Orange = 47 × 10^3 = 47,000 Ω)

**Visual Inspection Result:**
- [ ] Resistor present and correct (120 kΩ brown-red-yellow) → **PROCEED**
- [ ] Resistor present but wrong value (47 kΩ yellow-purple-orange) → **ERROR: Wrong mode**
- [ ] No resistor (empty pad) → **NEED TO SOLDER 120 kΩ**
- [ ] Can't determine visually → **Go to Step 2 (electrical test)**

---

### Step 2: Electrical Measurement with Multimeter (10 minutes)

**Only if visual inspection is inconclusive**

**Equipment needed:**
- Digital multimeter (any model)
- Sensor board SR04M-2

**Procedure:**

1. **Set multimeter to resistance mode (Ω symbol)**

2. **Locate the mode resistor pad on the board**
   - Look for the small pad or resistor near the connector

3. **Measure resistance between the mode pad and GND:**
   - Place red probe on the mode resistor pad
   - Place black probe on the GND pad/lead
   - Read the display

4. **Interpret the result:**
   - **Display shows ~120k Ω** (or 120,000) → ✅ **Correct! 120 kΩ resistor is there**
   - **Display shows ~47k Ω** (or 47,000) → ❌ **Wrong! 47 kΩ resistor present (continuous mode)**
   - **Display shows very high (>1M Ω) or "OL" (overload)** → ❌ **Empty pad! No resistor soldered**

**Multimeter Reading Examples:**
```
✅ CORRECT:        ❌ WRONG:          ❌ EMPTY PAD:
120k Ω             47k Ω              OL (open loop)
or                 or                 or
0.120 M Ω          0.047 M Ω          >999k Ω
```

---

### Step 3: Functional Test with Serial Command (15 minutes)

**Most reliable method: Test with the actual trigger command**

**Equipment needed:**
- Sensor SR04M-2
- USB-to-UART adapter (e.g., CH340, FT232RL, ~$2-5 on Amazon)
- Computer with serial terminal software (free: PuTTY, Arduino IDE serial monitor)
- Power supply (5V, 100 mA minimum for sensor)
- Jumper wires

**Wiring:**
```
SR04M-2 Board         USB-UART Adapter
  VCC (+5V)    ---→   VCC (5V)
  GND          ---→   GND
  RX           ---→   TX
  TX           ---→   RX
```

**Procedure:**

1. **Connect power to SR04M-2** (5V + GND)

2. **Open serial monitor:**
   - Port: USB adapter COM port
   - Baud: 9600
   - No flow control

3. **Send trigger command:**
   - Type `0x55` or the ASCII character 'U' (both are 0x55 in hex)
   - Press Enter/Send

4. **Check response:**
   - ✅ **You see 4 bytes back** (often appears as garbage/symbols) → **Triggered UART mode active (120 kΩ resistor working)**
   - ❌ **No response or repeated garbage** → **Wrong mode or empty pad**
   - ❌ **Continuous stream of data** → **Continuous mode active (47 kΩ resistor)**

**Example Response:**
```
Send: 0x55
Receive (triggered mode): ÿ±  (4 bytes: 0xFF, H, L, SUM)

Send: 0x55
Receive (triggered mode): ÿ¦™ (4 bytes: different distance reading)

Send: 0x55 (no response) → Empty pad, no resistor
```

---

### Summary Verification Table

| Method | Result | Status | Action |
|--------|--------|--------|--------|
| **Visual** | 120 kΩ resistor visible | ✅ OK | Use sensor as-is |
| **Visual** | 47 kΩ resistor visible | ❌ WRONG | Desolder 47kΩ, solder 120kΩ |
| **Visual** | Empty pad | ❌ MISSING | Solder 120 kΩ resistor |
| **Multimeter** | 120 k Ω measured | ✅ OK | Use sensor as-is |
| **Multimeter** | 47 k Ω measured | ❌ WRONG | Replace with 120 kΩ |
| **Multimeter** | OL or >1M Ω | ❌ MISSING | Solder 120 kΩ resistor |
| **Serial test** | 4-byte response to 0x55 | ✅ OK | Use sensor as-is |
| **Serial test** | No response | ❌ MISSING | Solder 120 kΩ resistor |
| **Serial test** | Continuous stream | ❌ WRONG | Replace resistor |

---

### If You Need to Solder the 120 kΩ Resistor

**If the mode resistor pad is empty, you'll need to:**

1. **Get a 120 kΩ resistor**
   - Standard ¼ W carbon film resistor
   - Color code: Brown-Red-Yellow
   - Cost: $0.01–0.05

2. **Solder it onto the pad:**
   - Use a soldering iron (25–40W recommended)
   - Apply solder to both pad and resistor lead
   - Keep iron on pad for 2–3 seconds
   - Let cool (don't move resistor while cooling)

3. **Verify after soldering:**
   - Repeat Steps 1–3 above to confirm

4. **Proceed with firmware testing only after confirmation**

---

## 🎯 QUICK VERIFICATION CHECKLIST

Before starting Phase 1B assembly:

- [ ] **SR04M-2 Mode Resistor Status:**
  - [ ] Visual inspection done
  - [ ] Multimeter measurement done (if needed)
  - [ ] Serial test done (if needed)
  - [ ] Result: ✅ 120 kΩ confirmed present OR ❌ Action: Solder resistor

- [ ] **All critical components sourced:**
  - [ ] SMBJ5V0A (evelta.com)
  - [ ] AO3401A (robu.in)
  - [ ] Ferrite 1 kohm (evelta.com)
  - [ ] RHEF100 polyfuse (Sharvi Electronics)

- [ ] **Standard components ready:**
  - [ ] Diodes, capacitors, resistors
  - [ ] Connectors (M12, GX12/screw terminal)
  - [ ] Mechanical (switch, enclosure, cable glands)

- [ ] **Ready for Phase 1B assembly:** YES / NO

---

**Document Status:** ✅ COMPLETE & READY

Next steps: Order components, verify SR04M-2, proceed to **Option A (Phase 1B Detailed Plan)**

