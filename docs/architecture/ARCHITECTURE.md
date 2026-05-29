# Water Level Monitoring System — Implementation Architecture
**Version:** 4.0 — Phase 2A cloud sync infrastructure planned; AWS backend + multi-device support  
**Hardware:** Seeed Studio XIAO ESP32-C6 + JSN-SR04T (Mode 0, trigger/echo) + Relay module  
**Last updated:** Phase 2A (Cloud Sync) requirements, implementation guide, and architecture design added

---

## Implementation Status

### Firmware — Tank Sensor (sensor unit)
- [x] `platformio.ini` — pioarduino platform, ESP32-C6, all lib_deps, LittleFS filesystem
- [x] `pins.h` — D1/D2 TRIG/ECHO, LED_BUILTIN, RF-reserved GPIO comments
- [x] `state.h` — `DeviceState` struct + `extern gState/gStateMutex`
- [x] `config.h/.cpp` — NVS-backed `DeviceConfig` via Preferences; `applyPartialJson()` for BLE/REST partial updates
- [x] `sensor.h/.cpp` — `readDistanceCM()` 5-sample avg, `computeLevelPct()`, `resolvePin()`, `handlePinCommand()` with atomic test_pin sensor command (trigger + echo in one, 3 retries)
- [x] `queue_store.h/.cpp` — LittleFS `/q.bin` binary circular buffer, 2000 × 16-byte entries, O(1) pending count
- [x] `ble_server.h/.cpp` — NimBLE GATT server, AA01–AA06, config write + pin command callbacks
- [x] `api_server.h/.cpp` — AsyncWebServer REST :80 + WebSocket :80/live (single server), mDNS, ElegantOTA
- [x] `main.cpp` — FreeRTOS tasks (sensor, comms, ble), WiFi connect/reconnect, MQTT, shared state
- [x] Validated: BLE advertising, WiFi connect, REST API, WebSocket, sensor readings all confirmed working

### iOS App — Phase 1
- [x] `BLEService.swift` — CoreBluetooth, GATT AA01–AA06, CBDelegate on main queue, `onLiveReading` / `onConfigReceived` callbacks
- [x] `WiFiService.swift` — URLSession REST + WebSocket, ping timer, auto-reconnect, queue flush (POST /api/queue/flush)
- [x] `ConnectionManager.swift` — transport priority (WiFi > BLE > offline), `writeConfig`, `sendCommand`, `testDeviceConnection()` for health checks, `connectToDevice()` for manual reconnect, queue drain via REST
- [x] `DataCache.swift` — SwiftData reads/writes, 7-day pruning, duplicate-safe bulk queue import
- [x] `DashboardView.swift` — circular gauge, connection badge, test-mode toggle, stats grid (kept for legacy)
- [x] `HistoryView.swift` — Swift Charts line + area chart, 24h/7d range
- [x] `ConfigWizardView.swift` — 3-step wizard: WiFi credentials → tank dimensions → pin assignment
- [x] `PinConfigView.swift` — pin pickers, test pulse with 5s timeout (firmware retries 3x), save
- [x] `DeviceInfoView.swift` — RSSI, firmware version, queue depth, OTA trigger, reboot
- [x] `ScanView.swift` — BLE scan with `pendingScan` flag for CBCentralManager init timing (kept for legacy)
- [x] `SavedDevice.swift` — SwiftData model for persisted known devices
- [x] `Tank.swift` — SwiftData model for tank topology
- [x] `MotorGroup.swift` — SwiftData model linking tanks to motor controllers
- [x] `ContentView.swift` — 3-state router: `.launching` splash → `.welcome` (no devices) → `.home` (has devices)
- [x] `WelcomeView.swift` — first-launch screen; blue drop icon; "Add Your First Sensor" button
- [x] `MainAppView.swift` — root TabView: Devices / History / Settings; sheet for AddDeviceView
- [x] `DevicesHubView.swift` — "Devices" tab; cards for all saved devices; WiFi+BLE parallel search; 15s timeout
- [x] `DeviceCardView.swift` — mini circular gauge; connection badge (searching/WiFi/BLE/offline); last-seen
- [x] `DeviceDetailView.swift` — full dashboard per device; large gauge; stats grid; test-mode toggle; device info; "Health Check" button
- [x] `DeviceHealthCheckView.swift` — device connectivity troubleshooting; shows BLE/WiFi status, last reading time, "Test Connection" button; called from DeviceDetailView or "Fix Connection" on device card after timeout
- [x] `AddDeviceView.swift` — full-screen sheet; BLE scan phase → ConfigWizard phase → health check phase; persistDevice() with verification
- [x] `AppSettingsView.swift` — "Settings" tab; list saved devices with delete; app version info
- [x] `TankCalibrationView.swift` — tank calibration with real-time sensor streaming + AI filtering (median-based outlier detection, stability scoring); quick mode (asks user for % at EACH point, records distance+percent for both, calculates empty/full via two-point formula); auto mode (24-48h background detection)
- [x] `HistoryView.swift` — device-wise history with 24h/7d range picker, line+area charts with legends, per-device filtering, real-time data updates
- [x] `InsightsView.swift` — AI insights engine: predictions (time to empty, drain rate), 7-day usage forecast, fill events, daily consumption trends, peak usage hours, pump estimates
- [x] `InsightsEngine.swift` — statistical analysis of readings: fill/drain event detection, daily usage calculation, weekly trends, hourly patterns, tank-level predictions via linear regression
- [x] `DataCache.swift` — SwiftData reads/writes, 7-day pruning; excludes `isTest=true` rows from history; fixed nodeID filtering for multi-device support
- [x] `NotificationManager.swift` — UserNotifications framework; local alerts for low/high tank level with 5-minute spam prevention per device
- [ ] Multi-tank dashboard — cards per tank, motor status indicators

### Phase 2A — Cloud Sync Infrastructure (In Progress)

#### AWS Backend
- [ ] **DynamoDB** — readings table (device_id + timestamp key), GSI for date queries, TTL for 1-year retention
- [ ] **RDS PostgreSQL** — users, profiles, devices, sync_queue, anomalies, insights tables
- [ ] **API Gateway** — REST endpoints (POST /api/readings, GET /api/readings, CRUD /profiles, CRUD /devices)
- [ ] **Lambda** — sync function with deduplication, reads from API Gateway, writes to DynamoDB + RDS
- [ ] **AWS IoT Core** — MQTT broker, topics: tank/{device_id}/reading/live, config/request, config/response
- [ ] **S3** — Daily backups of DynamoDB + RDS

#### Device Firmware (Phase 2A)
- [ ] Queue expansion: 2000 → 5000 capacity, metadata tracking per entry
- [ ] ACK protocol: Device waits for app confirmation before clearing synced items
- [ ] Cloud API sync: Batch 100 readings, POST to /api/readings, retry exponential backoff
- [ ] MQTT publishing: Publish live readings to tank/{device_id}/reading/live every 30s
- [ ] Queue persistence: Survives device reboot via NVS checkpoint

#### iOS App (Phase 2A)
- [ ] **SyncQueueItem** model — SwiftData, tracks pending→synced status, attempts, retry timestamps
- [ ] **SyncQueueManager** — actor for thread-safe queue operations, network monitoring, auto-sync on connectivity restore
- [ ] **Offline detection** — NWPathMonitor for WiFi/cellular status, queues readings when offline
- [ ] **Cloud sync flow** — When online: push pending queue to cloud, receive ACK, clear local queue
- [ ] **Multi-app sync** — App A uploads reading → Cloud → App B fetches via GET /api/readings (polling or MQTT subscription)
- [ ] **UI status** — Settings tab shows "Cloud sync: Online / Offline / X pending readings"

#### Documentation (Phase 2A)
- [x] `docs/architecture/REQUIREMENTS.md` — Complete Phase 2 requirements (AI validation, cloud sync, multi-device)
- [x] `docs/architecture/IMPLEMENTATION_TODO.md` — Detailed TODO list (2A/2B/2C phases, effort estimates)
- [x] `docs/architecture/CLOUD_PERFORMANCE_ANALYSIS.md` — Firebase vs AWS vs Custom comparison
- [x] `docs/api/PHASE_2A_AWS_IMPLEMENTATION.md` — Step-by-step AWS setup guide with CLI commands + code

#### Integration Tests (Phase 2A)
- [ ] DynamoDB deduplication: Send same reading twice, verify only one stored
- [ ] Multi-app sync: App A reads, App B retrieves via REST, verify identical data
- [ ] Queue persistence: App offline for 1h, queue 500+ readings, go online, sync completes without loss
- [ ] MQTT subscription: Device publishes, multiple apps subscribe, all receive
- [ ] Retry logic: Simulate cloud downtime, verify exponential backoff, no data loss

#### Cost Estimate (AWS, Phase 2A)
- DynamoDB: $1-5/month (on-demand, reads/writes)
- RDS micro: $10-15/month (free tier or micro instance)
- API Gateway: $3-5/month (1M requests free tier + overage)
- Lambda: $5-10/month (1M free invocations + overage)
- AWS IoT: $5-10/month (message volume)
- **Total: $25-45/month** (significantly cheaper than Firebase at scale)

#### Timeline: 3-4 weeks
- **Week 1:** AWS setup (DynamoDB, RDS, API Gateway, Lambda)
- **Week 2:** Device firmware + MQTT + iOS queue layer
- **Week 3:** Integration testing + bug fixes
- **Week 4:** Production deployment + monitoring

---

### Phase 2 Additions (after Phase 1 stable and Phase 2A deployed)
- [ ] Node B firmware: relay driver, MQTT subscriber, motor automation
- [ ] Tank Sensor: MQTT publish on each reading *(stub present in commsTask)*
- [ ] Motor control UI: on/off, runtime display, auto-mode config
- [ ] Energy & water stats: kWh and litres per pump cycle
- [ ] Android app (same feature set)
- [ ] Optional: Zigbee mode if rooftop WiFi unreliable

---

## App Launch Flow

The app uses a 3-state `AppScreen` enum: `.launching`, `.welcome`, `.home`.

```
App Launch  (.launching — 100ms splash)
    │
    ├─ Any SavedDevice in SwiftData?
    │
    │  NO  →  .welcome  (WelcomeView)
    │          └─ "Add Your First Sensor" → AddDeviceView (sheet)
    │               Scan phase: BLE peripheral list
    │               Config phase: ConfigWizardView
    │               persistDevice() → dismiss → .home
    │
    │  YES  →  .home  (MainAppView → DevicesHubView)
    │           DevicesHubView.onAppear calls startSearch():
    │           ├─ tryWiFi(host:) for each saved device (IP first, then mDNS)
    │           ├─ startBLEScan()
    │           ├─ startBLEAutoConnect() — auto-connects to known BLE peripherals
    │           └─ After 15s timeout: start periodic WiFi retry every 30s for offline devices
    │
    │           Cards show "Searching…" until connected or 15s timeout
    │           After 15s → cards show "Offline" + "Fix Connection" button + last-seen date
    │           User can tap "Fix Connection" → DeviceHealthCheckView for diagnosis
    │           Or: device boots after timeout → periodic retry catches WiFi within 30s
    │
    │           BLE deviceConfig arrives → if known device → upgradeToWiFi()
    │           WiFi connects → cm.isOnline=true, transport=.wifi
```

**Key rule:** WiFi (WebSocket) is always the preferred transport once the device is on the same LAN. BLE is used for initial setup and as a fallback when the device is not reachable over WiFi (e.g., during commissioning, or if the phone is out of WiFi range).

---

## Multi-Tank / Motor-Group Topology

The system supports N sensor nodes and M motor controllers connected in arbitrary groupings. The iOS app stores the logical topology in SwiftData; the hardware nodes don't know about each other.

### Entity Relationships

```
Tank  ────────────────────────────────────────────┐
  │  has one  SensorNode (Tank Sensor)            │
  │  belongs to one or more  MotorGroup           │
  │                                               │
MotorGroup ─────────────────────────────────────  │
  │  contains one or more  Tank            many─to─many
  │  controls one or more  MotorNode (Node B)     │
  │                                               │
MotorNode (Node B)  ───────────────────────────── ┘
  drives one relay
  listens to MQTT topic home/tank/level
```

### Example configurations

| Setup | Tanks | Motors | MotorGroup |
|---|---|---|---|
| Simple rooftop | 1 tank | 1 pump | 1 group: tank A → motor 1 |
| Underground + rooftop | 2 tanks | 1 pump | 1 group: both tanks → motor 1 (fill both sequentially) |
| Two buildings | 2 tanks | 2 pumps | 2 groups, one per building |
| Multi-motor single tank | 1 tank | 2 pumps | 1 group: tank A → motor 1 + motor 2 (parallel) |

### SwiftData Models (Planned)

```swift
@Model class SavedDevice {          // known Tank Sensor or Motor Controller units
    var nodeID: String              // "sensor-a", "motor-b"
    var type: NodeType              // .sensor | .motor
    var lastHost: String?           // last known mDNS hostname or IP
    var displayName: String         // user-assigned label
    var addedAt: Date
    var tankID: UUID?               // which tank this node belongs to
}

@Model class Tank {
    var id: UUID
    var displayName: String         // "Rooftop Tank", "Underground Cistern"
    var sensorNodeID: String?       // NodeID of the Tank Sensor serving this tank
    var tankEmptyCM: Double         // distance from sensor when empty
    var tankFullCM: Double          // distance from sensor when full
    var tankVolumeL: Int
    var alertLowPct: Int
    var alertHighPct: Int
    var readings: [DeviceReading]   // SwiftData relationship
}

@Model class DeviceReading {
    var timestamp: Date             // when reading was taken
    var nodeID: String?             // which device produced this ("sensor-a", nil = legacy)
    var readingType: String?        // "level" | "motor" | nil = legacy
    var levelPct: Int               // 0–100% as computed from distance
    var distanceCM: Double          // raw sensor distance measurement
    var sensorOk: Bool              // false if sensor error (not stored if true)
    var isTest: Bool                // true if device was in testing_mode (excluded from history)
}

@Model class MotorGroup {
    var displayName: String         // "Main Pump", "Building B Pumps"
    var tankIDs: [UUID]             // which tanks this group monitors
    var motorNodeIDs: [String]      // NodeIDs of Node B controllers
    var autoStartPct: Int           // trigger ON below this level
    var autoStopPct: Int            // trigger OFF above this level
    var maxRunMinutes: Int          // safety cut-off
}
```

### Dashboard Layout (multi-tank target)

```
Dashboard
├─ Tank Cards  (LazyVGrid, 1–2 columns)
│   └─ TankCard
│       ├─ Display name + location
│       ├─ Circular level gauge (%)
│       ├─ Distance reading (cm)
│       ├─ Transport badge (WiFi / BLE / Offline)
│       └─ Motor status chips (for each MotorGroup that covers this tank)
│
└─ Motor Groups section
    └─ MotorGroupCard
        ├─ Name + tanks it serves
        ├─ On / Off / Auto toggle
        └─ Runtime this cycle
```

---

## Hardware Confirmed (from pinout images)

### XIAO ESP32-C6 Actual Pin Map

| Arduino Label | GPIO # | Alt Function | Notes |
|---|---|---|---|
| D0 | GPIO0 | A0, LP_GPIO0 | ADC, ULP-capable |
| D1 | GPIO1 | A1, LP_GPIO1 | ADC, ULP-capable — **ECHO connected here** |
| D2 | GPIO2 | A2, LP_GPIO2 | ADC, ULP-capable — **TRIG connected here** |
| D3 | GPIO21 | SDIO_DATA1 | |
| D4 | GPIO22 | SDA, SDIO_DATA2 | I2C SDA |
| D5 | GPIO23 | SCL, SDIO_DATA3 | I2C SCL |
| D6 | GPIO16 | TX | UART0 TX |
| D7 | GPIO17 | RX | UART0 RX |
| D8 | GPIO19 | SCK, SDIO_CLK | SPI SCK |
| D9 | GPIO20 | MISO, SDIO_DATA0 | SPI MISO |
| D10 | GPIO18 | MOSI, SDIO_CMD | SPI MOSI |
| 5V | — | Power | USB 5V pass-through |
| GND | — | Ground | |
| 3V3 | — | Regulated 3.3V out | |
| LED_BUILTIN | GPIO15 | Yellow onboard LED | |
| — | GPIO3 | WIFI_ENABLE (RF switch) | ⛔ DO NOT USE |
| — | GPIO14 | WIFI_ANT_CONFIG | ⛔ DO NOT USE |

---

## Tank Sensor — Current Actual Wiring

### JSN-SR04T → XIAO ESP32-C6 (Mode 0 — HC-SR04 trigger/echo)

| JSN-SR04T Pin | Connected to | Status |
|---|---|---|
| 5V Power | XIAO 5V pin | ✅ Correct |
| GND | XIAO GND | ✅ Correct |
| TRIGGER | XIAO D2 (GPIO2) | ✅ Safe — 3.3V output drives 5V sensor trigger fine |
| ECHO | XIAO D1 (GPIO1) | ⚠️ **Add voltage divider** — sensor powered at 5V, ECHO may output 5V logic |

### ⚠️ ECHO Pin — Voltage Divider Required

```
JSN ECHO ──[1kΩ]──┬── D1 (GPIO1) on XIAO
                  │
                [2kΩ]
                  │
                 GND
```
Divides 5V × (2kΩ / 3kΩ) = 3.33V → safe for ESP32-C6.

---

## Firmware — Tank Sensor

### Development Stack
- **Framework:** Arduino Core 3.x for ESP32 (ESP32-C6, RISC-V single HP-core)
- **Build system:** VS Code + PlatformIO
- **Board package:** pioarduino fork (platform-espressif32 53.03.13)

### platformio.ini
```ini
[env:tank-sensor]
platform     = https://github.com/pioarduino/platform-espressif32/releases/download/53.03.13/platform-espressif32.zip
board        = seeed_xiao_esp32c6
framework    = arduino
monitor_speed  = 115200
upload_speed   = 921600
monitor_filters = esp32_exception_decoder

board_build.filesystem  = littlefs
board_build.partitions  = partitions.csv

lib_deps =
    bblanchon/ArduinoJson@^7.0.0
    knolleary/PubSubClient@^2.8
    h2zero/NimBLE-Arduino@^2.0.0
    ESP32Async/ESPAsyncWebServer@^3.4.0
    ESP32Async/AsyncTCP@^3.4.0
    ayushsharma82/ElegantOTA@^3.1.5

build_flags =
    -DCORE_DEBUG_LEVEL=3
    -DCONFIG_ARDUINO_LOOP_STACK_SIZE=8192
    -DARDUINO_USB_MODE=1
    -DELEGANTOTA_USE_ASYNC_WEBSERVER=1
```

### Custom Partition Table (`partitions.csv`)
```
# Name,   Type, SubType,  Offset,   Size
nvs,      data, nvs,      0x9000,   0x5000
otadata,  data, ota,      0xe000,   0x2000
app0,     app,  ota_0,    0x10000,  0x1C0000   ← 1.75 MB
app1,     app,  ota_1,    0x1D0000, 0x1C0000   ← 1.75 MB
spiffs,   data, spiffs,   0x390000, 0x70000    ← 448 KB LittleFS
```
> Partition named `spiffs` — Arduino LittleFS library searches for that name.

### Source File Structure

```
firmware/tank-sensor/src/
├── main.cpp          FreeRTOS tasks (sensor/comms/ble), WiFi, MQTT, shared state init
├── state.h           DeviceState struct + extern gState/gStateMutex
├── pins.h            GPIO pin definitions (D1 ECHO, D2 TRIG, LED_BUILTIN)
├── config.h/.cpp     NVS config (Preferences-backed), applyPartialJson()
├── sensor.h/.cpp     readDistanceCM(), computeLevelPct(), resolvePin(), handlePinCommand()
├── queue_store.h/.cpp LittleFS /q.bin binary ring buffer (2000 entries)
├── ble_server.h/.cpp NimBLE GATT server (AA01–AA06)
└── api_server.h/.cpp AsyncWebServer REST :80, WebSocket :80/live, mDNS, OTA
```

### FreeRTOS Tasks

| Task | Stack | Priority | Responsibility |
|---|---|---|---|
| `sensorTask` | 4096 | 3 | Sensor read loop, queue write, BLE level notify |
| `commsTask` | 8192 | 2 | WiFi connect/reconnect, REST server loop, WebSocket push, MQTT |
| `bleTask` | 10240 | 1 | NimBLE init, config char refresh |

### Shared State

```cpp
struct DeviceState {
    float    distance_cm;   // latest sensor reading (-1 = error)
    uint8_t  level_pct;     // computed fill percentage
    uint32_t last_read_ts;  // seconds since boot of last reading
    bool     sensor_ok;
    uint16_t queue_depth;   // unsent entries
    int8_t   wifi_rssi;
    bool     wifi_ok;
};
```

### Local Message Queue

- File: `/q.bin` — 2000 × 16 bytes = **32 KB** on LittleFS
- Metadata in NVS namespace `qmeta`; `pendingCount()` is O(1)
- Drained by app via `POST /api/queue/flush` (max 50 per call) + `POST /api/queue/ack`

```cpp
struct __attribute__((packed)) QueueEntry {
    uint32_t seq;
    uint32_t ts;         // seconds since boot
    float    distance_cm;
    uint8_t  level_pct;
    uint8_t  sensor_ok;
    uint8_t  sent;
    uint8_t  _pad;       // 16 bytes total
};
```

---

## BLE GATT Service Definition

**Service UUID:** `0000AA01-0000-1000-8000-00805F9B34FB`

| Char | UUID | Properties | Payload |
|---|---|---|---|
| Level reading | `0xAA01` | Read, Notify | `{"level_pct":42,"distance_cm":87.4,"ts":366}` |
| Device status | `0xAA02` | Read, Notify | `{"wifi_ok":true,"sensor_ok":true,"rssi":-62,"queue_depth":3}` |
| Config read | `0xAA03` | Read | Full NVS config JSON |
| Config write | `0xAA04` | Write | Partial config update |
| Command | `0xAA05` | Write | `{"cmd":"test_pin","peripheral":"sensor"}` (full measurement with 3 retries) or `{"cmd":"reboot"}` |
| Command result | `0xAA06` | Read, Notify | `{"result":"ok","value":87.4,"unit":"cm"}` (on success) or `{"result":"fail","detail":"no_echo_timeout"}` |

**Note:** AA01 and AA02 are merged in the iOS app — AA01 carries level fields, AA02 carries status fields. The app accumulates them into a single `DeviceStatus` rather than replacing it wholesale.

### Full NVS Config Schema (AA03 / AA04 / GET /api/config)
```json
{
  "wifi_ssid":        "MyNetwork",
  "wifi_pass":        "password",
  "tank_empty_cm":    150.0,
  "tank_full_cm":     20.0,
  "tank_volume_l":    1000,
  "alert_low_pct":    15,
  "alert_high_pct":   95,
  "poll_interval_s":  30,
  "pin_trig":         "D2",
  "pin_echo":         "D1",
  "node_id":          "sensor-a",
  "mqtt_broker_ip":   "",
  "firmware_version": "1.0.0"
}
```

---

## REST API (WiFi — same LAN)

**Base URL:** `http://{node_id}.local/`  
**mDNS hostname:** `{node_id}.local` registered after WiFi connects

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/status` | Live state snapshot (8 fields) |
| GET | `/api/config` | Full NVS config JSON |
| POST | `/api/config` | Partial config update |
| WebSocket | `/live` | `ws://{node_id}.local/live` — push on every sensor reading |
| POST | `/api/queue/flush` | Returns up to 50 unsent queue entries |
| POST | `/api/queue/ack` | `{"seq_up_to": N}` — mark entries sent |
| POST | `/api/command` | Same payload as BLE AA05 |
| GET | `/api/ota/check` | `{"current":"1.0.0","node_id":"sensor-a"}` |
| POST | `/api/ota/start` | `{"url":"http://..."}` — background OTA task |
| GET | `/update` | ElegantOTA browser UI |

### WebSocket Push Format
```json
{"level_pct":42,"distance_cm":87.4,"ts":1234567,"sensor_ok":true}
```

---

## Communication Architecture

### Transport Priority (App)

```
WiFi (WebSocket) ──── primary ─── latency ~100ms, full data rate
       │
       │ fallback if WiFi unavailable
       ▼
BLE (AA01/AA02 notify) ── secondary ─── latency ~500ms, limited throughput
       │
       │ fallback if BLE also unavailable
       ▼
Offline (last cached reading + age indicator)
```

**WiFi is always preferred once the device is on the same LAN.** BLE is used for:
- Initial device setup (before WiFi credentials are configured)
- Fallback when out of WiFi range
- Sending config writes and commands during early pairing

### RF Coexistence (ESP32-C6)

The ESP32-C6 shares one 2.4 GHz RF front-end across WiFi and BLE via time-division multiplexing.  
- WiFi + BLE simultaneously ✅ (fully supported, used in Phase 1)
- Zigbee + WiFi simultaneously ✗ (not feasible; Zigbee is an optional Phase 2 alternative)

---

## iOS App Architecture

### Tech Stack
| Layer | Technology |
|---|---|
| Language | Swift 6 (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) |
| UI | SwiftUI (iOS 26) |
| BLE | CoreBluetooth |
| WiFi REST | URLSession async/await |
| WebSocket | URLSessionWebSocketTask |
| Local persistence | SwiftData |
| Charts | Swift Charts |
| Alerts | UserNotifications (planned) |

**Note:** `@Bindable` as a local `body` declaration crashes the Swift 6.2.3 type checker in this project. All mutable bindings use `@State` + `$state.property` directly.

### File Structure (current)

```
ios-app/mobile/WaterMonitor/
├── WaterMonitorApp.swift       App entry; ModelContainer; ConnectionManager environment
├── ContentView.swift           3-state router: .launching / .welcome / .home
│
├── Models/
│   ├── DeviceReading.swift     @Model — persisted historical readings (SwiftData)
│   ├── DeviceConfig.swift      Codable struct — mirrors firmware NVS schema exactly
│   ├── DeviceStatus.swift      Decodable struct — accumulated live state from AA01+AA02
│   ├── SavedDevice.swift       @Model — known paired devices (nodeID, lastHost, type, lastIP)
│   ├── Tank.swift              @Model — tank entity with sensor node ref
│   └── MotorGroup.swift        @Model — links tanks to motor nodes
│
├── Services/
│   ├── BLEService.swift        CoreBluetooth; AA01–AA06; onLiveReading/onConfigReceived callbacks
│   ├── WiFiService.swift       URLSession REST + WebSocket; queue flush loop; ping timer
│   ├── ConnectionManager.swift Transport priority; REST queue drain; saveStatus; originalPollInterval
│   └── DataCache.swift         SwiftData save/query; duplicate-safe bulk import
│
├── ViewModels/
│   ├── DashboardVM.swift       displayStatus (last-valid holding); alert thresholds
│   ├── ConfigVM.swift          Lazy-configured; patch-only writes; pin test
│   └── HistoryVM.swift         SwiftData fetch by date range; avg/min/max
│
└── Views/
    ├── WelcomeView.swift        First-launch screen; "Add Your First Sensor" CTA
    ├── MainAppView.swift        Root TabView: Devices / History / Settings
    ├── DevicesHubView.swift     "Devices" tab; device cards; WiFi+BLE search; 15s timeout
    ├── DeviceCardView.swift     Mini gauge; connection badge (searching/WiFi/BLE/offline)
    ├── DeviceDetailView.swift   Full dashboard; large gauge; stats; test-mode toggle; device info
    ├── AddDeviceView.swift      Sheet: BLE scan phase → ConfigWizard phase; persistDevice()
    ├── AppSettingsView.swift    "Settings" tab; saved device list with delete; app version
    ├── ScanView.swift           BLE scan (legacy; kept for reference)
    ├── DashboardView.swift      Single-device dashboard (legacy; kept for reference)
    ├── HistoryView.swift        Swift Charts line+area; 24h/7d picker
    ├── ConfigWizardView.swift   3-step wizard: WiFi → Tank → Pins; selectedTab binding
    ├── PinConfigView.swift      Pin pickers; test pulse with 10s timeout
    └── DeviceInfoView.swift     RSSI; OTA; queue depth; reboot
```

---

## Node B — Motor Controller (Phase 2)

### Hardware Wiring
| Relay module pin | XIAO pin | Notes |
|---|---|---|
| VCC | 5V | |
| GND | GND | |
| IN (signal) | D2 (GPIO2) | Default, configurable |
| Feedback (optional) | D1 (GPIO1) | Optional sense line |

> Use an opto-isolated relay module (e.g. HW-482). Never connect mains voltage to the ESP32 directly.

### MQTT Message — Node A → Node B
**Topic:** `home/tank/level`
```json
{
  "node": "sensor-a",
  "ts": 1718000000,
  "level_pct": 42,
  "distance_cm": 87.4,
  "sensor_ok": true,
  "queued": false
}
```

### Motor Automation Logic
```
Trigger ON:  currentLevelPct < auto_start_pct  (default 20%)
Trigger OFF: currentLevelPct > auto_stop_pct   (default 90%)
Safety OFF:  motor running > max_run_min        (default 45 min)
Dry-run OFF: sensor offline > dry_run_timeout   (default 10 min)
```

---

## Energy & Water Stats (Phase 2 — computed client-side)

```swift
func calcEnergy(events: [MotorEvent], motorWatts: Double, since: Date) -> (kWh: Double, cost: Double)
func calcWaterUsage(cycles: [PumpCycle], tankLitres: Double, since: Date) -> Double
```

---

## Hardware BOM

### Tank Sensor Unit
| Item | Qty | Note |
|---|---|---|
| Seeed XIAO ESP32-C6 | 1 | |
| JSN-SR04T (Mode 0 default) | 1 | |
| 1kΩ resistor | 1 | ECHO voltage divider |
| 2kΩ resistor | 1 | ECHO voltage divider |
| IP65 ABS enclosure | 1 | Weatherproof for rooftop |
| 5V USB-C power supply | 1 | Weatherproof if outdoor |

### Node B — Motor Controller (Phase 2)
| Item | Qty | Note |
|---|---|---|
| Seeed XIAO ESP32-C6 | 1 | |
| Opto-isolated relay module (5V, 10A) | 1 | HW-482 or equivalent |
| DIN rail enclosure | 1 | Near motor DB panel |
| 5V USB-C power supply | 1 | |
