# Firmware — Build and Flash Guide

Target: **Node A** (`firmware/node_a_sensor/`) on Seeed XIAO ESP32-C6

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| VS Code | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |
| PlatformIO IDE extension | Latest | VS Code Extensions marketplace |
| Python | 3.8+ | Required by PlatformIO |
| USB-C cable | — | Data cable (not charge-only) |

PlatformIO will automatically download the pioarduino platform and all library dependencies on first build.

---

## Build

1. Open VS Code
2. **File → Open Folder** → select `firmware/node_a_sensor/`
3. PlatformIO will detect `platformio.ini` and configure the project
4. Click the **Build** button (✓ in the bottom toolbar) or run:
   ```
   pio run
   ```
5. First build takes 2–5 minutes while the platform and libraries download. Subsequent builds are fast.

Expected output:
```
RAM:   [=====     ]  52.3% (used 34156 bytes from 327680 bytes)
Flash: [========  ]  77.1% (used 1012540 bytes from 1310720 bytes)
```

---

## Flash

1. Connect the XIAO ESP32-C6 via USB-C
2. Hold the **BOOT** button, press and release **RESET**, then release **BOOT** (puts it in download mode)
3. Click **Upload** (→ in the bottom toolbar) or run:
   ```
   pio run --target upload
   ```
4. If the port isn't detected automatically, check PlatformIO's device list:
   ```
   pio device list
   ```
   and set `upload_port = /dev/cu.usbmodem...` in `platformio.ini`

---

## Serial Monitor

```
pio device monitor
```

Or click the plug icon in the PlatformIO toolbar. Baud rate: **115200**.

Expected boot output:
```
[Boot] Water Level Monitor v1.0 — Node A (XIAO ESP32-C6)
[Boot] node_id=sensor-a  ssid=(not set)  poll=10s
[Boot] Queue: 0 pending entries
[Boot] OK — tasks started
[BLE] Advertising as "sensor-a"
```

---

## First-Boot Configuration

On first boot, WiFi credentials are not set. The device runs in **BLE-only mode** until configured via the iOS app (BLE characteristic AA04).

### Setting WiFi via BLE (AA04 write)
Send a partial config JSON to characteristic `0xAA04`:
```json
{"wifi_ssid":"YourNetwork","wifi_pass":"YourPassword"}
```

After writing, the `commsTask` picks up the new credentials on its next WiFi connect attempt (within ~500ms).

### Setting Tank Dimensions
Send to AA04:
```json
{"tank_empty_cm":150.0,"tank_full_cm":20.0,"tank_volume_l":1000}
```

`tank_empty_cm` = sensor distance when tank is empty (sensor to tank floor).  
`tank_full_cm` = sensor distance when tank is full (sensor to water surface at max fill).

---

## OTA Updates

### Browser (ElegantOTA)
1. Connect to the same WiFi network as the device
2. Open `http://waterlevel-a.local/update`
3. Select the compiled `.bin` file from `.pio/build/node_a_sensor/firmware.bin`
4. Click **Update** — device reboots automatically

### From iOS App
The app can trigger OTA via `POST /api/ota/start` with a firmware URL. The device downloads and flashes in the background, blinking `LED_BUILTIN` during the process.

---

## LittleFS Filesystem

The queue storage uses a LittleFS partition. On first boot, `queueStore.begin()` creates `/q.bin` (32 KB pre-allocated). If LittleFS fails to mount, `main.cpp` automatically reformats it.

To upload files to LittleFS manually:
```
pio run --target uploadfs
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Upload fails with "No serial data received" | Not in download mode | Hold BOOT, press RESET, release BOOT |
| `LittleFS mount failed` on every boot | Corrupted filesystem | Will auto-format; if persistent, `pio run --target uploadfs` |
| BLE not advertising | NimBLE init failed | Check serial for `[BLE]` errors; verify stack size ≥ 6144 |
| Sensor always returns -1 | Wiring issue | Check TRIG→D2, ECHO→D1, voltage divider, 5V supply |
| mDNS not resolving | WiFi not connected | Check serial for `[WiFi]` lines; verify SSID/pass via AA04 |
