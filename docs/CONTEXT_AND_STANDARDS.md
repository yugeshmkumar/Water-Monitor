# Water Monitor — Comprehensive Context & Standards Guide

**Version:** 1.0 | **Date:** May 2026  
**Purpose:** Unified reference for all architectural decisions, coding standards, industry best practices, and hard constraints to maintain consistency across all future development and conversations.

---

## Table of Contents

1. [CRITICAL CONSTRAINTS](#critical-constraints)
2. [Project Architecture Overview](#project-architecture-overview)
3. [Firmware Architecture & Standards](#firmware-architecture--standards)
4. [iOS App Architecture & Standards](#ios-app-architecture--standards)
5. [AWS Cloud Architecture & Standards](#aws-cloud-architecture--standards)
6. [Code Quality & Documentation Standards](#code-quality--documentation-standards)
7. [Communication & Connectivity Patterns](#communication--connectivity-patterns)
8. [Testing & Validation Standards](#testing--validation-standards)
9. [Security Standards](#security-standards)
10. [Common Pitfalls & Lessons Learned](#common-pitfalls--lessons-learned)

---

## CRITICAL CONSTRAINTS

### 🔴 PRIORITY: ABSOLUTE (Non-negotiable)

These constraints have been learned through experience and must be followed without exception.

#### Branch Strategy (CRITICAL)

| Branch | Purpose | Stability | Merge Into |
|--------|---------|-----------|-----------|
| `main` | **Original baseline** — NEVER merge audit work here | Immutable | N/A — preserve forever |
| `master` | **Stable, tested release** — current production/near-production | High | Only from verified fixes |
| `fixes` | **Development work** — all new features, audits, refactoring | Active | Into master after review |
| `audit/*` | **Feature branches** — temp branches for specific work | Temporary | Into fixes after review |

**Enforcement Rule:** "DO NOT MERGE TO MAIN BRANCH" — This was violated once, breaking the immutable baseline. Always check branch names before merging.

**Git Author Configuration:**
```bash
git config --local user.name "yugeshmkumar"
git config --local user.email "yugeshmkumar@gmail.com"
```

#### Documentation Placement (STRICT)

**Rule:** Only `README.md` is permitted in project root. ALL other documentation goes in `docs/` subfolders.

| Content Type | Target Subfolder |
|---|---|
| System architecture, design decisions | `docs/architecture/` |
| Firmware build, flash, dev guides | `docs/firmware/` |
| Hardware wiring, BOM, datasheets | `docs/hardware/` |
| iOS app design, API contracts | `docs/ios-app/` |
| Android app | `docs/android-app/` |
| API reference | `docs/api/` |

**Enforcement:** Before creating ANY `.md` file, verify it belongs in root (only README qualifies). If the subfolder doesn't exist, create it first.

#### Architecture Documentation Maintenance (STRICT)

**Rule:** `docs/architecture/ARCHITECTURE.md` must be kept up to date at all times.

**Trigger updates after:**
- Adding/removing/renaming source files
- Changing BLE UUIDs, REST endpoints, config keys
- Changing GPIO pin assignments
- Implementing previously planned checklist items
- Making architectural decisions that differ from original plans

**Timing:** Update ARCHITECTURE.md in the SAME COMMIT as the code change. Do not defer.

#### Shared State Architecture (STRICT)

**Rule:** All inter-task shared state lives in `gState` (defined in `src/state.h`). Do not create additional global state structs.

**Rule:** All NVS config goes through the `Config` class (`src/config.h`). Do not call `Preferences` directly from other modules.

#### Hardware Constraints (STRICT)

**ESP32-C6 RF Lines:**
- **GPIO3** and **GPIO14** are RF switch lines — **NEVER use as I/O**
- Voltage divider required on ECHO pin (1kΩ + 2kΩ) on breadboard/perfboard
- Single HP-core RISC-V (use `xTaskCreate` unpinned)

#### Phase Gating (STRICT)

**Rule:** Phase 1 only: sensor unit + iOS app. Do NOT scaffold Phase 2 (motor controller) until Phase 1 is tested and stable.

**Rationale:** Early phase complexity must be proven and hardened before multi-phase coordination.

---

## Project Architecture Overview

### Current Phase

**Phase 1 (Current):** Sensor Unit + iOS App
- ✅ Firmware scaffold complete (tank-sensor)
- ✅ iOS app core complete (BLEService, WiFiService, Views, Models)
- ✅ Round 2 Code Audit completed (4 phases: firmware docs, magic numbers, iOS service refactoring, view splitting)
- 🔄 Phase 2A (Cloud Sync) in progress

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER FACING (iOS App)                        │
├─────────────────────────────────────────────────────────────────┤
│  ContentView → MainAppView → {Devices, History, Settings}       │
│  Views Layer (After Phase 4: 22 focused components)             │
│  ViewModels: ConfigVM, DashboardVM, HistoryVM                   │
│  Services: BLEService, WiFiService, ConnectionManager           │
│  Models: SavedDevice, Tank, DeviceReading, DeviceConfig, etc.   │
└─────────────────────────────────────────────────────────────────┘
                              ↕ (BLE/WiFi/REST)
┌─────────────────────────────────────────────────────────────────┐
│              EDGE DEVICE (ESP32-C6 Firmware)                     │
├─────────────────────────────────────────────────────────────────┤
│  FreeRTOS Tasks:                                                 │
│  • sensor_task → readDistanceCM() → gState.distance             │
│  • comms_task → WiFi, API server, WebSocket, mDNS               │
│  • ble_task → NimBLE GATT server (AA01-AA06)                    │
│  • watchdog/monitoring                                           │
│  Storage: LittleFS queue (/q.bin), NVS config                   │
│  State: DeviceState (gState), DeviceConfig                      │
└─────────────────────────────────────────────────────────────────┘
                         ↕ (REST/SQS/DynamoDB)
┌─────────────────────────────────────────────────────────────────┐
│                  CLOUD (AWS Phase 2A)                            │
├─────────────────────────────────────────────────────────────────┤
│  SQS: water-monitor-readings (14-day retention, 3 retries)      │
│  DynamoDB: readings (device_id + timestamp), TTL 1 year         │
│  Lambda: sync function with ownership validation                │
│  RDS PostgreSQL: 7-table schema (users, devices, readings)      │
│  Cognito: user auth + temporary credentials                     │
└─────────────────────────────────────────────────────────────────┘
```

### Hardware Stack

| Component | Spec | Status |
|-----------|------|--------|
| Microcontroller | Seeed Studio XIAO ESP32-C6 | ✅ Working |
| Sensor | JSN-SR04T Ultrasonic (Mode 0) | ✅ Calibrated |
| Connectivity | BLE + WiFi + mDNS + Optional MQTT | ✅ Working |
| Flash Storage | LittleFS circular queue (2000 × 16-byte entries) | ✅ Working |
| OTA Updates | ElegantOTA via API server | ✅ Integrated |

---

## Firmware Architecture & Standards

### ✅ Round 2 Audit Results

| Phase | Status | Achievement |
|-------|--------|-------------|
| Phase 1: Documentation | ✅ COMPLETE | 5 headers: 17-15% → 50-70% coverage |
| Phase 2: Magic Numbers | ✅ COMPLETE | `constants.h` created, zero hardcoded values |
| Phase 3: Service Refactoring | ✅ COMPLETE | 8 new iOS services, SRP achieved |
| Phase 4: View Component Extraction | ✅ COMPLETE | 8 large views → 22 focused components |

### Firmware File Structure

```
firmware/tank-sensor/src/
├── main.cpp                 # FreeRTOS task creation, WiFi, MQTT
├── pins.h                   # GPIO mapping, TRIG/ECHO, RF-reserved notes
├── state.h                  # DeviceState struct, gState extern, gStateMutex
├── device_state.h           # 50% documentation ratio (audit Phase 1)
├── config.h/cpp             # NVS-backed Config class, applyPartialJson()
├── sensor.h/cpp             # readDistanceCM(), computeLevelPct(), Kalman filter
├── queue_store.h/cpp        # LittleFS circular buffer, O(1) pending count
├── error_handler.h          # 65% documentation ratio, 8 error codes + recovery
├── ble_server.h/cpp         # NimBLE GATT (AA01-AA06), config+pin callbacks
├── api_server.h/cpp         # AsyncWebServer, REST :80, WebSocket :80/live
├── constants.h              # Extracted magic numbers (audit Phase 2)
├── timers.h                 # FreeRTOS timer utilities
├── tests/                   # Unit tests
└── platformio.ini           # PlatformIO config
```

### Firmware Task Architecture (FreeRTOS)

**Task 1: sensor_task**
- Reads distance from JSN-SR04T every N seconds
- Applies Kalman filter (initial P = 1000.0f constant)
- Updates `gState.distance` under mutex protection
- Computes level percentage via `computeLevelPct()`
- Frequency: configurable (default ~1 Hz in test mode, longer in normal)

**Task 2: comms_task**
- WiFi connection with auto-reconnect logic
- REST API server (port 80) with CORS support
- WebSocket live streaming (port 80/live with 30s keepalive)
- mDNS advertisement (waterlevel-a.local)
- Optional MQTT publish
- Queue flush every 30s if WiFi available

**Task 3: ble_task**
- NimBLE GATT server with AA01-AA06 characteristics
- Characteristic write callbacks for config + pin commands
- Scoped to main queue, no background processing
- Discoverable until WiFi configured (soft gate)

**Task 4: watchdog / monitoring**
- System health monitoring
- Ensures queues don't overflow under load
- Recovery after device crashes mid-sync

**Mutex Protection:**
- All access to `gState` must acquire `gStateMutex`
- Config updates via `Config::set()` (NVS-backed, atomic)
- No nested locks (deadlock prevention)

### Firmware Communication Protocols

#### BLE (Bluetooth Low Energy)

**Service UUID:** `0000AA01-0000-1000-8000-00805F9B34FB`

| Char | UUID | R/W | Purpose |
|------|------|-----|---------|
| AA01 | Status | R | Device state (JSON: distance, level, battery, etc.) |
| AA02 | Config | R/W | Device config (JSON: SSID, password, alert thresholds) |
| AA03 | Queue | R | Pending queue entries (binary) |
| AA04 | Settings | W | WiFi/node ID setup (JSON) |
| AA05 | Commands | W | Ping, test, reboot, OTA trigger |
| AA06 | Notifications | N | Push notifications (real-time alerts) |

**Security:** Standard BLE pairing optional; data not encrypted by default (can add ECDH after Phase 1 is stable).

#### WiFi / REST API

**Base URL:** `http://<IP>` or `http://waterlevel-a.local`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/status` | GET | Device status (distance, level, battery) |
| `/api/config` | GET/PATCH | Read/update configuration |
| `/api/command` | POST | Test pin, reboot, OTA trigger |
| `/api/queue` | GET | Queue depth + preview |
| `/api/queue/flush` | POST | Bulk export + clear queue |
| `/live` | WebSocket | Real-time distance stream (30s keepalive ping) |

**OTA:** ElegantOTA integrated; firmware binaries stored on device or S3.

#### Queue Store (LittleFS)

**File:** `/q.bin` (binary circular buffer)  
**Structure:** 2000 entries × 16 bytes = 32 KB total
- Entry: `[timestamp_u32][distance_f32][level_u8][reserved_7b]`
- Circular: Write pointer wraps at 2000
- O(1) pending count via metadata header
- Survives reboot (persistence)

**Lifecycle:**
1. Sensor readings accumulated locally → queue
2. WiFi available → ACK each flushed entry → clear from queue
3. WiFi down → queue acts as buffer (up to 2000 entries)
4. Overflow → oldest entries overwritten (data loss acceptable for Phase 1)

### Firmware Constants (Phase 2 Extraction)

**File:** `src/constants.h`

```cpp
#define KF_INITIAL_P 1000.0f              // Kalman filter initial covariance
#define QUEUE_MAX_ENTRIES 2000            // Circular buffer capacity
#define QUEUE_ENTRY_SIZE_BYTES 16         // Bytes per entry (ts+dist+level)
#define HTTP_SERVER_PORT 80               // REST + WebSocket port
#define WEBSOCKET_PATH "/live"            // WebSocket endpoint
#define WEBSOCKET_KEEPALIVE_INTERVAL 30   // Seconds between pings
#define TASK_STACK_SIZE 4096              // FreeRTOS stack size for worker tasks
#define BLE_MTU_SIZE 512                  // BLE max transmission unit
#define QUEUE_FLUSH_INTERVAL_S 30         // How often to sync queue to app
```

**Rationale:** No magic numbers in code; all constants centralized for maintainability and config-ability.

### Firmware Documentation Standards

**Target:** 50-70% documentation ratio for all public headers.

**Content** (by phase):
- **Phase 1:** Architecture overviews, thread safety patterns, usage examples, error codes + recovery strategies
- **Phase 2:** Explain WHY constants exist (not just WHAT they are)
- **Phase 3:** Add performance notes and limitations

**Example:**

```cpp
/**
 * queue_store.h — Persistent circular queue for readings
 * 
 * PURPOSE: Buffer sensor readings when WiFi is unavailable.
 * - Survives reboot via LittleFS
 * - O(1) pending count via header metadata
 * - 2000 × 16-byte entries (32 KB) fits in SPIFFS safely
 * 
 * THREAD SAFETY: All public methods acquire gStateMutex internally.
 * Do NOT call from ISR context.
 * 
 * LIMITATIONS: Overflow discards oldest entries (data loss acceptable in Phase 1).
 * Phase 2 should implement aging/prioritization.
 * 
 * USAGE:
 *   QueueStore::instance().append(distance, level);
 *   auto pending = QueueStore::instance().pendingCount();
 *   auto entries = QueueStore::instance().readAll();
 */
```

---

## iOS App Architecture & Standards

### ✅ Round 2 Audit Results

**Phase 3: Service Refactoring**
- 8 new focused services extracted (RestClient, WebSocketManager, BLENotificationHandler, TransportManager, QueueDrainer, QueueImporter, DataPruner)
- 4 major services simplified (WiFiService, BLEService, ConnectionManager, DataCache)
- Single Responsibility Principle achieved
- 532 lines redistributed with 26-48% size reductions

**Phase 4: View Component Extraction**
- 8 large views split into 22 focused components (avg 110 lines each)
- Coordinators reduce complexity by 48-82%
- Extracted views: TankCalibrationView, InsightsView, HistoryView, ConfigWizardView, DeviceDetailView, AddDeviceView, DashboardView, DeviceHealthCheckView

### iOS File Structure

```
ios-app/mobile/WaterMonitor/
├── WaterMonitorApp.swift            # App entry point
├── ContentView.swift                 # Root router: launching → welcome → home
│
├── ViewModels/
│   ├── ConfigVM.swift              # Config form state management
│   ├── DashboardVM.swift           # Dashboard data + actions
│   └── HistoryVM.swift             # History filtering + charting
│
├── Views/
│   ├── MainAppView.swift           # TabView coordinator (Devices/History/Settings)
│   ├── WelcomeView.swift           # First-launch splash
│   ├── AppSettingsView.swift       # Settings tab (device list, version)
│   │
│   ├── DashboardView.swift         # Dashboard (legacy, after Phase 4c.2 refactored)
│   ├── DashboardView_Refactored.swift
│   ├── LevelGaugeDisplay.swift     # Circular gauge with alerts
│   ├── DashboardStatusBar.swift    # Connection badge, test mode
│   │
│   ├── DeviceDetailView.swift      # Device dashboard (legacy, after Phase 4b.3)
│   ├── DeviceDetailView_Refactored.swift
│   ├── DeviceGaugeCard.swift       # Gauge + alert indicators
│   ├── DeviceStatsAndActions.swift # Stats grid, action buttons
│   │
│   ├── AddDeviceView.swift         # Add new device (legacy, after Phase 4c.1)
│   ├── AddDeviceView_Refactored.swift
│   ├── BLEScanPhase.swift          # BLE discovery + filtering
│   │
│   ├── TankCalibrationView.swift   # Tank calibration (legacy)
│   ├── TankCalibrationView_Refactored.swift
│   ├── CalibrationModeSelector.swift      # Mode selection (Quick vs Auto)
│   ├── SensorStreamingDisplay.swift       # Real-time distance + stability
│   ├── CalibrationDataProcessor.swift     # AI filtering, stability scoring
│   ├── CalibrationResultsDisplay.swift    # Results summary
│   │
│   ├── ConfigWizardView.swift      # WiFi + tank config (legacy)
│   ├── ConfigWizardView_Refactored.swift
│   ├── WiFiConfigStep.swift        # WiFi SSID, password, node ID
│   ├── TankConfigStep.swift        # Tank dimensions, alert thresholds
│   │
│   ├── HistoryView.swift           # History (legacy, after Phase 4c.3)
│   ├── HistoryView_Refactored.swift
│   ├── HistoryDevicePicker.swift   # Multi-device selection
│   ├── HistoryLevelChart.swift     # Time-series chart
│   ├── HistoryStatsTable.swift     # Summary stats
│   │
│   ├── InsightsView.swift          # Insights (legacy, after Phase 4b.1)
│   ├── InsightsView_Refactored.swift
│   ├── InsightsPredictionCard.swift     # Time-to-empty, drain rate
│   ├── InsightsChartSuite.swift        # 7-day forecast, hourly, trends
│   ├── InsightsStatsPanel.swift        # Usage, fill events, alerts
│   │
│   ├── DeviceHealthCheckView.swift      # Device health (legacy)
│   ├── DeviceHealthCheckView_Refactored.swift
│   ├── HealthCheckStatus.swift    # BLE/WiFi status display
│   ├── HealthCheckTester.swift    # Test connection + results
│   │
│   ├── PinConfigView.swift         # Manual pin assignment
│   ├── ScanView.swift              # BLE scan (legacy)
│   ├── DeviceCardView.swift        # Mini device card
│   ├── DevicesHubView.swift        # Devices tab
│
├── Models/
│   ├── SavedDevice.swift           # @Model for persisted devices
│   ├── DeviceReading.swift         # @Model for sensor readings (with isTest flag)
│   ├── DeviceStatus.swift          # Transient status snapshot
│   ├── DeviceConfig.swift          # Config form data (Codable)
│   ├── Tank.swift                  # @Model for tank metadata
│   ├── MotorGroup.swift            # @Model for motor associations (Phase 2)
│   ├── QueueEntry.swift            # Transient queue item
│
├── Services/
│   ├── BLEService.swift            # CoreBluetooth GATT client
│   ├── BLENotificationHandler.swift# GATT characteristic decoding
│   │
│   ├── WiFiService.swift           # URLSession REST + WebSocket
│   ├── RestClient.swift            # HTTP operations (GET/PATCH/POST)
│   ├── WebSocketManager.swift      # WebSocket + keepalive (5s auto-reconnect)
│   │
│   ├── ConnectionManager.swift     # Transport prioritization (WiFi > BLE)
│   ├── TransportManager.swift      # Retry throttling + priority logic
│   │
│   ├── DataCache.swift             # SwiftData persistence layer
│   ├── QueueImporter.swift         # Bulk queue import + dedup
│   ├── QueueDrainer.swift          # Queue flush (3-attempt ACK retry)
│   ├── DataPruner.swift            # 30-day retention window cleanup
│   │
│   ├── NotificationManager.swift   # UserNotifications (low/high alert)
│   └── InsightsEngine.swift        # Statistical analysis + predictions
│
└── Tests/
    └── ConnectionManagerTests.swift
```

### iOS MVVM Architecture Pattern

**Model → ViewModel → View (Coordinator)**

```
SwiftData Models (SavedDevice, DeviceReading, Tank)
           ↓ (observed by)
ViewModels (ConfigVM, DashboardVM, HistoryVM)
           ↓ (@Published, @MainActor)
Views (SwiftUI @State/@Binding)
           ↓ (actions trigger)
Services (BLEService, WiFiService, ConnectionManager)
           ↓ (update)
           → back to Models
```

**Guidelines:**
- ❌ Do NOT import SwiftUI in ViewModels — import only Foundation + Combine
- ✅ Use `@MainActor` for ViewModels with async work (prevent threading issues)
- ✅ Views handle navigation; ViewModels expose state only
- ✅ Services are dependency-injected via @Environment or init parameters
- ✅ No view logic in ViewModels; separate into Views or Services as needed

### iOS Service Architecture (After Phase 3 Refactoring)

| Service | Purpose | Lines | Depends On |
|---------|---------|-------|-----------|
| **RestClient** | HTTP GET/PATCH/POST | 160 | URLSession |
| **WebSocketManager** | WebSocket + 30s keepalive ping | 100 | URLSession |
| **BLENotificationHandler** | Decode GATT AA01-AA06 characteristics | 140 | CoreBluetooth |
| **TransportManager** | WiFi > BLE priority, retry throttling | 120 | RestClient, BLEService |
| **QueueDrainer** | 3-attempt ACK retry, timestamp reconstruction | 140 | RestClient |
| **QueueImporter** | Bulk import, deduplication, validation | 120 | DataCache |
| **DataPruner** | 30-day retention window cleanup | 110 | SwiftData |
| **WiFiService** | HTTP + WebSocket orchestration | 120 (↓40%) | RestClient, WebSocketManager |
| **BLEService** | CoreBluetooth orchestration | 170 (↓26%) | BLENotificationHandler |
| **ConnectionManager** | Transport priority, queue/config sync | 190 (↓48%) | TransportManager, QueueDrainer |
| **DataCache** | SwiftData persistence | 95 (↓38%) | QueueImporter, DataPruner |

**Single Responsibility:**
- Each service handles ONE domain
- No circular dependencies
- RestClient ≠ WebSocketManager (no coupling)
- ConnectionManager = orchestrator only (delegates to specific services)

### iOS View Coordinator Pattern (After Phase 4 Refactoring)

**Large View → Multiple Components + Lightweight Coordinator**

Example: **TankCalibrationView (567 lines) → 5 focused files**

```
TankCalibrationView_Refactored (150 lines, Coordinator)
├── CalibrationModeSelector (80 lines)           ← Quick/Auto mode picker
├── SensorStreamingDisplay (167 lines)           ← Real-time distance stream
├── CalibrationDataProcessor (151 lines)         ← Stability scoring, outlier detection
└── CalibrationResultsDisplay (160 lines)        ← Results summary
```

**Coordinator responsibilities:**
- Manage state machine (mode → streaming → results)
- Orchestrate navigation between components
- Keep under 150 lines

**Component responsibilities:**
- Single UI job (display, input, calculation)
- @Binding to coordinator state
- Reusable across different contexts

### iOS Data Models (SwiftData)

```swift
@Model final class SavedDevice {
    @Attribute(.unique) var macAddress: String
    var name: String
    var nodeID: String
    var tanks: [Tank]
    var lastSeenAt: Date?
    var rssi: Int?
    var firmwareVersion: String?
}

@Model final class DeviceReading {
    @Attribute(.unique) var id: String  // nodeID + timestamp
    var nodeID: String
    var timestamp: Date
    var distanceCM: Double
    var levelPct: Int
    var temperature: Double?
    var isTest: Bool = false            // Marks calibration/test data
}

@Model final class Tank {
    var name: String
    var volume_litres: Double
    var empty_cm: Double
    var full_cm: Double
    var alert_low_pct: Int
    var alert_high_pct: Int
}
```

**Persistence:** SwiftData + ModelContainer (local storage only; Phase 2 syncs to cloud).

### iOS Connectivity Strategy

**Transport Priority:**
```
1. WiFi (REST + WebSocket)  ← Fast, reliable, sync queue
2. BLE                      ← Fallback, config-only
3. Offline                  ← Queue + retry on reconnect
```

**WiFi → BLE Fallback:**
- If REST fails 3 times → switch to BLE
- BLE can only read config + send test commands (no queue flush)
- When WiFi reconnects → sync full queue via REST

**BLE → WiFi Parallel Search:**
- During device add: search both simultaneously (15s timeout)
- Prioritize WiFi if both found
- Use parallel DispatchGroup.notify()

### iOS Calibration Implementation (Two-Point)

**User asks for % at BOTH points** (not just at empty/full)

```swift
// User flow:
1. Place sensor at point 1 (e.g., 25% full)
2. Adjust percentage slider → 25
3. Stability indicator shows green → Click "Record Point 1"
4. Place sensor at point 2 (e.g., 75% full)
5. Adjust percentage slider → 75
6. Stability indicator shows green → Click "Record Point 2"
7. Click "Calculate & Save"

// Formula solved by app:
range = 100.0 * (dist1 - dist2) / (pct1 - pct2)
full_cm = dist1 - (pct1 / 100.0) * range
empty_cm = full_cm + range
```

**Test Data Filtering:**
- DeviceReading has `isTest: Bool` flag
- DataCache marks readings as test when `device.testingMode == true`
- DataCache.readings() filters out test data by default
- InsightsEngine also filters test data

---

## AWS Cloud Architecture & Standards

### Phase 2A Status

**PRODUCTION-READY design** (pending implementation):
- ✅ Cognito authentication + temporary credentials
- ✅ Device ownership validation (Lambda checks user owns device)
- ✅ Multi-tenant support (device_users table, permission checking)
- ✅ DynamoDB PITR + SQS DLQ for recovery
- ✅ Least privilege IAM (specific resources only)

### AWS Service Architecture

```
iOS App
   ↓
SQS Queue (water-monitor-readings)
   ├─ 14-day retention
   ├─ 3 retries before DLQ
   └─ Dead Letter Queue for debugging
   ↓
Lambda (SyncReadings)
   ├─ Check ownership (device_users table)
   ├─ Dedup readings (device_id + timestamp)
   ├─ Write to RDS
   └─ On error → DLQ
   ↓
DynamoDB (readings)
   ├─ TTL: 1 year
   ├─ PITR enabled
   └─ Fast access for latest readings
   ↓
RDS PostgreSQL (readings_synced)
   ├─ 7-table schema
   ├─ users, profiles, devices, device_users
   ├─ readings_synced, anomalies, insights
   └─ Relational queries (analytics)
```

### AWS Cellular Architecture Pattern

**Principle:** Isolate failure domains; avoid shared resources

| Resource | Pattern | Anti-pattern |
|----------|---------|--------------|
| DynamoDB table | One per service/device type | Global mapping table queried on every request |
| RDS instance | Separate DB per tenant (Phase 2) | Central DB bottleneck |
| SQS queue | Per device type / per region | Single global queue |
| Lambda | Stateless; no long-lived connections | Caching Lambda instance memory |

**In-Memory Caching:**
- Lambda may cache device_id → user_id mapping in execution context (but watch for stale data)
- Don't assume cache persists across invocations (Lambda reuses containers but can spawn new)

### AWS Data Schema (RDS PostgreSQL)

```sql
-- Users & Auth
CREATE TABLE users (
  user_id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  cognito_sub VARCHAR(255) UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE profiles (
  profile_id UUID PRIMARY KEY,
  user_id UUID REFERENCES users,
  display_name VARCHAR(255),
  timezone VARCHAR(50)
);

-- Devices
CREATE TABLE devices (
  device_id UUID PRIMARY KEY,
  node_id VARCHAR(50) UNIQUE,
  firmware_version VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE device_users (
  device_user_id UUID PRIMARY KEY,
  device_id UUID REFERENCES devices,
  user_id UUID REFERENCES users,
  permission ENUM('owner', 'read', 'configure'),
  UNIQUE(device_id, user_id)
);

-- Readings
CREATE TABLE readings_synced (
  reading_id UUID PRIMARY KEY,
  device_id UUID REFERENCES devices,
  timestamp TIMESTAMP,
  distance_cm DOUBLE PRECISION,
  level_pct INT,
  temperature_c DOUBLE PRECISION,
  synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX(device_id, timestamp)
);

-- Analytics
CREATE TABLE anomalies (
  anomaly_id UUID PRIMARY KEY,
  device_id UUID REFERENCES devices,
  reading_id UUID REFERENCES readings_synced,
  type ENUM('spike', 'drop', 'stuck', 'sensor_error'),
  severity ENUM('low', 'medium', 'high'),
  detected_at TIMESTAMP
);

CREATE TABLE insights (
  insight_id UUID PRIMARY KEY,
  device_id UUID REFERENCES devices,
  metric VARCHAR(50),  -- 'drain_rate', 'fill_frequency', etc.
  value DOUBLE PRECISION,
  period ENUM('daily', 'weekly', 'monthly'),
  computed_at TIMESTAMP
);
```

### AWS Security Practices

**IAM Least Privilege:**
- Lambda execution role: only SQS read, DynamoDB write, RDS insert, CloudWatch logs
- API Gateway: restricted to authenticated users (Cognito)
- S3 (for OTA): pre-signed URLs only, 15-minute expiry

**Data Encryption:**
- In transit: TLS 1.3 everywhere (Lambda → RDS, API → Lambda, App → API)
- At rest: AWS KMS for RDS, DynamoDB, S3
- Secrets Manager for API keys, DB passwords (rotated every 30 days)

**Monitoring & Recovery:**
- CloudWatch alarms: SQS queue depth, Lambda errors, RDS CPU/storage
- DynamoDB PITR: 35-day point-in-time recovery
- SQS DLQ: manual inspection of failed messages

---

## Code Quality & Documentation Standards

### Documentation Ratios (Industry Best Practice: 40-50%)

**Target for Water Monitor:** 50-70% for public APIs

| File Type | Coverage | Status |
|-----------|----------|--------|
| Firmware headers (public APIs) | 50-70% | ✅ Phase 1 complete |
| iOS services | 40-50% | 🔄 Phase 3 in progress |
| iOS views | 20-30% | 🔄 Phase 4 in progress |

**What counts as documentation:**
- Architecture overviews (explain WHY, not what)
- Thread safety guarantees
- Performance notes and limitations
- Error codes and recovery strategies
- Usage examples
- Dependency graph (what calls what)

**What doesn't count:**
- Variable declarations (good names suffice)
- Obvious implementations (`if (x > 0) { x = 0; }` needs no comment)
- Parameter names (use clear naming)

### Code Documentation Examples

**Firmware Header (Good):**
```cpp
/**
 * queue_store.h — Persistent circular queue for buffering sensor readings
 *
 * ARCHITECTURE:
 * - LittleFS binary circular buffer at /q.bin
 * - 2000 × 16-byte entries (timestamp, distance, level, reserved)
 * - O(1) append/peek via write pointer; O(1) pending count via metadata
 * - Survives reboot; replays on app reconnect
 *
 * THREAD SAFETY:
 * - All public methods acquire gStateMutex internally
 * - Safe to call from FreeRTOS tasks
 * - NOT safe from ISR context
 *
 * LIMITATIONS & FUTURE:
 * - Overflow discards oldest entries (data loss acceptable in Phase 1)
 * - Phase 2 should implement aging/prioritization
 * - LittleFS has ~500K lifecycle; monitor wear after 1 year
 *
 * USAGE:
 *   QueueStore::instance().append(distance_cm, level_pct);
 *   auto count = QueueStore::instance().pendingCount();
 *   auto all_entries = QueueStore::instance().readAll();
 */
```

**iOS Service (Good):**
```swift
/**
 * RestClient — HTTP operations (GET, PATCH, POST) with error handling
 *
 * Responsibilities:
 * - Construct requests with proper headers + authentication
 * - Execute synchronously or async (@MainActor for UI safety)
 * - Decode JSON responses into Swift Decodable types
 * - Retry failed requests with exponential backoff
 *
 * Thread Safety:
 * - All methods are @MainActor; safe to call from SwiftUI views
 * - URLSession handles threading internally
 *
 * Dependencies:
 * - URLSession (standard library)
 * - No Firebase, no third-party HTTP libraries
 *
 * Usage:
 *   let client = RestClient(baseURL: "http://waterlevel-a.local")
 *   let status = try await client.fetchStatus()
 *   try await client.patchConfig(["alert_low_pct": 10])
 */
```

### Code Quality Metrics (Enforced)

| Metric | Target | Tool | Status |
|--------|--------|------|--------|
| Cyclomatic Complexity | ≤ 10 per function | SwiftLint | ✅ Enforced |
| Lines per Function | ≤ 50 (firmware) ≤ 30 (iOS views) | Code review | ✅ Phase 4 achieved |
| Method/Function Count | ≤ 20 per class | Code review | ✅ After refactoring |
| Test Coverage | ≥ 60% for critical paths | XCTest + SonarQube | 🔄 Phase 3+ |
| Documentation Ratio | 50-70% headers, 40-50% services | Manual review | ✅ Phase 1 complete |

### Code Refactoring Standards (SOLID Principles)

**S — Single Responsibility Principle:**
- Each class/struct does ONE thing
- RestClient = HTTP only (no WebSocket, no caching)
- WebSocketManager = WebSocket only (no HTTP)
- ConnectionManager = orchestrator (delegates to RestClient + WebSocketManager)
- ✅ Achieved in Phase 3 iOS refactoring

**O — Open/Closed Principle:**
- Classes open for extension, closed for modification
- Use protocols + dependency injection
- Example: `protocol Transport` with WiFi + BLE implementations

**L — Liskov Substitution Principle:**
- Subclasses are substitutable for their base class
- If class A uses Transport, both WiFiTransport and BLETransport must work identically

**I — Interface Segregation Principle:**
- Clients shouldn't depend on interfaces they don't use
- Don't force BLEService to implement REST methods
- Keep protocols lean (3-5 methods max)

**D — Dependency Inversion Principle:**
- Depend on abstractions, not concretions
- ConnectionManager depends on `Transport` protocol, not `RestClient` directly
- Enables easy testing via mock implementations

### Testing Standards

**Unit Tests:**
- Test one thing per test method
- Use descriptive names: `testFetchStatusWithValidResponse()` not `test1()`
- Mock all external dependencies (BLE, WiFi, database)
- Assertion: one main assertion per test (helper assertions for setup OK)

**Integration Tests:**
- Real hardware (BLE device, local WiFi)
- Test data flows end-to-end
- Run weekly (not in CI; manual schedule)

**UI Tests:**
- Snapshot tests for critical flows (dashboard, device add, calibration)
- XCTest UI automation for tap sequences
- Run nightly against simulator

---

## Communication & Connectivity Patterns

### BLE Communication (Phase 1)

**When to use BLE:**
- Initial device discovery and pairing
- WiFi credentials not yet configured
- Device is out of WiFi range
- Emergency access (low battery, offline)

**When NOT to use BLE:**
- Regular polling (too slow: 100 ms per characteristic read)
- Bulk queue flush (WiFi is 100× faster)
- Firmware updates (OTA via REST/WebSocket)

**BLE Performance Notes:**
- Max read speed: ~100 ms per characteristic (AA01-AA06)
- Typical round-trip: request + response = 200 ms
- Scanning: ~10 seconds for fresh device discovery
- Connection: ~2 seconds after scan discovery

### WiFi / REST Communication (Primary in Phase 1)

**When to use REST:**
- Regular status polling (every 30-60 seconds)
- Queue synchronization (every 30-60 seconds)
- Configuration updates
- OTA firmware updates

**REST Polling Loop:**
```
1. User opens app
2. App connects to device WiFi (SSID configured via BLE)
3. REST GET /api/status every 30s
4. If queue has entries: POST /api/queue/flush
5. Display live gauge + chart + insights
```

**Performance:**
- Typical round-trip: 500 ms (WiFi latency + device processing)
- Battery impact: ~5-10% per hour (depends on polling frequency)
- Network impact: ~1-2 KB per poll + 2-4 KB per queue flush

### WebSocket Live Streaming (Phase 1)

**When to use WebSocket:**
- Real-time sensor streaming (for calibration)
- Live gauge updates during viewing
- Keepalive health check

**WebSocket Keepalive:**
- Server sends ping every 30 seconds
- App responds with pong (automatic in URLSession)
- If no pong for 90 seconds: auto-reconnect with 5-second backoff

**Performance:**
- Streaming: ~1-2 KB per 100 ms (distance sample)
- Latency: <50 ms round-trip (over WiFi)
- Battery: similar to REST polling

### Transport Prioritization (ConnectionManager)

**Decision Tree:**

```
┌─ Is WiFi available & configured? ─┐
│                                     YES ─→ Use REST + WebSocket (Priority 1)
│                                     │
└─ Is BLE available?                  │
   │                                   NO ─→ Fall through
   ├ YES ─→ Use BLE (Priority 2)
   │        (config read/write only)
   │
   └─ NO (Offline) ─→ Queue + Retry (Priority 3)
                      - Store changes locally
                      - Retry on reconnect
                      - Exponential backoff: 5s → 10s → 30s → 1m
```

**Retry Logic:**
- REST: 3 retries with exponential backoff (1s, 2s, 4s)
- BLE: 2 retries (BLE slower to recover)
- Queue: unlimited (survives app restart)

---

## Testing & Validation Standards

### Firmware Testing

**Unit Tests (src/tests/):**
- Kalman filter correctness (sample inputs + expected smoothed outputs)
- Queue store circular buffer (append, read, wrap-around)
- Config parsing (valid JSON, partial updates, defaults)
- Error handling (sensor timeout, WiFi disconnect, queue overflow)

**Integration Tests (manual):**
- BLE: scan → connect → read AA01 (status) → write AA04 (WiFi)
- WiFi: connect → GET /api/status → verify response
- Queue: append 100 entries → disconnect WiFi → reconnect → flush → verify all received
- OTA: trigger firmware update → verify device reboots with new version

**Hardware Tests (manual):**
- Sensor: place at known distances, verify distance reading ±2 cm
- Calibration: two-point (0%, 100%) → verify empty_cm and full_cm
- Queue wear: write 1000 entries per day for 1 year → monitor flash health

### iOS Testing

**Unit Tests:**
- ConnectionManager: WiFi available → use REST, WiFi down → use BLE
- DataCache: import 100 readings → verify dedup by timestamp
- InsightsEngine: 7 days of readings → verify drain rate calculation
- Calibration: two-point formula with sample data

**UI Tests (Snapshot + Interaction):**
- DashboardView: render with 75% level → verify gauge position + color
- ConfigWizardView: tap "Next" → verify WiFi step → tank step → confirm
- HistoryView: select 7-day range → verify chart loads + filters test data
- AddDeviceView: BLE scan → select device → WiFi config → health check

**Integration Tests (Simulator + Real Device):**
- Full flow: add device → configure → view dashboard → stream calibration → insights
- Offline: disable WiFi → verify BLE fallback → re-enable WiFi → sync queue
- Multi-device: add 3 devices → verify each device's readings separate

### Code Review Standards (Phase Round 2+)

**Mandatory checks:**
- ✅ All public functions have documentation (50-70% ratio)
- ✅ No magic numbers (use constants.h or named constants)
- ✅ Single responsibility per class/service
- ✅ Thread safety (mutex, @MainActor, queues)
- ✅ Error handling (try/catch, error callbacks)
- ✅ No console.log / print (use structured logging)
- ✅ Tests written (unit tests for all public APIs)
- ✅ ARCHITECTURE.md updated

**Review Process:**
1. Author: push to `audit/*` or `fix/*` branch
2. Reviewer: check list above + manual code quality
3. Approval: /ultrareview if >500 lines or >3 files changed
4. Merge: to `fixes` after review (never direct to `master` or `main`)

---

## Security Standards

### BLE Security (Phase 1 + Beyond)

**Current (Phase 1):** No encryption; discovery via advertising

**Why:** Phase 1 is homelab/hobby grade. Encryption adds complexity.

**Future (Phase 2):** LE Secure Connections (ECDH)
- Pairing method: Numeric Comparison (MITM-resistant)
- Encryption: AES-CCM after bonding
- Privacy: MAC randomization (resolvable private addresses)

**Never implement:**
- "Just Works" pairing (no MITM protection)
- Out-of-band authentication without user verification

### REST API Security (Phase 1 + Beyond)

**Current (Phase 1):** HTTP (local network only; mDNS)

**Future (Phase 2):** HTTPS + API Key
- TLS 1.3 required
- API key in Authorization header (rotated monthly)
- Device ownership validation on backend

**Never implement:**
- HTTP on public internet without HTTPS
- Credentials in URLs or body
- API keys in client-side code (retrieve from backend)

### iOS App Security

**Credentials Storage:**
- WiFi password: stored in Keychain (encrypted)
- API tokens: stored in Keychain (not UserDefaults)
- Device UUIDs: stored in SwiftData (acceptable; non-sensitive)

**Never implement:**
- Passwords in UserDefaults
- Credentials in code
- Hardcoded API keys

### AWS Security (Phase 2A+)

**Cognito:**
- Multi-factor authentication (TOTP or SMS)
- Passwordless sign-in (passkeys) recommended
- User sign-out on suspicious activity

**Lambda:**
- Input validation (reject oversized payloads)
- SQL injection prevention (use parameterized queries)
- Rate limiting (DynamoDB throttle + Lambda reserved concurrency)

**API Gateway:**
- WAF rules (AWS Managed Rules)
- API key enforcement
- CORS: allow only trusted origins

---

## Common Pitfalls & Lessons Learned

### 🔴 Pitfall 1: Branch Strategy Violation (CRITICAL LESSON)

**What happened:** User asked to "merge all to fixes branch" after code review. I mistakenly merged to `main` instead, violating the immutable baseline.

**Why it was wrong:**
- `main` is supposed to be the original stable version forever
- Audit work contaminated the baseline
- Had to manually restore `main` and create `fixes` from the correct state

**How to avoid:**
- Always check branch names before git merge
- Confirm with user: "I'll merge to `fixes` branch, not `main`"
- Use branch protection rules in GitHub (require PR review, no force-push)

**Status:** ✅ Fixed — restored correct branch structure; all audit work now in `fixes`

---

### 🔴 Pitfall 2: Git Authentication vs. Git Config (CRITICAL LESSON)

**What happened:** User changed git config to `yugeshmkumar`, but push still used `Yo-FirsThing` credentials. Thought git config controlled authentication.

**Why it was wrong:**
- `git config user.name/user.email` only affects commit author metadata
- Authentication is controlled separately by SSH keys or stored Git credentials
- Changing git config ≠ changing who can push

**How to avoid:**
- Understand the distinction: authorship vs. authentication
- For HTTPS: update credentials in system credential manager or git config credential.helper
- For SSH: ensure correct SSH key is loaded (ssh-add ~/.ssh/id_rsa_username)

**Resolution:** Switched to HTTPS with correct credentials; all commits now have correct author.

**Status:** ✅ Fixed — authentication working, all branches pushed with correct author

---

### 🟡 Pitfall 3: Mixed State Updates During WiFi Transitions

**Potential issue:** If WiFi disconnects mid-queue-flush, state inconsistency could occur (queue partial-synced, some entries ACK'd, some not).

**Prevention:**
- Queue flush is idempotent: ACK only entries that successfully wrote
- Replay unACK'd entries on next sync
- Test: disable WiFi during flush, verify queue replays correctly

**Status:** ⚠️ Not yet tested — add to integration test suite

---

### 🟡 Pitfall 4: BLE Service UUID Collisions

**Potential issue:** If another device on network uses same UUID `0000AA01-0000-1000-8000-00805F9B34FB`, scanning will discover both.

**Prevention:**
- Firmware hardcodes UUID in advertising (secure by default)
- App filters for both UUID + device name (waterlevel-a, waterlevel-b, etc.)
- Device name persisted in SavedDevice model

**Status:** ⚠️ Mitigation in place — verify with multi-device testing

---

### 🟡 Pitfall 5: Kalman Filter Tuning

**Potential issue:** Default `KF_INITIAL_P = 1000.0f` may be too aggressive or too conservative for different sensor/tank combinations.

**Prevention:**
- Log Kalman filter state (P, gain) for debugging
- User-configurable Q/R parameters (future) via BLE AA02
- Document how to tune for specific hardware

**Status:** ⚠️ Needs user feedback from pilot devices — collect data, tune constants.h

---

### 🟡 Pitfall 6: Concurrent WiFi/BLE Operations

**Potential issue:** Some ESP32 chips cannot run BLE + WiFi simultaneously without packet loss or deadlock.

**Prevention:**
- XIAO ESP32-C6 supports concurrent BLE + WiFi (spec verified)
- Monitor BLE RSSI during WiFi transfers (signal degradation = hardware limit)
- Firmware disables BLE scanning when WiFi in use (priority)

**Status:** ✅ Verified — no issues in Round 1 testing

---

### 🟡 Pitfall 7: LittleFS Wear Leveling

**Potential issue:** Writing queue.bin every second for 1 year could exceed flash lifecycle (typ. 1M write cycles).

**Prevention:**
- Current: 1 write per ~3 sensor readings (1 KB per write, 32 KB queue)
- LittleFS wear leveling: automatic
- Monitoring: add flash health check (bootloader can detect worn blocks)
- Future: switch to NAND cache pattern or external flash

**Status:** 🟡 Monitor; no action until 6+ months of data

---

### 🟡 Pitfall 8: Race Conditions in Multi-Task State Updates

**Potential issue:** Two FreeRTOS tasks updating `gState` without proper mutex lock could corrupt data.

**Prevention:**
- All gState access must acquire gStateMutex (compile-time check is hard; code review)
- Use `ScopedLock` pattern or RAII wrapper
- Static analysis: grep for direct `gState.` assignments outside mutex block

**Status:** ✅ Verified in Phase 1 — all state access properly locked

---

### 🟡 Pitfall 9: UITest Fragility (iOS)

**Potential issue:** XCTest UI tests fail due to timing (button not yet available, animation in progress, etc.).

**Prevention:**
- Use `waitForExistence` with reasonable timeout (5s max)
- Add identifier to UI elements for robust targeting
- Avoid position-based taps (use accessibilityIdentifier)
- Run on consistent device (simulator or specific physical device)

**Status:** 🔄 Phase 4 UI tests in progress — apply these patterns

---

### 🟡 Pitfall 10: Data Loss on Queue Overflow

**Current behavior:** Oldest entries overwritten when queue full (2000 entries).

**Is this acceptable?**
- Phase 1: **YES** — homelab grade; data loss acceptable
- Phase 2: **NO** — cloud sync should prevent overflow
- Phase 3+: Implement tiered storage (local queue → cloud → archive)

**Prevention (Phase 2):**
- Sync queue every 30s (not just on demand)
- Cloud ACK immediately (no local re-queue needed)
- Implement queue watermark alarm (alert at 80%, stop accepting at 100%)

**Status:** 🔄 Phase 2A will address this

---

## Appendix: Key File Locations

### Firmware

```
firmware/tank-sensor/
├── src/main.cpp                 # Task creation, WiFi, MQTT
├── src/constants.h              # Extracted magic numbers
├── src/pins.h                   # GPIO mapping
├── src/state.h                  # DeviceState struct + gState
├── src/config.h/cpp             # NVS configuration layer
├── src/sensor.h/cpp             # Ultrasonic + Kalman filter
├── src/queue_store.h/cpp        # LittleFS circular buffer
├── src/ble_server.h/cpp         # NimBLE GATT
├── src/api_server.h/cpp         # AsyncWebServer + WebSocket
├── src/device_state.h           # Device state definitions
├── src/error_handler.h          # Error codes + recovery
├── platformio.ini               # Build configuration
└── tests/                       # Unit tests

docs/architecture/ARCHITECTURE.md        # MUST KEEP UPDATED
docs/firmware/                          # Build guides, flashing instructions
docs/hardware/                          # Wiring diagrams, BOM, datasheets
```

### iOS App

```
ios-app/mobile/WaterMonitor/
├── WaterMonitorApp.swift                # Entry point
├── ContentView.swift                    # Root router
├── Models/                              # SwiftData models
├── ViewModels/                          # ConfigVM, DashboardVM, HistoryVM
├── Views/                               # UI components (after Phase 4: 22 focused views)
├── Services/                            # BLE, WiFi, Connection, Data, Insights
└── Tests/ConnectionManagerTests.swift

docs/ios-app/                           # API contracts, design patterns
docs/api/                               # REST API reference
```

### AWS

```
docs/api/PHASE_2A_AWS_IMPLEMENTATION_REVISED.md  # Production-ready design
docs/architecture/REQUIREMENTS.md                # Phase 2 requirements
docs/architecture/IMPLEMENTATION_TODO.md         # Detailed TODO (2A/2B/2C)
docs/architecture/CLOUD_PERFORMANCE_ANALYSIS.md  # AWS vs Custom comparison
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | May 2026 | Claude Code | Initial comprehensive context document based on Round 2 Code Audit |

---

## How to Use This Document

1. **Before starting any feature/fix:** Read the relevant section (Firmware, iOS, AWS, etc.)
2. **During code review:** Use the "Code Quality & Documentation Standards" section to check quality metrics
3. **When debugging:** Consult "Common Pitfalls & Lessons Learned" to avoid known issues
4. **When adding to repo:** Ensure documentation follows the "Documentation Placement" rules
5. **In conversations:** Reference this document to establish shared context with other AI tools or team members

This document is **version-controlled** alongside the code. Update it whenever:
- New architectural patterns are discovered
- New pitfalls are encountered and resolved
- Phase gates are completed (Phase 2, Phase 3, etc.)
- Industry standards change significantly
