# Water Level Monitor

A self-contained IoT system that measures water tank level with an ultrasonic sensor and streams it live to an iOS app over BLE and WiFi.

## What it does

- Measures water level continuously using a JSN-SR04T ultrasonic sensor
- Streams live readings via BLE (when nearby) and WebSocket (when on the same WiFi)
- iOS app shows a live gauge, history chart, and push alerts for low/high levels
- Stores readings locally in a queue that flushes when connectivity is restored
- Configures sensor, tank dimensions, and WiFi credentials via BLE — no web portal needed

## Hardware

| Component | Role |
|---|---|
| Seeed XIAO ESP32-C6 | Microcontroller — tank sensor unit |
| JSN-SR04T (Mode 0) | Waterproof ultrasonic distance sensor |
| 1kΩ + 2kΩ resistors | Voltage divider on ECHO line (5V→3.3V) |
| iPhone (iOS 17+) | Monitoring app |

## Repository Layout

```
water-monitor/
├── README.md                   ← you are here
├── CLAUDE.md                   ← project rules for Claude Code
├── firmware/
│   └── tank-sensor/            ← Tank sensor firmware (PlatformIO project)
│       ├── platformio.ini
│       └── src/
│           ├── main.cpp
│           ├── state.h
│           ├── config.{h,cpp}
│           ├── sensor.{h,cpp}
│           ├── ble_server.{h,cpp}
│           ├── api_server.{h,cpp}
│           ├── queue_store.{h,cpp}
│           └── pins.h
├── ios-app/
│   └── mobile/                 ← iOS app (SwiftUI)
│       └── WaterMonitor/
├── android-app/                ← Android app (Phase 2 placeholder)
└── docs/
    ├── architecture/
    │   └── ARCHITECTURE.md     ← full system design reference
    ├── firmware/
    │   └── build-and-flash.md  ← how to build and flash tank sensor
    ├── hardware/
    │   └── wiring-and-bom.md   ← wiring diagram and bill of materials
    ├── ios-app/
    │   └── api-contracts.md    ← iOS app design & BLE API contracts
    └── android-app/
        └── README.md           ← Android app Phase 2 placeholder
```

## Quick Start

### Firmware (Tank Sensor)

1. Install [VS Code](https://code.visualstudio.com/) + [PlatformIO extension](https://platformio.org/install/ide?install=vscode)
2. Open `firmware/tank-sensor/` as a PlatformIO project
3. Connect the XIAO ESP32-C6 via USB-C
4. See [docs/firmware/build-and-flash.md](docs/firmware/build-and-flash.md) for build, flash, and first-boot steps

### iOS App

See [ios-app/mobile/](ios-app/mobile/) for the SwiftUI app. Configuration and usage details in [docs/ios-app/api-contracts.md](docs/ios-app/api-contracts.md).

## Documentation

| Document | Description |
|---|---|
| [Architecture](docs/architecture/ARCHITECTURE.md) | Complete system design — hardware, firmware, BLE/REST APIs, iOS app |
| [Build & Flash](docs/firmware/build-and-flash.md) | PlatformIO build instructions and first-boot configuration |
| [Wiring & BOM](docs/hardware/wiring-and-bom.md) | Hardware wiring diagram and bill of materials |

## Phase Status

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | Tank sensor + iOS app | Firmware complete, iOS app (live gauges, history, alerts, calibration) |
| Phase 2 | Motor controller + automation | Placeholder only, Phase 1 must be tested and stable first |
