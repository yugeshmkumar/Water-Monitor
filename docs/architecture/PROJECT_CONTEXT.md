# Water Monitor Project Context

**Purpose:** Durable context file for future Codex/AI sessions. Read this before changing code, architecture, docs, tests, firmware, cloud sync, or app identity.

**Last reviewed:** 2026-05-30  
**Repo path during review:** `/Users/yugeshmluv/Work/Projects/code/Water-Monitor`  
**Canonical product name:** Water Monitor  
**Canonical repo slug:** `water-monitor` preferred, current local folder `Water-Monitor` acceptable  
**Canonical iOS app display name:** Water Monitor  
**Canonical Swift/Xcode target/module:** `WaterMonitor`

---

## How To Use This File

1. Treat this file as the first context file for every future discussion.
2. If this file conflicts with live source code, inspect the code and update this file or the code in the same change.
3. If this file conflicts with `CLAUDE.md`, `CLAUDE.md` wins for workflow rules, then update this file.
4. If this file conflicts with `docs/architecture/ARCHITECTURE.md`, inspect implementation and reconcile both docs.
5. Do not add new planning or audit docs in the repo root. Root docs are currently a known issue, not a precedent.

---

## Priority Legend

| Priority | Meaning |
|---|---|
| P0 | Non-negotiable. Must be preserved or fixed immediately. |
| P1 | High priority. Required before production/TestFlight-quality release. |
| P2 | Important quality or scalability item. Should be scheduled. |
| P3 | Future enhancement or cleanup. Do after P0-P2 are stable. |

---

## P0 Non-Negotiables

### P0.1 Product Identity

Use one public-facing product name:

| Surface | Value |
|---|---|
| Product/app name | Water Monitor |
| GitHub repo name | `water-monitor` preferred, `Water-Monitor` acceptable |
| iOS display name | Water Monitor |
| Swift module/target | `WaterMonitor` |
| Firmware/device family | Water Monitor tank sensor |
| Cloud resource prefix | `water-monitor-*` |

Current mismatch to fix:
- `README.md` title says `Water Level Monitor`.
- `docs/architecture/ARCHITECTURE.md` title says `Water Level Monitoring System`.
- Firmware boot log says `Water Level Monitor v1.0`.
- Xcode generated Info.plist does not explicitly set `CFBundleDisplayName = "Water Monitor"`, so iOS may display `WaterMonitor`.

Decision: keep `Water Monitor` as the brand; use "water level monitoring system" as descriptive copy only.

### P0.2 Scope And Phase Gate

Current product goal:
- Phase 1: ESP32-C6 tank sensor firmware plus SwiftUI iOS app.
- Phase 2A: cloud sync/offline sync infrastructure.
- Later Phase 2/3: motor controller, automation, Android, advanced ML.

Hard rule from `CLAUDE.md`:
- Do not scaffold new Phase 2 motor-controller work until Phase 1 is tested and stable.

Current ambiguity:
- Some docs say Phase 2A cloud is in progress/implemented, while `CLAUDE.md` says Phase 1 only.
- Resolve by treating Phase 2A cloud sync docs as design/reference unless code exists and tests prove it.
- Do not add new motor-controller firmware/UI unless explicitly requested and the phase gate is updated.

### P0.3 Documentation Placement

`README.md` is the only documentation file allowed in the repo root.

Correct locations:
- Architecture/design decisions: `docs/architecture/`
- Firmware build/dev docs: `docs/firmware/`
- Hardware wiring/BOM: `docs/hardware/`
- iOS app design/API contracts: `docs/ios-app/`
- Android app docs: `docs/android-app/`
- Cloud/API reference: `docs/api/`
- Audits/reports: `docs/analysis/`

Current violations/issues:
- `CODEBASE_AUDIT_FIX_PLAN.md` exists in repo root and should move to `docs/analysis/`.
- `README.md` references `docs/ios-app/api-contracts.md`, but `docs/ios-app/` does not currently exist.
- `android-app/README.md` is a doc inside a source-adjacent directory; `CLAUDE.md` says Android docs belong in `docs/android-app/`. Decide whether placeholder module docs are allowed or move it.
- IDE had `docs/analysis/README.md` open, but that file does not exist.

### P0.4 Architecture File Maintenance

`docs/architecture/ARCHITECTURE.md` must stay current.

Update it in the same change whenever:
- A source file is added, removed, renamed, or superseded.
- BLE UUIDs, REST endpoints, config keys, pin assignments, queue formats, or cloud flow change.
- A planned item becomes implemented.
- An implementation differs from the stated architecture.

### P0.5 Zero Data Loss

Data loss is unacceptable.

Required behavior:
- Device queues readings when app/cloud is unavailable.
- App persists readings locally before acknowledging device queue entries.
- Cloud ingest must be idempotent and deduplicate readings.
- Do not clear device queue entries until the app has safely persisted them and, for cloud sync flows, has either synced them or recorded them in a durable app sync queue.
- Test-mode/calibration readings must not pollute normal history and insights.

Current implementation signals:
- Firmware queue: LittleFS circular buffer, 2000 entries, 16 bytes each.
- REST queue endpoints: `/api/queue/flush` and `/api/queue/ack`.
- iOS models include `DeviceReading.isTest`.
- `QueueDrainer`, `QueueImporter`, and `DataPruner` exist.

Current risk:
- SwiftData container creation deletes the old store after schema failure in `WaterMonitorApp.swift`. This is acceptable only during development. Production requires a migration strategy.

### P0.6 Hardware Safety And Pin Rules

Board: Seeed Studio XIAO ESP32-C6.

Do not use GPIO3 or GPIO14 as normal I/O. They control the RF switch/antenna path on this board.

Current pin defaults:
- Trigger: `D2`
- Echo: `D1`
- ECHO voltage divider: 1k + 2k, 5V to 3.3V
- Sensor: JSN-SR04T Mode 0

Required behavior:
- Preserve RF-reserved pin comments in firmware and hardware docs.
- Validate user-selectable pin configuration so GPIO3/GPIO14 cannot be chosen.
- Never connect mains voltage to ESP32; motor relay work must use isolated relay modules and proper enclosures.

### P0.7 iOS Deployment Target

Architecture and README state iOS 17+ because SwiftData requires modern Apple OS support.

Current mismatch:
- Xcode project sets `IPHONEOS_DEPLOYMENT_TARGET = 26.2`.

Required correction:
- Set deployment target to iOS 17.0 unless a deliberate product decision raises it.
- If using iOS 26-only APIs, document them and decide whether they are worth losing older devices.

### P0.8 Permissions And Privacy Strings

The app uses:
- CoreBluetooth
- Local network connections to device REST/WebSocket endpoints
- Notifications

Required Info.plist/generated settings:
- `NSBluetoothAlwaysUsageDescription`
- `NSLocalNetworkUsageDescription`
- `CFBundleDisplayName = "Water Monitor"`
- If using Bonjour/mDNS service discovery explicitly, add `NSBonjourServices`.
- If CoreBluetooth background work is required, add the Bluetooth background mode and document exactly why.

Current state:
- Bluetooth and local network usage descriptions exist.
- Display name is missing.
- Bonjour services are not declared.
- Background BLE mode is not declared.

### P0.9 Security Baseline

Minimum security posture:
- No long-lived AWS secrets in the iOS app.
- Use Cognito Identity Pool temporary credentials for direct AWS access.
- Use least-privilege IAM policies scoped to the user's allowed resources.
- Validate device ownership server-side before accepting readings.
- Do not expose unauthenticated cloud endpoints.
- Local LAN REST endpoints may remain unauthenticated only for Phase 1/private LAN development; production must either document the risk or add pairing/token protection.
- OTA must be treated as security-sensitive. Do not allow arbitrary remote firmware URLs in production without authentication, integrity checking, and rollback/recovery guidance.
- Never log WiFi passwords, Cognito tokens, AWS credentials, or private user data.

---

## What We Are Building

Water Monitor is an offline-first IoT water tank monitoring system.

Phase 1:
- ESP32-C6 firmware reads tank level from a JSN-SR04T ultrasonic sensor.
- Device exposes BLE GATT for setup and fallback live readings.
- Device exposes local REST and WebSocket endpoints after WiFi setup.
- SwiftUI iOS app configures WiFi/tank/pins, monitors live readings, stores local history, shows alerts, supports calibration, and manages saved devices.

Phase 2A:
- Add cloud sync for readings, profiles, and multi-device/multi-phone consistency.
- Current cloud design favors AWS SQS-first ingest with Cognito temporary credentials, Lambda, DynamoDB, RDS/PostgreSQL, SNS, and CloudWatch.

Later phases:
- Motor controller node, automation, energy/water stats, Android app, optional Zigbee/Thread exploration, richer ML/anomaly detection.

---

## Current Codebase Snapshot

### Root

- `README.md`: public overview, quick start, repo layout.
- `CLAUDE.md`: project rules. Treat as workflow authority.
- `.github/workflows/ci.yml`: CI exists but currently masks failures with `|| true` in important places.
- `CODEBASE_AUDIT_FIX_PLAN.md`: root doc that should move to `docs/analysis/`.

### Firmware

Path: `firmware/tank-sensor/`

Key files:
- `platformio.ini`: PlatformIO Arduino project for ESP32-C6.
- `src/main.cpp`: FreeRTOS tasks, sensor loop, comms loop, BLE loop, WiFi/MQTT coordination.
- `src/config.h/.cpp`: NVS-backed config. All config changes must go through `Config`.
- `src/sensor.h/.cpp`: ultrasonic reading, filtering, level calculation, pin command handling.
- `src/queue_store.h/.cpp`: LittleFS queue, circular buffer, pending readings.
- `src/ble_server.h/.cpp`: NimBLE GATT server, AA01-AA06.
- `src/api_server.h/.cpp`: REST, WebSocket `/live`, OTA.
- `src/state.h` and `src/device_state.h`: shared state/mutex patterns.
- `src/constants.h`: centralized constants. Add tunables here, not as scattered literals.
- `src/pins.h`: board pin mapping and RF-reserved pin comments.
- `tests/`: Python tests for config and sensor logic.

Current firmware architecture:
- Single shared state lives in `gState`, guarded by `gStateMutex`.
- Config is centralized through the `Config` class.
- BLE and WiFi can both exist, but the iOS app intentionally avoids overloading ESP32 sockets by draining queues before opening WebSocket.
- MQTT is present/stubbed for later phase; do not build motor automation around it yet.

### iOS App

Path: `ios-app/mobile/WaterMonitor/`

Entry:
- `WaterMonitorApp.swift`: app entry, SwiftData `ModelContainer`, `ConnectionManager`, `NotificationManager`.
- `ContentView.swift`: launch router between splash/welcome/home.

Models:
- `DeviceReading`: persisted readings; includes `nodeID`, `readingType`, `isTest`.
- `SavedDevice`: known device metadata.
- `Tank`: tank topology.
- `MotorGroup`: future motor relationship model.
- `DeviceConfig`: Codable mirror of firmware config.
- `DeviceStatus`: merged live status from BLE/WiFi.
- `QueueEntry`: queue DTO from device REST flush.

Services:
- `ConnectionManager`: top-level orchestration.
- `TransportManager`: WiFi/BLE priority and switching.
- `BLEService`: CoreBluetooth scanning/connection/GATT.
- `BLENotificationHandler`: BLE notification decoding.
- `WiFiService`: coordinator around REST and WebSocket.
- `RestClient`: REST endpoints.
- `WebSocketManager`: `/live` streaming.
- `QueueDrainer`: device queue flush/ack.
- `QueueImporter`: queue entries to SwiftData.
- `DataCache`: SwiftData save/query.
- `DataPruner`: retention cleanup.
- `InsightsEngine`: predictions/statistics/anomaly insights.
- `NotificationManager` and `NotificationService`: local notification handling.

Views:
- App has both original and `_Refactored` view files for several screens.
- Xcode project uses a file-system-synchronized group, so duplicate type names in original and refactored files can compile if both files define the same symbols.
- Before building/releasing, confirm only one version of each duplicated view/component type is active.

Known duplicate/superseded risk:
- `TankCalibrationView.swift` and `TankCalibrationView_Refactored.swift` both define `TankCalibrationView`.
- Similar original/refactored pairs exist for `HistoryView`, `ConfigWizardView`, `DeviceDetailView`, `DashboardView`, `AddDeviceView`, `DeviceHealthCheckView`, and `InsightsView`.
- Decide the canonical file for each screen, remove or exclude superseded files, and update `ARCHITECTURE.md`.

### Docs

Primary docs:
- `docs/architecture/ARCHITECTURE.md`: implementation architecture.
- `docs/architecture/REQUIREMENTS.md`: Phase 2 requirements.
- `docs/architecture/IMPLEMENTATION_TODO.md`: detailed cloud/queue TODO.
- `docs/architecture/CLOUD_PERFORMANCE_ANALYSIS.md`: cloud comparison.
- `docs/api/PHASE_2A_IMPLEMENTATION.md`: current single comprehensive AWS Phase 2A guide.
- `docs/analysis/*`: audit/refactoring summaries.

Current doc mismatches:
- `README.md` references missing `docs/ios-app/api-contracts.md`.
- Architecture file's iOS file tree is behind the actual source structure.
- Architecture says UI is SwiftUI iOS 26 but deployment says iOS 17; resolve this distinction as "built with current Xcode/iOS SDK, deploys to iOS 17+".

---

## Current Architecture Decisions

### Device-To-App Transport

Priority:
1. WiFi/WebSocket for normal live readings once device is on LAN.
2. BLE for setup and fallback.
3. Offline mode with cached last reading and queue sync.

BLE is required for:
- First setup before WiFi credentials exist.
- Config writes during commissioning.
- Fallback when local network is unavailable.

WiFi is preferred because:
- Better throughput and lower latency.
- REST queue drain is more practical over WiFi.
- WebSocket `/live` gives real-time updates.

Important implementation detail:
- Queue drain should complete before opening WebSocket, because the ESP32 can be resource constrained when BLE, WebSocket, and bulk HTTP operations overlap.

### BLE Contract

Current service UUID:
- `0000AA01-0000-1000-8000-00805F9B34FB`

Characteristics:
- AA01: level read/notify
- AA02: status read/notify
- AA03: config read
- AA04: config write
- AA05: command write
- AA06: command result read/notify

Rules:
- If UUIDs or payloads change, update firmware, iOS, and architecture docs together.
- BLE notification handler must merge AA01/AA02 status rather than replacing state wholesale.
- Use `.withResponse` for write characteristics that require response.

### REST/WebSocket Contract

Current local API:
- `GET /api/status`
- `GET /api/config`
- `POST /api/config`
- `POST /api/queue/flush`
- `POST /api/queue/ack`
- `POST /api/command`
- `GET /api/ota/check`
- `POST /api/ota/start`
- `GET /update`
- `WS /live`

Rules:
- Local REST must return JSON.
- Keep API error responses structured.
- Update `RestClient`, firmware handlers, and docs together.
- Do not make iOS poll device history; queue sync is the source for missed readings.

### Persistence

iOS persistence:
- SwiftData.
- `DeviceReading` is historical local storage.
- `SavedDevice`, `Tank`, `MotorGroup` are topology/config models.

Rules:
- Model changes require migration planning.
- Do not delete production stores on schema failure.
- Use DTOs for cloud sync queues rather than storing SwiftData model objects inside queue payloads.
- Exclude `isTest == true` from normal history and insights.

Firmware persistence:
- NVS for config.
- LittleFS queue for readings.

Rules:
- Do not call `Preferences` outside `Config`.
- Do not mutate queue format without versioning/migration docs.

### Cloud Sync

Preferred current design:
- iOS app authenticates with Cognito.
- Cognito Identity Pool issues temporary AWS credentials.
- iOS batches pending readings and sends to SQS.
- Lambda consumes SQS, validates ownership, deduplicates, writes DynamoDB/RDS.
- SNS/CloudWatch handle alerts/ops.

Delivery semantics:
- Standard SQS is at-least-once and can duplicate messages.
- FIFO SQS can provide deduplication and ordering within constraints, but the app/cloud must still be idempotent.
- Always design cloud processing as idempotent.
- Lambda SQS integration should use partial batch responses so one failed reading/message does not retry the whole batch unnecessarily.

### AI/Insights

Current local insights:
- Predictions like time to empty.
- Fill/drain event detection.
- Daily/weekly/hourly usage statistics.
- Leak/spike/low-level insights.

Rules:
- Physics-based validation must run before accepting suspicious values as normal.
- Do not trust a single raw ultrasonic reading.
- Keep ML optional until deterministic rules and history are reliable.

---

## Priority Backlog

### P0 Fix Immediately

1. Fix iOS deployment target mismatch: change `26.2` to `17.0` or document a deliberate higher target.
2. Add explicit iOS display name: `CFBundleDisplayName = "Water Monitor"`.
3. Resolve duplicate original/refactored Swift type definitions before relying on builds.
4. Stop deleting SwiftData production stores on schema failure; gate current deletion as development-only or implement migration.
5. Move root `CODEBASE_AUDIT_FIX_PLAN.md` into `docs/analysis/` or document an exception.
6. Fix missing/stale doc references:
   - `docs/ios-app/api-contracts.md`
7. Update `ARCHITECTURE.md` file tree to match actual services/views.
8. Make CI fail when tests fail; remove `|| true` from important test steps.
9. Upgrade deprecated GitHub Actions such as `actions/upload-artifact@v3`.
10. Validate GPIO3/GPIO14 cannot be configured through the iOS pin UI.

### P1 Release Quality

1. Add/expand automated tests:
   - Firmware queue persistence and ACK behavior.
   - Firmware config validation.
   - iOS `ConnectionManager`, `QueueDrainer`, `QueueImporter`, `DataCache`.
   - SwiftData migration tests.
   - BLE payload decoding tests.
2. Add iOS build/test CI that actually fails on compile/test failure.
3. Define the production local network security model:
   - Pairing token?
   - LAN-only trust?
   - User-facing warning?
4. Define OTA security:
   - Signed firmware or trusted update source.
   - Rollback behavior.
   - Disable arbitrary URL update in production unless secured.
5. Add cloud sync schema and idempotency tests before enabling production sync.
6. Confirm notification authorization flow and UX.
7. Add app privacy notes for Bluetooth, local network, notifications, and cloud data.

### P2 Architecture And Maintainability

1. Finish view refactoring by choosing canonical files and removing/excluding superseded files.
2. Keep components around 100-200 lines when reasonable.
3. Continue service single-responsibility structure.
4. Replace silent `try?` in important flows with user-visible or logged errors.
5. Add structured logging policy for firmware and iOS.
6. Add performance benchmarks:
   - BLE discovery/connect time.
   - WebSocket latency.
   - Queue drain throughput.
   - SwiftData history fetch time.
7. Add docs for data retention and pruning.

### P3 Future Work

1. Motor controller Node B.
2. Android app.
3. Cloud profile sharing UI.
4. Advanced ML validation.
5. Water quality sensors.
6. Zigbee/Thread only if WiFi/BLE rooftop reliability fails.

---

## Coding Rules For Future AI Sessions

### General

- Read existing code before changing it.
- Keep changes scoped.
- Use repo patterns and helper types before adding new abstractions.
- Do not introduce broad refactors while fixing a narrow issue.
- If changing behavior, update tests or explain why tests cannot be run.

### Firmware

- Put constants in `constants.h`.
- Preserve `gState`/`gStateMutex` ownership.
- Use `Config` for NVS.
- Avoid blocking work in high-frequency tasks.
- Be careful with AsyncWebServer callback context.
- Queue writes and ACKs must be robust against reboot or partial failure.
- Keep JSN-SR04T filtering conservative; do not trust one sample.

### iOS

- Use SwiftUI + SwiftData patterns already present.
- Remember SwiftData `ModelContext` is main-actor-sensitive in this project.
- Avoid local `@Bindable` in `body` declarations; architecture notes mention a Swift 6.2.3 type checker crash.
- Do not create duplicate type names across original/refactored files.
- Prefer focused views/services over large monoliths.
- User-facing text should say "Water Monitor".
- Keep WiFi > BLE > offline transport priority.
- Do not open WebSocket until bulk device queue drain is complete.

### Cloud

- Treat all queue processing as at-least-once unless proven otherwise.
- Use explicit idempotency keys.
- Validate ownership server-side.
- Store only temporary credentials on device/app.
- Use partial batch failure handling for SQS-triggered Lambda.
- Monitor cost and DLQ depth.

### Docs

- No new root docs.
- Update `ARCHITECTURE.md` with meaningful implementation changes.
- Keep this context file current when decisions change.
- Prefer one canonical doc over many superseded variants.

---

## External Standards Checked On 2026-05-30

These links were used to validate platform-sensitive decisions. Re-check them when upgrading major SDKs, OS targets, cloud design, CI actions, or board hardware.

### Apple

- SwiftData official documentation: https://developer.apple.com/documentation/SwiftData  
  Implication: SwiftData is the correct local persistence framework for iOS 17+ app architecture, but schema migration must be handled deliberately.

- WWDC23 SwiftData materials: https://developer.apple.com/videos/wwdc2023/?q=swiftdata  
  Implication: SwiftData arrived with the iOS 17 era; iOS 17+ remains the sensible minimum unless newer APIs are required.

- Core Bluetooth documentation: https://developer.apple.com/documentation/corebluetooth  
  Implication: include Bluetooth usage descriptions and respect CoreBluetooth lifecycle/state handling.

- Core Bluetooth background processing: https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html  
  Implication: only add BLE background modes if the app truly needs background BLE work.

- Local network privacy key: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSLocalNetworkUsageDescription  
  Implication: local REST/WebSocket/mDNS access requires a clear local network usage description.

- Local network privacy technote: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy  
  Implication: declare Bonjour services if relying on Bonjour service discovery.

- Notification authorization: https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications  
  Implication: request notification permission before scheduling alerts.

- `.local` and Bonjour behavior: https://support.apple.com/en-us/101903  
  Implication: use `.local` for mDNS/Bonjour devices, but avoid treating it like ordinary DNS.

### ESP32 / Seeed

- ESP32-C6 RF coexistence: https://docs.espressif.com/projects/esp-idf/en/v5.1.2/esp32c6/api-guides/coexist.html  
  Implication: ESP32-C6 shares one 2.4 GHz RF module; WiFi/BLE coexistence is time-shared and should not be overloaded.

- ESP32-C6 datasheet: https://documentation.espressif.com/esp32-c6_datasheet_en.html  
  Implication: board and radio capabilities must be verified against Espressif docs before changing hardware assumptions.

- Seeed XIAO ESP32-C6 getting started / RF switch: https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/  
  Implication: GPIO3 and GPIO14 participate in RF switch/antenna behavior on this board; keep them reserved.

- Arduino-ESP32 Preferences docs: https://espressif-docs.readthedocs-hosted.com/projects/arduino-esp32/en/latest/tutorials/preferences.html  
  Implication: NVS/Preferences should remain centralized and monitored for namespace/partition issues.

- Espressif NVS encryption docs: https://docs.espressif.com/projects/esp-idf/en/latest/esp32c2/api-reference/storage/nvs_encryption.html  
  Implication: if production requires encrypted WiFi credentials, confirm actual Arduino/ESP-IDF integration rather than assuming Preferences are encrypted.

### AWS

- SQS queue types: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html  
  Implication: Standard queues are not exactly-once; idempotency is mandatory. FIFO queues provide dedup/ordering features but do not remove the need for robust consumers.

- SQS FIFO exactly-once processing: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html  
  Implication: if exactly-once processing is required, use FIFO semantics carefully with deduplication IDs and message groups.

- Cognito Identity Pools: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-identity.html  
  Implication: use Identity Pools to exchange authenticated identity for temporary AWS credentials.

- Cognito temporary AWS access: https://docs.aws.amazon.com/cognito/latest/developerguide/accessing-aws-services.html  
  Implication: mobile app should not store long-lived AWS secrets.

- Lambda with SQS: https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html  
  Implication: implement partial batch responses for reliable batch processing.

- Lambda SQS error handling: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-errorhandling.html  
  Implication: failed items should be retried without reprocessing successful items.

### Security

- OWASP IoT project: https://owasp.org/www-project-internet-of-things/  
  Implication: watch for weak auth, insecure network services, weak encryption, poor update mechanisms, lack of device management.

- OWASP IoT firmware update testing: https://owasp.org/owasp-istg/03_test_cases/firmware/firmware_update_mechanism.html  
  Implication: OTA is a security boundary and needs integrity/authenticity controls.

### GitHub Actions

- `actions/checkout`: https://github.com/actions/checkout  
  Implication: keep checkout action versions current.

- `actions/upload-artifact`: https://github.com/actions/upload-artifact  
  Implication: v3 is deprecated; update workflow to current supported major.

- GitHub Actions artifact v4 changelog: https://github.blog/changelog/2023-12-14-github-actions-artifacts-v4-is-now-generally-available/  
  Implication: artifact action upgrades may need workflow changes.

---

## Known Corrections To Apply Soon

Use this as a short operational checklist:

- [ ] Rename public docs from "Water Level Monitor" to "Water Monitor" where user-facing.
- [ ] Add `CFBundleDisplayName = "Water Monitor"`.
- [ ] Change iOS deployment target from `26.2` to `17.0`, or document why not.
- [ ] Fix bundle identifier style if desired: prefer reverse-DNS lowercase such as `com.yugeshmkumar.watermonitor`.
- [ ] Move root audit plan into `docs/analysis/`.
- [ ] Create or remove reference to `docs/ios-app/api-contracts.md`.
- [ ] Resolve duplicate Swift view definitions from original/refactored files.
- [ ] Remove `|| true` from CI test/build commands.
- [ ] Upgrade deprecated GitHub Actions.
- [ ] Replace development-only SwiftData destructive fallback before production.
- [ ] Verify pin picker rejects GPIO3/GPIO14.
- [ ] Add production OTA security decision.
- [ ] Add idempotent cloud sync tests before real data sync.

---

## Comprehensive Technical Standards (Round 2 Audit)

**New:** For detailed firmware documentation standards, iOS MVVM patterns, service architecture, AWS cloud design patterns, code quality metrics, and industry best practices validated against 2026 standards, see:

📄 **[CONTEXT_AND_STANDARDS.md](CONTEXT_AND_STANDARDS.md)** (Complete technical reference)

This document covers:
- Firmware architecture patterns (FreeRTOS task coordination, constants extraction, documentation ratio targets)
- iOS MVVM + service refactoring (after Phase 3: 8 services, Single Responsibility achieved)
- iOS view component extraction (after Phase 4: 22 focused components, 48-82% complexity reduction)
- AWS cloud architecture (Cellular pattern, SQS-first ingest, idempotency, least-privilege IAM)
- Code quality metrics (cyclomatic complexity, documentation ratios, testing standards)
- BLE, WiFi, REST, WebSocket communication patterns
- Common pitfalls and lessons learned from Round 2 Code Audit
- External standards references from Apple, Espressif, AWS, OWASP

**Use PROJECT_CONTEXT.md for:** strategic decisions, phase gates, P0-P3 priority backlog, coding rules, product identity.  
**Use CONTEXT_AND_STANDARDS.md for:** detailed technical patterns, industry standards, code examples, quality metrics.

---

## Final AI Instruction

When in doubt, optimize for:

1. No data loss.
2. Hardware safety.
3. Clear phase boundaries.
4. One canonical product identity.
5. Source-backed platform decisions.
6. Small, testable changes.
7. Updated architecture docs in the same change.
8. Consult CONTEXT_AND_STANDARDS.md for detailed technical validation.
