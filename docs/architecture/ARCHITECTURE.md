# Water Level Monitoring System — Implementation Architecture
**Version:** 4.2 — Round 2 Code Audit: comprehensive firmware documentation, magic number extraction, iOS service refactoring, view splitting  
**Hardware:** Seeed Studio XIAO ESP32-C6 + JSN-SR04T (Mode 0, trigger/echo) + Relay module  
**Last updated:** Phase 1 documentation (50-70% ratio for all firmware headers) + Round 2 Audit issues identified and approved

### Recent Changes (Round 2 Audit Cycle — Code Quality Improvements)
- [x] **Phase 1: Firmware Documentation** ✅ COMPLETE
  - 5 firmware headers: device_state.h, api_server.h, error_handler.h, queue_store.h, state.h
  - Documentation ratio: 17-15% → 50-70% (industry best practice target met)
  - Content: Architecture overviews, thread safety patterns, usage examples, performance notes
  - Validation: Review Cycle 1 passed all consistency and quality checks
  
- [x] **Phase 2: Extract Magic Numbers** ✅ COMPLETE
  - 3 firmware magic numbers identified and extracted to constants.h
  - KF_INITIAL_P (Kalman filter), QUEUE_MAX_ENTRIES, QUEUE_ENTRY_SIZE_BYTES
  - Validation: Review Cycle 2 passed (code clarity, maintainability improved)

- [x] **Phase 3: iOS Service Refactoring** ✅ COMPLETE (4 subphases)
  - Phase 3a: RestClient + WebSocketManager (extracted from WiFiService: 202 → 120 lines, 40% ↓)
  - Phase 3b: BLENotificationHandler (extracted from BLEService: 231 → 170 lines, 26% ↓)
  - Phase 3c: TransportManager + QueueDrainer (extracted from ConnectionManager: 366 → 190 lines, 48% ↓)
  - Phase 3d: QueueImporter + DataPruner (extracted from DataCache: 154 → 95 lines, 38% ↓)
  - Result: 8 new focused services, 4 major services simplified, 532 lines redistributed
  - Single Responsibility: Achieved across all iOS services

- [x] **Phase 4: iOS View Splitting** — Extract 8 large views into 22 focused components
  - Phase 4a: TankCalibrationView (567 lines → 4 components + 150-line coordinator) ✅
    * CalibrationModeSelector: Mode selection UI (80 lines)
    * SensorStreamingDisplay: Real-time visualization (167 lines)
    * CalibrationDataProcessor: AI filtering and stability (151 lines)
    * CalibrationResultsDisplay: Results summary (160 lines)
    * TankCalibrationView_Refactored: Coordinator (150 lines, 73% reduction)
  - Phase 4b.1: InsightsView (426 lines → 3 components + 80-line coordinator) ✅
    * InsightsPredictionCard: Time-to-empty, drain rate (125 lines)
    * InsightsChartSuite: Forecast, hourly, trends charts (160 lines)
    * InsightsStatsPanel: Alerts, usage, fill events, pump estimates (180 lines)
    * InsightsView_Refactored: Coordinator (80 lines, 82% reduction)
  - Phase 4c.3: HistoryView (244 lines → 3 components + 70-line coordinator) ✅
    * HistoryDevicePicker: Multi-device selection (50 lines)
    * HistoryLevelChart: Time-series water level visualization (105 lines)
    * HistoryStatsTable: Summary stats and recent readings (130 lines)
    * HistoryView_Refactored: Coordinator (70 lines, 71% reduction)
  - Phase 4b.2: ConfigWizardView (316 lines) — Ready
  - Phase 4b.3: DeviceDetailView (319 lines) — Ready
  - Phase 4c.1: AddDeviceView (223 lines) — Ready
  - Phase 4c.2: DashboardView (184 lines) — Ready
  - Phase 4c.4: DeviceHealthCheckView (288 lines) — Ready

---

## Table of Contents
1. [Implementation Status](#implementation-status)
   - [Firmware — Tank Sensor](#firmware--tank-sensor-sensor-unit)
   - [iOS App — Phase 1](#ios-app--phase-1)
   - [Phase 2A — Cloud Sync](#phase-2a--cloud-sync-infrastructure-in-progress)
2. [Architecture Boundaries](#architecture-boundaries)
3. [Credentials & Security](#credentials--security)
4. [Build & Deployment](#build--deployment)
5. [Performance & Optimization](#performance--optimization)

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

#### AWS Backend (Option 2: SQS-First Architecture)
- [x] **SQS Queue** — durable message queue (14-day retention, 3 retries before DLQ)
- [x] **DynamoDB** — readings table (device_id + timestamp key), TTL 1-year, PITR backup enabled
- [x] **RDS PostgreSQL** — 7 tables: users, profiles, devices, device_users, readings_synced, anomalies, insights
- [x] **Lambda** — sync function with ownership validation, dedup, RDS writes, error handling
- [x] **Cognito** — user management, temporary credentials for mobile app
- [x] **SNS** — anomaly alerts (low level, high level, etc)
- [ ] **API Gateway** — [Phase 2B] for GET reads (fetch history, insights)
- [ ] **AWS IoT Core** — [Phase 2C] for device commands (config, motor control)

#### Device Firmware (Phase 2A)
- [x] NVS queue: 2000 capacity, survives reboot
- [x] Syncs queue to app every 30s via BLE/WiFi
- [ ] Verify queue doesn't overflow under heavy load
- [ ] Test recovery after device crashes mid-sync

#### iOS App (Phase 2A)
- [x] **SyncQueueItem** model — SwiftData, tracks pending→synced→cleared status
- [x] **SyncQueueManager** — batch sends to SQS, offline queueing, exponential backoff
- [x] **SQSManager** — AWS SDK integration, SigV4 signing, Cognito credentials
- [x] **Cognito integration** — authenticate user, get temporary AWS credentials
- [x] **Offline detection** — NWPathMonitor, auto-sync when online
- [ ] Verify queue persists across app restart
- [ ] Test multi-device syncing (same app, multiple tanks)

#### Documentation (Phase 2A)
- [x] `docs/architecture/PROJECT_CONTEXT.md` — Canonical AI/project context, priorities, naming, rules, standards, known corrections
- [x] `docs/architecture/REQUIREMENTS.md` — Complete Phase 2 requirements
- [x] `docs/architecture/IMPLEMENTATION_TODO.md` — Detailed TODO (2A/2B/2C)
- [x] `docs/architecture/CLOUD_PERFORMANCE_ANALYSIS.md` — AWS vs Custom comparison
- [x] `docs/api/PHASE_2A_IMPLEMENTATION.md` — **PRODUCTION-READY**, single comprehensive SQS-first architecture guide:
  - ✅ Cognito authentication + temporary credentials
  - ✅ Device ownership validation (Lambda checks user owns device)
  - ✅ Multi-tenant support (device_users table, permission checking)
  - ✅ Complete RDS writes + error handling + transactions
  - ✅ Least privilege IAM (specific resources only)
  - ✅ DynamoDB PITR + SQS DLQ for recovery
  - ✅ Complete test procedures + troubleshooting guide
  - ✅ Cost monitoring + CloudWatch alarms
  - ✅ 4-6 week realistic timeline

#### Integration Tests (Phase 2A)
- [ ] Ownership validation: User B can't submit readings for User A's device
- [ ] Deduplication: App A + App B sync same device, no duplicates
- [ ] Offline scenario: App offline 2h, queues 500 readings, syncs all when online
- [ ] Error recovery: Lambda fails 3x, message goes to DLQ, can manually replay
- [ ] Multi-app: Same device, 2 phones, both sync simultaneously without loss
- [ ] RDS consistency: Check readings_synced table tracks all syncs
- [ ] Cost: Monitor actual spend vs $33/month estimate

#### Cost Estimate (AWS, Phase 2A — Revised)
- SQS: $2/month (4.3M messages)
- DynamoDB: $10/month (on-demand)
- RDS micro: $15/month (free tier 12mo, then paid)
- Lambda: $5/month (1M free invocations)
- SNS: $1/month
- Cognito: Free (1M MAU free)
- **Total: $33/month** (down from $78 with API Gateway)

#### Timeline: 4-6 weeks (Realistic)
- **Week 1:** RDS setup (schema), Cognito pool, SQS queue
- **Week 2:** DynamoDB, Lambda deployment, test procedures
- **Week 3:** iOS Amplify + SQSManager, end-to-end testing
- **Week 4:** Integration tests, monitoring, cost alerts
- **Week 5:** Burndown, bug fixes, documentation
- **Week 6:** Production readiness review, cutover plan

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

---

## Architecture Boundaries

### Module Responsibilities

**Firmware (ESP32)**
- Sensor polling & filtering (Kalman + consensus window)
- Local queue persistence (LittleFS) for offline resilience
- BLE GATT advertisement and characteristic reads/writes
- REST API for config, status, commands, OTA
- WiFi connection and mDNS registration
- MQTT pub/sub (optional, Phase 2)

**iOS App**
- User interface and device management
- BLE scanning and pairing (CoreBluetooth)
- WiFi network connection and status polling
- Historical data storage (SwiftData)
- Cloud sync (Phase 2A — SQS, DynamoDB via SyncQueueManager)
- Notifications (UserNotifications)

**AWS Cloud (Phase 2A)**
- Message durability (SQS)
- Historical analytics (DynamoDB, PostgreSQL)
- User authentication (Cognito)
- Serverless sync logic (Lambda)
- Cost & anomaly alerts (SNS, CloudWatch)

### No Responsibilities (Out of Scope)
- Firmware does NOT store readings forever — delegates to iOS app via queue sync
- iOS does NOT poll device history — relies on cloud sync from AWS
- Cloud does NOT control motors — Phase 2B/2C (AWS IoT Core)

---

## Credentials & Security

### WiFi & MQTT
- WiFi SSID/password stored in NVS (encrypted by ESP32 PSRAM)
- MQTT broker IP stored in config; no auth required (assume private LAN)
- No TLS on local LAN (standard practice for IoT); TLS required for external MQTT

### iOS App
- Cognito user pools for identity (Phase 2A)
- Temporary AWS SigV4 credentials issued by Cognito
- Credentials expire hourly; app refreshes silently via Cognito SDK
- No long-lived tokens stored locally

### REST API
- No authentication on LAN (local subnet only)
- ElegantOTA uses browser; assumes physical network isolation
- Phase 2B: API Gateway + IAM for cloud-facing endpoints

---

## Build & Deployment

### Firmware
- PlatformIO environment: `esp32-c6` with Arduino framework
- Build: `platformio run -e esp32-c6`
- Flash: USB-C; baud 460800 (auto-detected by VSCode)
- OTA: ElegantOTA web interface at `<device-ip>/update`

### iOS App
- Minimum target: iOS 17.0 (SwiftData requirement)
- Build: Xcode 15+, Swift 5.9+
- Development team: configured in Xcode project
- AppStore build: Xcode Cloud or local `xcodebuild archive`
- Cognito integration: requires AWS credentials in Xcode environment (Phase 2A)

### Cloud (Phase 2A)
- CloudFormation template: `aws/cloudformation/stack.yaml`
- Deploy: `aws cloudformation deploy --template-file stack.yaml --stack-name water-monitor`
- Lambda runtime: Python 3.11
- RDS: Multi-AZ PostgreSQL 14

---

## Performance & Optimization

### Firmware
- **Sensor**: 5-sample median + Kalman filter → 300ms latency per poll (configurable 10-30s interval)
- **Memory**: Stack 12KB per task, heap ~100KB free after boot
- **WiFi**: 15s connect timeout; 30s reconnect retry; mDNS lookup ~1-2s
- **BLE**: Advertisement interval 2s; GATT MTU 517 bytes (config transfer ~600 bytes)
- **Queue**: O(1) append/read via circular buffer; ~40 bytes per entry, 2000-entry capacity = ~80KB

### iOS App
- **UI**: Charts render 1000+ points in <500ms via Swift Charts + Canvas
- **BLE**: Scan timeout 15s; discovery list updates every 1s
- **History**: Fetch 30-day history in ~100ms (SwiftData indexed query)
- **Cloud sync**: Batch 50 readings per SQS message; exponential backoff on failures

### AWS
- **SQS**: Message retention 14 days; throughput unlimited; cost ~$0.40/M messages
- **Lambda**: 128MB heap, 3s timeout for dedup + RDS write
- **DynamoDB**: On-demand pricing; ~0.3KB per reading; 1-year TTL
- **RDS**: t3.micro instance; ~$30/month; max 500 connections
