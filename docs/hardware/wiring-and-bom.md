# Hardware — Wiring and Bill of Materials

---

## Node A — Sensor Unit

### JSN-SR04T → XIAO ESP32-C6 Wiring

```
JSN-SR04T                         XIAO ESP32-C6
─────────────────────────────────────────────────
5V ────────────────────────────── 5V  (USB pass-through)
GND ───────────────────────────── GND
TRIG ──────────────────────────── D2  (GPIO2)
                                       [3.3V output drives 5V trigger — safe]

ECHO ──[1kΩ]──┬────────────────── D1  (GPIO1, INPUT)
              │
            [2kΩ]
              │
             GND
             [voltage divider: 5V × 2kΩ/3kΩ = 3.33V → safe for ESP32-C6]
```

### Why the Voltage Divider is Required

The JSN-SR04T is powered from 5V. In Mode 0, the ECHO output pulses at supply voltage (5V). The ESP32-C6 GPIO inputs are rated **3.3V maximum**. Connecting 5V directly will damage GPIO1 over time.

The 1kΩ + 2kΩ resistor divider reduces 5V to 3.33V — just above the HIGH threshold, fully readable by the ESP32.

**If your JSN-SR04T is marked V2.0:** some batches output 3.3V logic even when powered from 5V. The divider is still recommended as a safe default.

### Component Placement

- Solder the two resistors on a small piece of perfboard between the JSN-SR04T cable and the XIAO header, or place on a breadboard for prototyping.
- Keep wires to the sensor as short as practical to reduce noise.
- The JSN-SR04T probe head is waterproof (IP67); mount it pointing down through the tank lid or an enclosure gland.
- The XIAO + resistors board goes in an IP65 enclosure outside the water.

---

## Bill of Materials — Node A

| Item | Qty | Approx. Cost (INR) | Notes |
|---|---|---|---|
| Seeed Studio XIAO ESP32-C6 | 1 | ₹650 | Main controller |
| JSN-SR04T ultrasonic sensor (Mode 0) | 1 | ₹350 | Waterproof; keep at Mode 0 (no strap resistor change needed) |
| 1kΩ resistor (¼W) | 1 | ₹1 | ECHO voltage divider — upper leg |
| 2kΩ resistor (¼W) | 1 | ₹1 | ECHO voltage divider — lower leg |
| Small perfboard (~3×4 cm) | 1 | ₹15 | For resistor assembly |
| IP65 ABS enclosure (≥100×60×25 mm) | 1 | ₹200 | Protects PCB at rooftop |
| 5V USB-C power supply (≥1A) | 1 | ₹300 | Weatherproof if exposed outdoors |
| USB-C cable (data-capable) | 1 | ₹100 | For flashing and power |
| M3 standoffs (×4) | 4 | ₹20 | Mount XIAO inside enclosure |
| PG7 cable gland | 2 | ₹30 | Sensor cable + power cable entry into enclosure |
| **Total** | | **~₹1,670** | |

---

## Bill of Materials — Node B (Phase 2)

| Item | Qty | Approx. Cost (INR) | Notes |
|---|---|---|---|
| Seeed Studio XIAO ESP32-C6 | 1 | ₹650 | Motor controller |
| Opto-isolated relay module (5V, 10A) | 1 | ₹150 | HW-482 or SRD-05VDC-SL-C based |
| DIN rail enclosure | 1 | ₹500 | Near motor distribution board |
| 5V USB-C power supply (≥1A) | 1 | ₹300 | |
| **Total** | | **~₹1,600** | |

> **Safety note:** The relay module switches the motor circuit. The ESP32 only drives the low-voltage (5V) signal pin. Never connect mains voltage to any ESP32 pin directly. Always use an opto-isolated relay module.

---

## Pin Reference (Node A)

| Signal | Arduino pin | GPIO | Direction | Notes |
|---|---|---|---|---|
| Sensor TRIG | D2 | GPIO2 | Output | 3.3V HIGH pulse, 15µs |
| Sensor ECHO | D1 | GPIO1 | Input | Via 1kΩ+2kΩ divider; reads HIGH on echo return |
| Status LED | LED_BUILTIN | GPIO15 | Output | Blinks on each sensor reading |
| ⛔ RF switch | — | GPIO3 | — | WIFI_ENABLE — DO NOT USE |
| ⛔ RF switch | — | GPIO14 | — | WIFI_ANT_CONFIG — DO NOT USE |

---

## JSN-SR04T Sensor Specs (Mode 0)

| Parameter | Value |
|---|---|
| Operating voltage | 5V |
| Measuring range | 20 – 500 cm |
| Beam angle | ~45° cone |
| Mode 0 interface | HC-SR04 compatible (TRIG + ECHO) |
| Trigger pulse | 10–15µs HIGH on TRIG |
| Echo output | HIGH pulse duration ∝ distance |
| IP rating | IP67 (probe head) |
| Cable length | ~2.5 m (standard) |
