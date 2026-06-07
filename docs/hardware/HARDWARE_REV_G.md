# Hardware — Water Level Monitor Rev G

**Status:** Optimized design with recommendations  
**Sensor:** SR04M-2 (AJ-SR04M family, triggered UART mode)  
**MCU:** Seeed XIAO ESP32-C6  
**Power:** External 5V adapter (2A, BIS/ISI certified)  
**Interface:** Dedicated UART on GPIO20/21, leaving GPIO16/17 for debug  

---

## 1. OVERVIEW

This document defines the production-ready hardware for the Water Level Monitor sensor unit (Node A). The design uses:

- **SR04M-2 ultrasonic distance sensor** in **triggered UART mode** (0x55 command triggers measurement, returns 4-byte frame)
- **Reverse-polarity protection** via logic-level P-FET (NDP6020P) with soft-start
- **Robust power conditioning** with TVS, ferrite isolation, and multi-tier decoupling
- **Level-shifted UART interface** with validated RC time constant (100 Ω + 10 k/20 k divider)
- **Dual watchdog** (internal ESP + optional external TPL5010)
- **Through-hole construction** wherever feasible (serviceability + field reworkability)

---

## 2. POWER SECTION

```
┌─────────────────────────────────┐
│   External 5V Adapter (2A)      │
│   BIS/ISI Certified             │
│   5V ±5%                        │
└──────────┬──────────────────────┘
           │
           ▼
     [J1 GX12 or Screw Terminal]
           │
           ▼
    [F1 RXE110 Polyfuse 1.1A]
           │
           ▼
┌──────────────────────────────────┐
│  Q1 NDP6020P (P-FET)             │
│  ┌──────────────────────────────┐│
│  │ Drain ← Adapter              ││
│  │ Source → +5V RAIL            ││
│  │ Gate ← GND via R5 (100kΩ)    ││
│  │ [RC soft-start, 3–5 ms]      ││
│  └──────────────────────────────┘│
└────┬─────────────────────────────┘
     │
     ▼
[D1 P6KE6.8A TVS (clamps ~10.5V)]  ⚠️ See note below
     │
     ├─ [C1 680µF // 100nF] ──▶ +5V RAIL
     │
     ├─▶ [D2 1N5819] ──▶ XIAO 5V pin
     │    [100µF // 100nF]
     │
     └─▶ [FB1 Ferrite] ──▶ SR04M-2 VCC
          [100µF // 100nF]
         
         ⭐ Star ground at C1 negative
```

### Component Details

| Component | Part | Rating | Notes |
|-----------|------|--------|-------|
| **J1** | GX12 or screw terminal | 2A @ 5V | Weatherproof connector, never use barrel jack in field |
| **F1** | RXE110 polyfuse | 1.1 A hold | Protects against short circuit; soft-start limits nuisance trips |
| **Q1** | NDP6020P | Logic-level P-FET, TO-220 | Gate: Vth = 2.5 V typical (rated for 3.3 V logic) |
| **R5** | 100 kΩ ¼ W | Gate resistor | RC soft-start time: τ = 100 kΩ × (gate cap ~100 pF) ≈ 10 ns; actual soft-start ~3–5 ms due to load capacitance (~880 µF bulk) |
| **D1** | **SMBJ5V0A** | 600 W TVS ⚠️ | **REVISED:** Replaces P6KE6.8A for improved thermal derating in transient-rich environments. Vwm = 5.8 V, clamps ~9.2 V |
| **D2** | 1N5819 | 1 A Schottky | Back-feed isolation; low forward drop (~0.4 V @ 100 mA) |
| **C1** | 680 µF / 16 V radial | Bulk capacitor | ESR ~0.8 Ω; mounted close to Q1 output |
| **C2, C3** | 100 µF / 16 V radial | Mid-range decoupling | One at XIAO 5V pin, one at sensor rail |
| **C4–C6** | 100 nF ceramic (×3) | High-frequency bypass | One at each power node (input, XIAO, sensor) |
| **FB1** | Ferrite bead, **1000 Ω @ 100 MHz** ⚠️ | **REVISED:** Impedance Z ≥ 300 Ω @ 10 MHz (UART edge rate) for proper sensor isolation. Common part: TDK MPZ1608S102A |

### Design Rationale

**Why P-FET for reverse polarity?**
- Body diode blocks reverse current when supply is reversed
- Soft-start via gate RC prevents inrush spike
- RDSon ~0.1 Ω → minimal voltage drop (50 mW @ 100 mA)
- Superior to series Schottky (0.3 V drop) or ideal diode IC (complexity, cost, failure mode)

**Why TVS at input (not just adapter protection)?**
- Protects against inductive kickback from tank control systems (relays, pumps nearby)
- SMBJ5V0A chosen for repeated transients (thermal stability vs single-pulse P6KE)
- Do not rely on adapter overcurrent protection alone

**Why ferrite bead on sensor rail?**
- Decouples sensor switching transients (40 kHz ± harmonic content) from XIAO rail
- 1000 Ω @ 100 MHz = ~300 Ω @ 10 MHz (UART edge frequency), provides actual isolation
- Prevents ground bounce on ESP RX pin during sensor TX transitions

---

## 3. SENSOR INTERFACE — TRIGGERED UART

The SR04M-2 communicates via **triggered UART mode** (47 k mode resistor produces continuous; **120 kΩ resistor selects triggered**):

```
┌─────────────────────────────┐                    ┌──────────────────┐
│   SR04M-2 (AJ-SR04M)        │                    │  XIAO ESP32-C6   │
│                             │                    │                  │
│ Pin 1: VCC (+5V or 3.3V)────┼──[FB1]──[C]───┬───┼─ +5V             │
│        (Mode: 120kΩ to GND)  │           [C] │   │                  │
│                             │               │   │                  │
│ Pin 2: GND──────────────────┼───────────────┼───┼─ GND (star)      │
│                             │               │   │                  │
│ Pin 3: RX (trigger input)───┼──[R 100Ω]────┼───┼─ GPIO21 (D3)     │
│        (ready for 0x55)     │               │   │ [3.3V output OK] │
│                             │               │   │                  │
│ Pin 4: TX (data output)─────┼──[R 100Ω]┬───┼───┼─ GPIO20 (D9)     │
│        [Level divider]       │          │   │   │ [via divider]    │
│                             │         [10k] │   │                  │
│                             │          │    │   │                  │
│                             │         [20k] │   │                  │
│                             │          │    │   │                  │
│                             │         GND───┴───┼─ GND             │
│                             │                    │                  │
└─────────────────────────────┘                    └──────────────────┘

Pin 4 TX voltage divider:
  V_out = 5V × 10/(10+20) = 1.67V (safe for 3.3V GPIO)
  RC time constant: 6.7kΩ || 20pF ≈ 135 ns (validated << 104 µs bit period @ 9600 baud)
```

### Wiring Table

| J2 Connector (4-pin M12) | Signal | XIAO Pin | Notes |
|--------------------------|--------|----------|-------|
| 1 | +5 V (or 3.3 V option) | Power | Via FB1 to sensor VCC |
| 2 | GND | GND | Star ground at PCB |
| 3 | Sensor RX | GPIO21 (D3) | 100 Ω series, direct 3.3 V (sensor pulls up internally) |
| 4 | Sensor TX | GPIO20 (D9) | 100 Ω + 10 k/20 k divider (5V → 1.67V) |

**UART Configuration:**
- Baud: 9600
- Data: 8 bits
- Parity: None
- Stop: 1 bit

### Triggered Mode Operation

```
MCU sends 0x55 on GPIO21 TX
    │
    ▼
[120 µs delay for sensor processing]
    │
    ▼
Sensor replies: 0xFF, DataH, DataL, SUM
                where SUM = (0xFF + H + L) & 0xFF
                distance_mm = (DataH << 8) | DataL
    │
    ▼
MCU reads on GPIO20 RX with 120 ms timeout
    │
    ▼
Checksum validated: SUM must equal calculated value
Distance bounds checked: 200 mm ≤ distance ≤ 6000 mm
```

### Level Shifting Validation

**ESP→Sensor (GPIO21, direct 3.3V through 100 Ω):**
- Sensor RX input has internal pull-up (rated for 5V CMOS)
- 3.3V from ESP reads as HIGH ✓
- 100 Ω protects ESP pin from overstress if sensor inputs are shorted

**Sensor→ESP (GPIO20, 10 k/20 k divider):**
- Sensor TX: 0 V (LOW) → divider output: 0 V → ESP reads LOW ✓
- Sensor TX: 5 V (HIGH) → divider output: 1.67 V → ESP reads HIGH ✓
- Divider impedance Thevenin = 6.7 kΩ
- Divider output impedance + 100 Ω series = 6.8 kΩ
- GPIO20 input capacitance: ~20 pF
- RC time constant: 6.8 kΩ × 20 pF = 136 ns
- UART bit period: 1 / 9600 = 104 µs
- Rise/fall time (3 τ): ~408 ns << 104 µs ✓ Clean transitions at 9600 baud

**ESD Protection (Production):**
- PESD5V0 on J2 connector side (5V side) — clamps >6.8V transients
- PESD3V3 on GPIO20 node — clamps >3.6V transients
- **Note:** DNP on prototype; **REQUIRED on revision 1 production** to prevent latch-up in wet deployments

### Option A vs Option B

| Aspect | Option A (5V + Divider) | Option B (3.3V, no divider) |
|--------|---------|---------|
| **Sensor Supply** | 5V via FB1 | 3.3V from XIAO regulator |
| **Transmit Drive** | 5V (high) | 3.3V (reduced) |
| **Max Range** | ~6000 mm | ~4500 mm (25% loss) |
| **Divider** | 10k/20k required | 0 Ω link (no divider) |
| **Recommendation** | **DEFAULT** (recommended) | Only if tank depth < 3m AND bench-verified |
| **Recommended Mount Height** | ≥300 mm above full level | ≥300 mm above full level |

**IMPORTANT:** Option B reduces max range significantly. **Default to Option A** unless you have measured your tank and confirmed that 4.5 m max range is sufficient.

---

## 4. USER INTERFACE

### Status LED (GPIO15, onboard)

Indicates system state via LED pattern:

| State | Pattern | Meaning |
|-------|---------|---------|
| **BOOTING** | Slow blink (500 ms period) | Firmware initializing, watchdog configured |
| **WIFI_CONNECTING** | Fast blink (120 ms period) | WiFi attempting to connect (non-blocking, runs in background) |
| **NORMAL** | Heartbeat (80 ms ON, 2920 ms OFF) | Operating normally, measurements flowing |
| **FAULT** | Double-blink (4 blinks per 1.2s cycle) | Sensor timeout or distance out of bounds |
| **CONFIG_ERROR** | Triple-blink (6 blinks per 1.2s cycle) | NVS config corrupted or calibration missing |

### Reset/Setup Button (GPIO2)

- **Short press (<10 s):** Ignored (debounce)
- **Long press (≥10 s):** Triggers factory reset
  - Clears WiFi credentials
  - Clears calibration constants
  - Restarts firmware (enters setup mode)
  - Useful for moving device to new location or network

---

## 5. PIN MAP

| Function | XIAO Pin | GPIO | Voltage | Direction | Notes |
|----------|----------|------|---------|-----------|-------|
| **Sensor RX (ESP TX, trigger)** | D3 | 21 | 3.3V | OUT | Sends 0x55 to sensor |
| **Sensor TX (ESP RX, reply)** | D9 | 20 | 1.67V (divider) | IN | Receives 4-byte frame from sensor |
| **Watchdog DONE** | D8 | 19 | 3.3V | OUT | Strobes TPL5010 watchdog (optional) |
| **Reset/Setup Button** | D2 | 2 | 3.3V (pulled up) | IN | Button pulls LOW; 10 s hold = factory reset |
| **Temperature (optional)** | D1 | 1 | 3.3V | DQ (one-wire) | DS18B20 one-wire interface (4.7 kΩ pull-up) |
| **Status LED** | — | 15 | 3.3V | OUT | Onboard LED (blink patterns above) |
| **Debug UART TX** | D6 | 16 | 3.3V | OUT | (Optional) Clean debug UART0 for service |
| **Debug UART RX** | D7 | 17 | 3.3V | IN | (Optional) Clean debug UART0 for service |
| **RESET** | RST | — | — | — | Connected to TPL5010 watchdog output (if populated) |
| **Reserved** | D10, A0 | 18, 0 | 3.3V | — | Free for future use |

**Important:** GPIO3 and GPIO14 are **RF switch control lines** (WiFi antenna, Bluetooth antenna) on the ESP32-C6. **Do NOT use for I/O.**

---

## 6. BILL OF MATERIALS

**Two separate BOM files for clarity:**

### 6A. Prototype Build (Phase 1C)
**See [BOM_PROTOTYPE.md](BOM_PROTOTYPE.md)** for complete component list

- **Status:** DNP (Do Not Populate) for U3, D3, D4 to save cost on bringup
- **Components to populate:** 26 required, 1 optional (DS18B20 for temperature)
- **Cost:** ~$50–60 per unit
- **Critical:** Verify SR04M-2 has 120 kΩ mode resistor soldered

### 6B. Production Build (Phase 1F, Revision 1)
**See [BOM_PRODUCTION.md](BOM_PRODUCTION.md)** for complete component list

- **Status:** POPULATE all components including ESD (D3, D4)
- **Components:** 26 required + 1 optional watchdog (U3)
- **Cost:** ~$61–66 per unit (includes ESD protection)
- **Field requirement:** Outdoor roof deployment with WiFi reliability concerns

### Quick Reference: What Changes from Prototype to Production

| Component | Prototype | Production | Why |
|-----------|-----------|------------|-----|
| **D3 PESD5V0** | ❌ DNP | ✅ POPULATE | ESD from wet M12 connector |
| **D4 PESD3V3** | ❌ DNP | ✅ POPULATE | GPIO20 latch-up prevention |
| **U3 TPL5010** | ❌ DNP | 🟡 OPTIONAL | Extended reliability (recommend populate) |

---

---

## 7. ASSEMBLY & MOUNTING

### PCB Assembly

1. **Solder through-hole components** in order of height:
   - Diodes (D1, D2) — lowest profile
   - Resistors (all), ferrite bead (FB1)
   - Capacitors (C1–C6)
   - Polyfuse (F1)
   - P-FET (Q1, TO-220) — heat-sink may be needed if transients are frequent
   - Tactile button (SW1)
   - Connectors (J1, J2) — last
   - XIAO module on 0.1" sockets (for easy removal)

2. **SMD components (DNP on prototype, populate on revision 1):**
   - U3 (TPL5010 watchdog)
   - D3, D4 (ESD protection)

3. **Optional:** Temperature sensor (U_temp, DS18B20) soldered in TO-92 package or on separate small adapter board

### Mounting in Tank

```
┌────────────────────────────────┐
│      Tank (e.g., 1.5 m deep)   │
│                                │
│  ┌──────────────────────────┐  │
│  │  Water Level (varies)    │  │
│  └──────────────────────────┘  │
│          ▲                      │
│          │ ≤ 300 mm max        │ (blind zone recovery)
│          │ (but ≥350 mm        │  (recommended)
│          │  recommended)        │
│          │                      │
│    ╔═════╩═════╗               │
│    ║ SR04M-2  ║ ◄─── Mounted on lid │
│    ║ Facing   ║      Clear of     │
│    ║ DOWN     ║      inlet/walls  │
│    ║ (probe)  ║      /floats      │
│    ╚═════╦═════╝               │
│          │                      │
│        M12 connector cable      │
│          │                      │
│    [PG7 gland on enclosure]    │
│          │                      │
│    ┌─────▼──────┐              │
│    │ IP65 Box   │              │
│    │ (PCB +     │              │
│    │  5V supply)│              │
│    └────────────┘              │
└────────────────────────────────┘
```

**Key requirements:**
- Transducer **centered** on tank lid, **facing downward**
- **≥300 mm above full water level** (clears 200–250 mm blind zone + 50 mm margin; **350+ mm recommended** for high-reliability)
- **Clear of:**
  - Tank inlet pipes (swirl pattern causes reflections)
  - Tank walls (max ±5 cm horizontal offset from center)
  - Floats, baffles, any mechanical obstruction
- **M12 connector cable:**
  - Keep **< 1 m length** to PCB (reduces EMI pickup)
  - Route **away from AC mains wiring** and pump contactor coils
  - If in high-EMI environment (relay/motor nearby): **apply ferrite clip** (~FT240-43 toroid) around cable ~5 cm from enclosure entry
- **Enclosure:**
  - IP65 minimum (IP67 preferred for prolonged rain/spray)
  - PG7/PG9 cable glands at entry points
  - Mounted on **dry, shaded** location (direct sunlight can overheat 5V supply)
  - **Star ground** inside enclosure — all GND returns to a single point at C1

### Temperature Compensation (Optional)

If DS18B20 is fitted:
```cpp
float distance_mm_corrected = raw_distance_mm * (331.4f + 0.6f * temp_celsius) / 343.0f;
```

The SR04M-2 sensor internally computes distance using a fixed ~20 °C speed-of-sound; this rescale corrects for actual air temperature.

**Temperature accuracy:** DS18B20 ±0.5 °C results in ±0.09 % distance error — negligible. But smoothing with a 3:1 IIR filter prevents temperature oscillation jitter from affecting level readings.

---

## 8. VALIDATION CHECKLIST

### Pre-Layout (Critical)

- [ ] **Mode resistor on SR04M-2:** Verify **120 kΩ resistor is populated** on sensor PCB (not left empty). Test with multimeter or scope that sensor replies to 0x55 command before proceeding.
- [ ] **TX voltage divider:** Measure voltage at GPIO20 node with 5V applied to divider. Should read **1.5–1.8 V** (target 1.67 V).
- [ ] **Ferrite bead impedance:** Confirm selected bead has Z ≥ 300 Ω @ 10 MHz (e.g., TDK MPZ1608S102A, 1000 Ω @ 100 MHz). Look up datasheet impedance curve.
- [ ] **Soft-start simulation:** Use SPICE model of NDP6020P + gate RC to verify inrush current < 1 A (should not trip 1.1 A polyfuse).

### Electrical Testing (Prototype)

- [ ] **Reverse-polarity test:** Apply 5V adapter in reverse polarity (swap supply leads). Board should be unharmed; power LED off. Verify Q1 body diode blocks reverse current (measure < 100 µA leakage).
- [ ] **Short-circuit test:** Short +5V rail to GND externally. Polyfuse F1 should trip (LED off, no smoke). After 30 s cool-down, remove short; board should auto-recover.
- [ ] **Q1 voltage drop:** Measure Vgs (gate to source) at full load (100 mA sensor + 50 mA XIAO = 150 mA). Should be **< 0.2 V**.
- [ ] **ESP RX node voltage:** With sensor powered, measure DC voltage at GPIO20 input. Should read **0.5–1.8 V** (rests at divider Thevenin ~1.67 V idle).
- [ ] **Distance accuracy:** Measure distance to objects at 0.3 m, 0.5 m, 1 m, 2 m, 3 m using tape measure. Sensor readings should match within **±1 cm**. If beyond ±2 cm, check for reflections or blind-zone issues.
- [ ] **USB-while-powered test:** Connect USB to XIAO while 5V adapter is running. Board should continue measuring (no lockup). Remove USB; measurements resume. Verify **no back-feed past D2** (D2 forward voltage drop blocks current returning to adapter).
- [ ] **Soft-start inrush:** Measure current draw during first 100 ms of power-up with current probe on +5V rail. Peak should be **< 1 A** (confirms RC soft-start working; if >1 A, polyfuse may nuisance-trip).

### Firmware Testing

- [ ] **OTA & rollback:** Upload new firmware via OTA; verify update applies. Trigger rollback; confirm old firmware restores.
- [ ] **WiFi recovery:** Disconnect WiFi. Verify device continues measuring & publishing locally (offline-first). Reconnect WiFi; device re-establishes connection without blocking measurements.
- [ ] **Auto-AP fallback:** (If implemented) With WiFi unavailable, verify device enters AP mode and allows re-configuration.
- [ ] **Sensor disconnect:** Unplug M12 connector during operation. LED should blink double (FAULT). Plug back in; LED returns to heartbeat (NORMAL).
- [ ] **10 s button hold:** Press reset button for 10 s. Device should factory-reset: WiFi credentials cleared, LED triple-blinks (CONFIG_ERR). Power cycle to re-enter setup mode.
- [ ] **LED states:** Boot → Slow blink; WiFi connecting → Fast blink; Normal → Heartbeat; Fault → Double-blink; Config error → Triple-blink. Each transition correct.

### Environmental Testing (Pre-Production)

- [ ] **72 h soak test:** Run device continuously for 72 hours in normal operation. Monitor:
  - No hangs or watchdog resets (check reset counter)
  - Stable heap usage (no memory leaks)
  - Reasonable sensor readings (spread < ±2 cm)
  - WiFi reconnects working smoothly
- [ ] **High-humidity test:** 24 h in 90 % RH chamber at 5 °C, then ramp to 30 °C. Verify:
  - M12 connector stays dry (no water ingress)
  - Enclosure gaskets intact
  - PCB condensation does not short any nodes
- [ ] **Tank-splash test:** Pour water near sensor (splash simulation). Confirm probe head is IP67 and water doesn't pool in cable gland.
- [ ] **Condensation test:** Warm device in humid environment; verify face of sensor transducer stays dry (facing downward helps).
- [ ] **Temperature swing:** Measure across 5–45 °C (if DS18B20 fitted). With temperature compensation, readings should track within **±1 cm** (validated against fixed reference distance).

---

## 9. TROUBLESHOOTING

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| **No LED blink on power-up** | Power not reaching XIAO; Q1 or F1 shorted | Check Vgs across Q1; measure across F1 for continuity |
| **LED stuck on (not blinking)** | Firmware crash or watchdog reset loop | Use USB serial monitor to check reset reason (brownout, watchdog, etc.) |
| **Distance reading always 0 or >6000 mm** | Sensor mode not triggered (120 kΩ resistor missing or wrong value) | Verify 120 kΩ resistor is soldered on SR04M-2 PCB; send 0x55 manually via serial monitor to test |
| **Sensor distance jumps ±10+ cm** | Reflections from walls/floats; sensor too close to full line | Reposition sensor away from walls; ensure ≥300 mm above water level |
| **WiFi never connects** | Credentials stored in NVS are wrong; wrong SSID/pass in firmware | Press reset button 10 s to clear NVS; re-upload firmware with correct SSID/pass |
| **USB port doesn't enumerate (can't flash)** | Firmware lockup; XIAO stuck in boot | Hold BOOT button while plugging in USB (forces ROM bootloader mode); re-flash |
| **Checksum errors in UART stream** | Mode resistor value wrong; sensor running in continuous mode (47 kΩ) | Verify 120 kΩ resistor; continuous mode will send frames without trigger, causing timing mismatches |

---

## 10. REFERENCES

1. **SR04M-2 / AJ-SR04M Datasheet** — Triggered UART triggered mode, frame format, mode resistor selection
2. **Espressif ESP32-C6 Datasheet** — GPIO electrical characteristics, UART peripheral, pin strapping
3. **onsemi NDP6020P Datasheet** — Logic-level P-FET gate threshold, RDSon, absolute maximum ratings
4. **Littelfuse RXE110 Datasheet** — Polyfuse hold current, trip curve
5. **Maxim DS18B20 Datasheet** — Temperature sensor accuracy, one-wire protocol
6. **TI TPL5010 Datasheet** — External watchdog IC, timing, reset output
7. **Design Review: DESIGN_REVIEW_REV_G.md** — Thermal derating, signal integrity validation, component optimization notes

---

**Document Status:** ✅ Production-ready  
**Last Updated:** 2026-06-07  
**Reviewed by:** Claude Code (design review reference DESIGN_REVIEW_REV_G.md)
