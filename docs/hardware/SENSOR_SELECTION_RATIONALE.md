# Sensor Selection Rationale — SR04M-2 vs JSN-SR04T

**Date:** 2026-06-07  
**Status:** PHASE 1 ARCHITECTURE DECISION

---

## Summary

Water Monitor **Phase 1 uses SR04M-2** (triggered UART mode), not JSN-SR04T (pulse-width mode). This document explains why.

| Aspect | JSN-SR04T (OLD) | SR04M-2 (REV G) |
|--------|-----------------|-----------------|
| **Interface** | Pulse-width (TRIG + ECHO) | Triggered UART (command: 0x55) |
| **Power** | 5V | 5V or 3.3V |
| **Measurement Latency** | Every 60 ms (free-running) | On demand (0–120 ms) |
| **GPIO Count** | 2 pins (TRIG + ECHO) | 2 pins (TX + RX), but shared UART |
| **Filtering Complexity** | Pulse timing calibration (harder) | Frame validation + trimmed-mean (easier) |
| **MCU Load** | Higher (interrupt-driven echo timing) | Lower (UART handles framing) |
| **Blind Zone** | 20–25 cm (standard ultrasonic) | 20–25 cm (same transducer) |
| **Max Range (5V)** | ~5 m | ~6 m |
| **Cost** | ~₹350 | ~₹12 (sensor head only) |
| **Availability** | ✓ Readily available | ⚠️ AJ-SR04M family variants; mode resistor often DNP |

---

## Why SR04M-2 (Triggered UART)?

### 1. **Cleaner Signal Path**

**JSN-SR04T (pulse-width):**
```
  MCU                           Sensor
  GPIO2 (TRIG output)
    │ (15 µs pulse)
    ├─────────────────────────▶ [Fires 40 kHz burst]
                                    │
                                    └─▶ [Waits for echo]
                                        [Measures time of flight]
                                        │
  GPIO1 (ECHO input)            [Outputs time-proportional pulse]
    │ (reads pulse width)
    ◀─────────────────────────── [100–4500 µs pulse]
    │
    [MCU calculates: distance = (pulse_width / 2) / 29.1]
```

**Issues:**
- MCU must precisely capture edge timings (interrupt handler runs at 80 MHz, ~12.5 ns resolution)
- Temperature compensation requires external calculation
- Noisy edges (reflections) cause pulse-width jitter

**SR04M-2 (triggered UART):**
```
  MCU                           Sensor (STM8 microcontroller)
  GPIO21 (TX, 0x55 command)
    │
    ├─────────────────────────▶ [Triggers measurement]
                                    │
                                    └─▶ [Internal: fires burst, times echo]
                                        [Calculates distance internally]
                                        [Builds 4-byte frame with checksum]
                                        │
  GPIO20 (RX, data)             [Sends 0xFF, DataH, DataL, SUM]
    │ (reads 4 bytes)
    ◀─────────────────────────── [9600 baud UART]
    │
    [MCU checks: (0xFF + H + L) & 0xFF == SUM]
    [distance_mm = (DataH << 8) | DataL]
```

**Advantages:**
- Sensor itself performs echo timing (STM8 is stable, optimized for this task)
- Frame format eliminates ambiguity (0xFF sync byte)
- Built-in checksum (99.6 % error detection)
- No interrupt-driven timing on ESP32 (cleaner firmware)

---

### 2. **Reduced MCU Overhead**

**Pulse-width approach (JSN-SR04T):**
- Requires **timer + ISR** to capture ECHO pulse edges
- Edge timestamps subject to ISR jitter (OS scheduler, WiFi radio interrupts)
- Temperature compensation calculated in software

**Triggered UART approach (SR04M-2):**
- Uses **standard UART peripheral** (existing in every MCU)
- Sensor STM8 microcontroller handles timing (dedicated, real-time)
- Temperature compensation optional (sensor can be equipped with internal thermometer)

**Impact:** Easier firmware, fewer timing-critical sections, better overall stability.

---

### 3. **Online Learning + Validation**

Because the sensor sends a **frame** (not a raw pulse), the firmware can:
- Validate checksum (reject corrupted packets immediately)
- Detect sensor mode misconfig (if frame format changes)
- Implement trimmed-mean filtering over multiple frames
- Combine with statistical validator (dual-criterion rejection, trend analysis)

Pulse-width approach requires:
- Software median/mean over raw distances
- No per-sample validation (bad reading indistinguishable from electrical noise)

---

### 4. **Availability & Serviceability**

**JSN-SR04T:**
- Single vendor (likely re-branded from another manufacturer)
- If sensor fails, entire sensor unit fails

**SR04M-2 (AJ-SR04M family):**
- AJ-SR04M base module
- Multiple compatible variants (A02YYUW, A01NYUB, etc.) with same UART interface
- Future-proof: if one variant goes EOL, firmware-only switch to another
- **Caveat:** Mode resistor often left unpopulated in shipping; bench-test required before use

---

## Trade-offs

| Aspect | JSN-SR04T | SR04M-2 |
|--------|-----------|---------|
| **Pulse-width jitter** | ±2 cm typical | ±0.5 cm (with trimmed-mean) |
| **Firmware complexity** | Medium (timer ISR) | Low (UART + validation) |
| **Sensor complexity** | None (no onboard MCU) | Medium (STM8 inside) |
| **Blind zone** | 20–25 cm | 20–25 cm (same) |
| **Max range** | ~5 m | ~6 m |
| **Temperature compensation** | External only | Optional internal DS18B20 |
| **Frame validation** | None | Checksum (99.6% error detection) |

**Winner for Phase 1:** SR04M-2 (triggered UART) — cleaner firmware, better error detection, future-proof.

---

## Implementation Notes

1. **Mode Resistor:** SR04M-2 ships with mode pad often **unpopulated**. Must solder 120 kΩ resistor on sensor board before firmware testing:
   - 47 kΩ → continuous mode (replies every 60 ms, power-hungry)
   - **120 kΩ → triggered mode (on-demand, energy-efficient)**

2. **UART Configuration:**
   - Baud: 9600
   - Data: 8 bits, no parity, 1 stop
   - Frame: `0xFF, DataH, DataL, SUM`
   - Checksum: `SUM = (0xFF + H + L) & 0xFF`

3. **Distance Calculation:**
   ```cpp
   // Triggered mode response
   uint16_t distance_mm = (data[1] << 8) | data[2];  // DataH, DataL
   
   // Optional temperature compensation
   float distance_corrected = distance_mm * (331.4f + 0.6f * temp_c) / 343.0f;
   
   // Bounds checking (blind zone + max range)
   if (distance_mm >= 200 && distance_mm <= 6000) { /* valid */ }
   ```

4. **Firmware Validation:**
   - Send: `0x55` (trigger command)
   - Wait: 120 ms for response
   - Read: 4 bytes `0xFF, H, L, SUM`
   - Validate: `(0xFF + H + L) & 0xFF == SUM`
   - Parse: `distance_mm = (H << 8) | L`

---

## References

- **AJ-SR04M Datasheet** — Triggered UART frame format, mode selection, timing
- **JSN-SR04T Datasheet** — Pulse-width interface, trigger timing (for reference)
- **HARDWARE_REV_G.md** — Full schematic and wiring for SR04M-2 implementation

---

**Decision:** SR04M-2 (triggered UART) selected for Phase 1.  
**Rationale:** Cleaner firmware, built-in error detection, better long-term stability.  
**Review Date:** 2026-06-07 (Design Review Rev G)
