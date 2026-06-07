# Phase 1C — Hardware Commissioning & Testing Guide

**Date:** 2026-06-07  
**Status:** Ready for PCB Assembly  
**Duration:** 2-3 hours for complete commissioning  

---

## 📋 Pre-Commissioning Checklist

### Hardware Ready
- [ ] PCB arrived from fab
- [ ] All components soldered (per BOM)
- [ ] M12 connector soldered (sensor interface)
- [ ] GX12 connector soldered (power input)
- [ ] Reset button functional
- [ ] IP65 enclosure prepared
- [ ] SR04M-2 sensor has 120kΩ mode resistor (verified)
- [ ] External 5V/2A power supply ready

### Firmware Ready
- [ ] Latest firmware compiled and ready to flash
- [ ] USB cable ready for XIAO programming
- [ ] Serial monitor available (115200 baud, 8N1)

### Test Equipment
- [ ] Multimeter (voltage, continuity checks)
- [ ] USB-Serial adapter (if needed)
- [ ] Tape measure (for distance verification)
- [ ] Tank or container with water (for functional testing)
- [ ] WiFi router accessible (for WiFi testing)

---

## 🔧 PHASE 1: HARDWARE VERIFICATION (30 min)

### Step 1: Visual Inspection
```
[ ] All solder joints clean (no cold joints, bridges)
[ ] No bent component leads
[ ] M12 connector properly seated
[ ] GX12 connector properly seated
[ ] Polyfuse F1 visually intact
[ ] TVS D1 oriented correctly (band marks direction)
[ ] Schottky D2 oriented correctly
[ ] P-FET Q1 oriented correctly
[ ] Electrolytic caps C1-C3 oriented correctly (+ stripe visible)
[ ] No visible cracks on PCB
```

### Step 2: Power-On Test (BEFORE connecting sensor)
```
SAFETY: Disconnect sensor (M12) before power-on test
```

**Procedure:**
1. Connect 5V/2A power supply to GX12 connector
2. Observe LED indicator:
   - Expected: LED should turn ON during boot, then OFF
   - Problem: LED stays OFF → check power connection
   - Problem: LED stays ON → possible short circuit

3. Measure voltages with multimeter:
   - Polyfuse output (+5V rail): Should be 4.8–5.2V
   - Measure between GX12 pin 1 and pin 2
   - Record: __________ V

4. Check reverse-polarity protection:
   - Disconnect power
   - Swap GX12 connector (reverse polarity)
   - Apply power (should fail to boot)
   - Verify: TVS D1 should absorb current, no damage
   - Reconnect correctly, proceed

### Step 3: Soft-Start Verification
```
Measure inrush current during power-on
Equipment: Multimeter in current mode or inline ammeter
```

**Procedure:**
1. Set multimeter to current measurement (DC A, highest range)
2. Insert multimeter in series with power supply positive lead
3. Connect power supply
4. Observe peak current during first 100ms
   - Expected: <1.0A peak
   - Record: __________ A
   - Problem: >1.5A → possible short circuit or damaged component

5. After 1 second, current should drop to <100mA (idle)
   - Record: __________ mA

### Step 4: Boot Message Verification
```
Open Serial Monitor: 115200 baud, 8N1
```

**Expected Output:**
```
[Boot] Water Level Monitor v1.0 — Node A (XIAO ESP32-C6)
[Boot] LittleFS mount successful
[Boot] node_id=waterlevel-a  ssid=(not set)  poll=5s
[Boot] Queue: 0 pending entries
[Boot] OK — tasks started
```

**If not appearing:**
- Check USB connection (use CH340 driver if needed)
- Try different USB port
- Verify XIAO ESP32-C6 is detected: `ls /dev/ttyUSB*`

---

## 🌊 PHASE 2: SENSOR VERIFICATION (20 min)

### Step 5: Connect SR04M-2 Sensor
```
With power OFF:
1. Connect M12 4-pin cable to sensor
2. Verify pin alignment:
   - Pin 1: +5V (red wire)
   - Pin 2: GND (black wire)
   - Pin 3: RX from sensor (white wire)
   - Pin 4: TX to sensor (yellow wire)
3. Reconnect power supply
```

### Step 6: Sensor Self-Test
```
Monitor Serial output for self-test messages
```

**Expected Output:**
```
[Sensor] Task starting...
[Sensor] SR04M-2 UART initialized: TX=GPIO21, RX=GPIO20, Baud=9600
[Sensor] Running self-test (3 attempts)...
[Sensor] Self-test PASS (attempt 1): 250.5 cm
```

**If FAIL:**
```
[Sensor] Self-test FAIL (all 3 attempts failed)
```

**Troubleshooting:**
- [ ] Verify M12 wiring (pin 3/4 swapped?)
- [ ] Check mode resistor is soldered (120kΩ on SR04M-2)
- [ ] Verify 9600 baud communication
- [ ] Check ferrite bead FB not open circuit

### Step 7: Measure Known Distance
```
Place sensor at fixed distance above known height
Use tape measure to record exact distance
```

**Procedure:**
1. Position sensor 200mm above a flat surface (book, bench)
2. Monitor Serial output:
   ```
   [Sensor] Raw: [0xFF 0x00 0xC8 0xC7] → 200 mm → 20.0 cm
   [Sensor] Valid reading: 20.0 cm → 50%
   ```
3. Record distance from 5 consecutive readings
4. Verify ±2cm accuracy
   - Expected variance: <1cm (temporal filter stabilizing)
   - Record: __________ cm

5. Repeat at 500mm, 1000mm distances
   - 500mm: __________ cm
   - 1000mm: __________ cm

**If readings are off:**
- Check tape measure accuracy (use ruler as baseline)
- Verify sensor orientation (perpendicular to surface)
- Check for reflective surfaces nearby (can cause echo confusion)

---

## ⚙️ PHASE 3: CONFIGURATION & CALIBRATION (15 min)

### Step 8: WiFi Configuration
```
Connect to WiFi via REST API or BLE
```

**Via REST API (HTTP):**
```
POST http://waterlevel-a.local/api/config
Content-Type: application/json

{
  "wifi_ssid": "YourWiFiSSID",
  "wifi_pass": "YourWiFiPassword"
}
```

**Expected Response:**
```
{"ok":true}
```

**Verify WiFi Connection:**
```
GET http://waterlevel-a.local/api/status
```

**Expected Response:**
```json
{
  "level_pct": 50,
  "distance_cm": 200.0,
  "ts": 3600,
  "sensor_ok": true,
  "wifi_ok": true,
  "rssi": -45,
  "queue_depth": 0,
  "fw": "1.0.0",
  "local_ip": "192.168.1.100"
}
```

### Step 9: Tank Calibration (Two-Point Method)
```
Measure your tank and set calibration values
```

**Procedure:**
1. **Empty Point:** Measure distance from sensor to tank bottom
   - Distance: __________ mm
   - Set via API: `tank_empty_dist_mm` = __________ 

2. **Full Point:** Measure distance from sensor to water surface (when full)
   - Distance: __________ mm
   - Set via API: `tank_full_dist_mm` = __________

**Update Configuration:**
```
POST http://waterlevel-a.local/api/config
{
  "tank_empty_dist_mm": 1000,
  "tank_full_dist_mm": 100
}
```

**Verify Calibration:**
```
GET http://waterlevel-a.local/api/status

Expected: level_pct should change with water level
```

---

## 🔍 PHASE 4: DIAGNOSTICS & MONITORING (15 min)

### Step 10: Diagnostics API
```
Call comprehensive diagnostics endpoint
```

**Request:**
```
GET http://waterlevel-a.local/api/diagnostics
```

**Expected Response:**
```json
{
  "sensor": {
    "reads": 42,
    "frame_errors": 0,
    "timeouts": 0,
    "last_raw_cm": 200.5,
    "last_filtered_cm": 200.3,
    "error_rate_%": 0.0
  },
  "wifi": {
    "connected": true,
    "rssi_dbm": -45,
    "ssid": "YourWiFi"
  },
  "queue": {
    "pending": 0
  },
  "system": {
    "uptime_s": 900,
    "heap_free": 78000,
    "heap_total": 156000,
    "heap_used_%": 50.0,
    "fw_version": "1.0.0"
  },
  "config": {
    "tank_empty_mm": 1000,
    "tank_full_mm": 100,
    "poll_interval_s": 5,
    "testing_mode": false
  }
}
```

**Verify:**
- [ ] Zero frame errors (frame_errors = 0)
- [ ] Zero timeouts (timeouts = 0)
- [ ] Heap usage <70% (heap_used_% < 70)
- [ ] WiFi connected (connected = true)
- [ ] Configuration matches what you set

### Step 11: Memory Leak Check
```
Monitor memory usage over 1 hour
```

**Procedure:**
1. Call `/api/diagnostics` every 10 minutes
2. Record heap_free values:
   - t=0min: __________ bytes
   - t=10min: __________ bytes
   - t=20min: __________ bytes
   - t=30min: __________ bytes
   - t=60min: __________ bytes

3. Verify heap_free is stable (doesn't decrease consistently)
   - Expected: Heap free varies ±5000 bytes
   - Problem: Steady decrease → memory leak

---

## 📡 PHASE 5: OFFLINE-FIRST TESTING (30 min)

### Step 12: WiFi Outage Tolerance
```
Test system behavior without WiFi
```

**Procedure:**
1. Verify WiFi is connected:
   ```
   GET http://waterlevel-a.local/api/status
   → wifi_ok = true
   ```

2. Disconnect WiFi (power off router or disable WiFi on phone hotspot)

3. Monitor Serial output for 10+ minutes:
   ```
   [WiFi] Reconnection attempt #1...
   (measurements continue)
   [Sensor] Valid reading: 200.0 cm → 50%
   [Sensor] Valid reading: 200.1 cm → 50%
   [Sensor] Valid reading: 200.2 cm → 50%
   ...
   ```

4. Verify:
   - [ ] Measurements continue every 5 seconds
   - [ ] No WiFi blocking delay (Serial logs continuous)
   - [ ] Queue filling (queue_depth increasing)

5. Check queue status (offline):
   ```
   Can't access HTTP, but Serial shows:
   [Diagnostics] Reads:120 Errors:0 Timeouts:0 Queue:24 RSSI:0
   ```

6. Re-enable WiFi (power on router)

7. Verify reconnection within 50 seconds:
   ```
   [WiFi] Reconnection attempt #2...
   [WiFi] Reconnection successful!
   ```

8. Verify queue flushes:
   ```
   GET http://waterlevel-a.local/api/status
   → queue_depth should return to 0
   ```

---

## 🔄 PHASE 6: INTEGRATION TEST (20 min)

### Step 13: 24-Hour Stability Test (Optional)
```
Run system for 24 hours and monitor
```

**Procedure:**
1. Leave system powered and connected to WiFi
2. Call `/api/diagnostics` every hour
3. Record heap_free, reads, wifi_rssi
4. Check for:
   - Memory leaks (heap_free stable)
   - Frame errors (errors < 1%)
   - WiFi stability (rssi consistent)

**Expected Results:**
- Heap free: varies ±10000 bytes (normal)
- Frame errors: <10 total
- WiFi RSSI: within ±10 dBm of initial

---

## ✅ COMMISSIONING PASS/FAIL CRITERIA

### PASS Criteria ✅
- [x] LED turns on during boot, then off
- [x] Soft-start inrush < 1.0A
- [x] Sensor self-test passes on first attempt
- [x] Distance readings within ±2cm of tape measure
- [x] WiFi connects successfully
- [x] Calibration stored and retrievable
- [x] Frame error rate < 1%
- [x] Heap usage < 70%
- [x] Measurements continue during WiFi outage
- [x] Queue flushes after reconnection

### FAIL Criteria ❌
- [ ] Power supply voltage <4.5V or >5.5V
- [ ] Soft-start inrush > 1.5A
- [ ] Sensor doesn't respond (self-test fails 3x)
- [ ] Distance off by >5cm
- [ ] WiFi won't connect
- [ ] Frame error rate > 5%
- [ ] Heap usage > 80%
- [ ] Measurements freeze during WiFi outage
- [ ] Queue doesn't flush after reconnection
- [ ] Memory leaks detected

---

## 🚀 NEXT STEPS

### If PASS: Proceed to Field Deployment
- [ ] Install in IP65 enclosure
- [ ] Mount on roof location
- [ ] Configure for specific tank dimensions
- [ ] Set up monitoring (Home Assistant, Grafana, etc.)
- [ ] Proceed to Phase 1D

### If FAIL: Troubleshooting
- Refer to [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Check component orientation and solder joints
- Verify firmware upload successful
- Test with known working calibration values

---

## 📝 COMMISSIONING LOG

```
Date: __________
Technician: __________
Device ID: __________
Serial Number: __________

Boot Test:        [PASS] [FAIL]
Power Test:       [PASS] [FAIL]
Sensor Test:      [PASS] [FAIL]
Calibration:      [PASS] [FAIL]
WiFi Test:        [PASS] [FAIL]
Offline Test:     [PASS] [FAIL]
Diagnostics:      [PASS] [FAIL]

Overall Status:   [PASS] [FAIL]

Notes:
________________________________
________________________________
________________________________

Signature: ________________________
```

---

**Commissioning Guide Complete**  
**Ready for Field Deployment**
