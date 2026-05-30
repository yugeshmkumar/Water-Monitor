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
6. Distinguish implemented facts from target standards. Before claiming a tool, library, CI check, cloud resource, or feature exists, verify it in the repo or deployed environment.

---

## Git & Branch Workflow (Critical)

**Hard Rules — Enforce Always:**

| Rule | Reason | Violation Cost |
|------|--------|---|
| `main` = IMMUTABLE baseline | Original stable state for rollback | Data loss, lost baseline |
| `master` = Stable, tested code | Production-ready, well-reviewed | Broken prod, user impact |
| `fixes` = Active development | All features merge here first | History pollution, hard to track |
| Merge: `fixes` → `master` only | Prevents direct-to-master skips | Untested code in stable branch |
| Never merge to `main` | Contaminates immutable baseline | Loses original state forever |
| All commits: `yugeshmkumar` | Correct authorship attribution | Wrong user credited for work |

**Workflow:**

```
audit/*  (temp feature branches)
  ↓ (merge after code review)
fixes    (active development)
  ↓ (merge after all tests pass)
master   (stable, tested, ready for deploy)

main     (IMMUTABLE — never touch)
```

**Commit Authorship:**

```bash
# Configure local git (per session)
git config --local user.name "yugeshmkumar"
git config --local user.email "yugeshmkumar@gmail.com"
```

Co-author trailers are optional and should match the actual collaborator/tool only when the user or repo policy asks for them. Do not hardcode another AI agent's identity in future commits.

Forbidden unless explicitly requested by the user:
- `git commit --amend`
- `git commit --no-verify`
- `git push --force`
- `git reset --hard`

**Remote/Auth Verification:**

```bash
git remote -v
git config --local user.name
git config --local user.email
ssh -T git@github.com  # if using SSH
git ls-remote origin   # safe remote access check
```

Do not use `git push origin master` as an authentication test; it can mutate the remote.

**Branch Protection Rules (Enforce via GitHub):**

- `main`: no direct pushes, no force pushes (protect immutable baseline)
- `master`: require review and tests passing (prevent broken releases)
- `fixes`: require review when practical (prevent unreviewed integration work)
- Signed commits are desirable if the team enables them; do not claim they are enforced unless GitHub branch protection confirms it.

**Lesson From Existing Project Notes:**

Project audit notes describe a prior mistake where audit work was merged to `main` instead of `fixes`. Treat this as a standing warning even if branch history changes later. Prevention:
- Always check branch name before merging: `git branch` shows current branch
- Use GitHub branch protection to prevent direct pushes to `main`/`master`
- Use `git log --oneline main` to verify `main` never changes after initial import

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

### P0.5 Zero Data Loss (Phase 1 & 2A Context)

Data loss is unacceptable in normal operation.

**Phase 1 (Current):**
- Device queues readings when app is unavailable (✅ LittleFS circular buffer, 2000 entries, 16 bytes each)
- App persists readings before ACK'ing device entries (✅ RestClient + QueueDrainer + QueueImporter)
- Test-mode readings excluded from history/analytics (✅ `isTest` flag filters data)
- **Known limitation:** Queue overflow (>1hr offline @ max frequency) discards oldest unsent entries
  - **Acceptable for Phase 1** (short WiFi outages, auto-reconnect limits downtime <5 min typical)
  - **Mitigated in Phase 2A** by cloud sync every 30s

**Phase 2A (Cloud Sync):**
- Cloud ACK prevents local queue overflow
- Idempotent dedup by (device_id, timestamp)

Current risks:
- SwiftData container deletion on schema failure (acceptable Phase 1 only; Phase 2 needs migration)
- Queue overflow acceptable Phase 1; Phase 2A solves via cloud draining

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

### P0.8 Permissions And Privacy Strings (Phase 1)

The app uses:
- CoreBluetooth (scanning, discovery, GATT read/write)
- Local network connections (mDNS discovery, REST/WebSocket to device)
- Notifications (low/high water level alerts)

Required Info.plist settings (Phase 1):
- ✅ `NSBluetoothAlwaysUsageDescription` (exists)
- ✅ `NSLocalNetworkUsageDescription` (exists)
- [ ] `CFBundleDisplayName = "Water Monitor"` (missing; currently auto-generated as "WaterMonitor")
- [ ] `NSBonjourServices` if mDNS discovery used (optional Phase 1)
- [ ] Background BLE mode (optional if not needed for Phase 1)

Current state:
- Bluetooth usage description: present
- Local network usage description: present
- App display name: missing (fix before TestFlight/App Store)
- Bonjour services declaration: not needed for Phase 1

### P0.9 Security Baseline

Minimum security posture for Phase 1:
- Never log WiFi passwords, Cognito tokens, AWS credentials, or private user data.
- Local LAN REST endpoints may remain unauthenticated for Phase 1/private LAN development.
- Validate GPIO3/GPIO14 are never used (RF switch lines on XIAO ESP32-C6).

**Phase 2A (Cloud Sync) Security Requirements:**
- No long-lived AWS secrets in iOS app; use Cognito temporary credentials only.
- Least-privilege IAM policies scoped to user/device resources.
- Validate device ownership server-side before accepting readings.
- Do not expose unauthenticated cloud endpoints.
- OTA: authentication, integrity checking, and rollback/recovery guidance (not implemented Phase 1).

### P0.10 Branch And Git Safety

Follow the Git & Branch Workflow section at the top of this file. In short: `main` is immutable, `fixes` is active development, `master` is stable, and destructive git commands require explicit user direction.

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
- `queue_store.cpp` currently uses `Preferences` for queue metadata. This is an existing implementation detail; new config/NVS work should still go through `Config` unless queue metadata is intentionally refactored.

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
- Xcode project uses a file-system-synchronized group, so duplicate type names in original and refactored files may be included automatically and cause compile failures.
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
- Do not add new `Preferences` usage outside `Config` without an explicit architectural reason. Existing queue metadata usage in `queue_store.cpp` is a known exception to review/refactor deliberately, not a pattern to copy.
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

### Calibration Rules

Current quick calibration intent:
- Ask the user for tank percentage at both calibration points, not just "empty" and "full".
- Record a stable distance and the user-entered percentage for point 1.
- Record a stable distance and the user-entered percentage for point 2.
- Calculate empty/full distances from the two-point line.

Formula:
```swift
let range = 100.0 * (dist1 - dist2) / (pct1 - pct2)
let fullCM = dist1 - (pct1 / 100.0) * range
let emptyCM = fullCM + range
```

Rules:
- Reject calibration if the two percentages are too close to produce a stable range.
- Prefer stable readings; use rolling-window stability and outlier rejection.
- Mark calibration/test readings with `isTest = true`.
- Exclude test readings from history charts, insights, usage estimates, and cloud analytics unless explicitly debugging.

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

## Known Pitfalls From Experience

Keep this section factual and enforceable. Do not add incident details or "fixed" status unless verified from git history, branch protection, tests, or deployment evidence.

1. Branch mistakes: never merge or push feature/audit work to `main`; verify branch and merge direction before any git operation.
2. Authorship vs authentication: `git config user.name/email` controls commit metadata only; verify remote access separately with `ssh -T git@github.com` or `git ls-remote origin`.
3. Partial queue sync: WiFi can drop mid-flush; ACK only after durable import/persistence and make replays idempotent.
4. BLE discovery ambiguity: service UUID alone may not uniquely identify a device; validate node ID/config before saving or updating a device.
5. Sensor tuning: Kalman and stability thresholds need real-world validation across tank sizes and mounting conditions.
6. Flash wear: queue write frequency and LittleFS behavior must be measured under sustained deployment; do not assume generic write-cycle numbers.
7. Shared state races: every `gState` access must be protected by the documented mutex pattern.
8. UI test fragility: use accessibility identifiers and waits; avoid position-based taps and fixed sleeps.
9. Queue overflow: P0 says data loss is unacceptable; add tests/alerts/backpressure before treating overflow as acceptable.
10. Silent failures: avoid `try?` in WiFi, queue, calibration, persistence, and cloud sync flows unless failure is truly non-critical and logged.

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
- Use `Config` for device config/NVS. Do not add new direct `Preferences` usage unless the architecture explicitly calls for a separate metadata namespace, as with current queue metadata.
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

## Testing Strategy (Phase Gate Readiness)

Define what "tested and stable" means before enabling production Phase 2A cloud sync or opening the Phase 2 motor-controller gate. Phase 2A design documents can exist before this gate, but production implementation should not bypass these checks.

### Firmware Testing

**Unit Tests (PlatformIO tests/ directory):**
- [ ] Kalman filter: sample inputs → expected smoothed outputs ±5%
- [ ] Queue store: circular buffer append/read/wrap-around behavior
- [ ] Config parsing: valid JSON, partial updates, defaults applied
- [ ] Error handling: sensor timeout recovery, WiFi disconnect handling
- [ ] Constants: all magic numbers extracted, KF_INITIAL_P = 1000.0f verified

**Hardware Tests (manual on Seeed XIAO ESP32-C6):**
- [ ] Sensor accuracy: known distances (10cm, 50cm, 100cm) read ±2cm
- [ ] Calibration: two recorded distance/percentage points produce correct empty_cm, full_cm
- [ ] BLE discovery: scan finds device in <10 seconds
- [ ] WiFi connect: SSID/password written via BLE AA04, device connects
- [ ] Queue persistence: 100 entries survive reboot, replay on next sync
- [ ] OTA: upload new firmware, device reboots, verifies version

**Integration Tests (device + app together):**
- [ ] BLE → WiFi transition: start with BLE, enable WiFi, seamless switch
- [ ] Queue sync: 50 queued readings flush to app without loss
- [ ] Offline recovery: disconnect WiFi 10 minutes, reconnect, all readings synced
- [ ] Concurrent BLE + WiFi: BLE config write works while WiFi WebSocket active

**Stability Test (72-hour soak):**
- [ ] Device powers on, runs continuously 72 hours
- [ ] No crashes, watchdog resets, or data corruption
- [ ] Queue remains stable (no overflow, all reads consistent)
- [ ] Readings sampled every 10 seconds, <100 missed samples

### iOS Testing

**Unit Tests (XCTest):**
- [ ] ConnectionManager: WiFi available → use REST; WiFi down → use BLE
- [ ] DataCache: import 100 readings → dedup by (nodeID, timestamp)
- [ ] QueueDrainer: 3-attempt retry on ACK failure
- [ ] InsightsEngine: 7 days of readings → drain rate calculation correct ±5%
- [ ] TankCalibrationView: two-point formula produces correct empty_cm, full_cm
- [ ] isTest flag: test readings excluded from history/insights

**UI Tests (Snapshot + Interaction):**
- [ ] DashboardView: 75% level → gauge at 75%, color blue (normal)
- [ ] DashboardView: 10% level → gauge at 10%, color red (low alert)
- [ ] HistoryView: select 7-day range → chart renders, no blank areas
- [ ] ConfigWizardView: enter WiFi SSID/password → saved to device
- [ ] NotificationManager: low/high alerts trigger at configured thresholds

**Integration Tests (Simulator + Real Device):**
- [ ] Full user flow: add device → configure WiFi/tank → view dashboard
- [ ] Offline → Online: disable WiFi, make local changes, enable WiFi, sync
- [ ] Multi-device: add 3 devices, verify each device's readings separate
- [ ] Notification: trigger low-level alert, verify notification appears (iOS 17+)

**App Lifecycle Tests:**
- [ ] Kill app mid-sync: relaunch, verify queue resume from checkpoint
- [ ] Network loss during load: graceful fallback to last cached reading
- [ ] Rapid WiFi on/off: no crashes, no data loss

### AWS Testing (Phase 2A)

**Unit Tests (Python pytest):**
- [ ] Lambda: verify device ownership before accepting reading
- [ ] Lambda: dedup readings by (device_id, timestamp)
- [ ] Lambda: handle malformed SQS messages gracefully
- [ ] RDS: write schema correct, all fields populated

**Integration Tests:**
- [ ] E2E: iOS app → SQS → Lambda → DynamoDB → RDS
- [ ] Idempotency: send duplicate message, verify single record written
- [ ] Offline: queue readings while offline, sync to cloud when online
- [ ] Partial batch failure: 1 bad reading in 100-message batch doesn't block others

**Load Tests:**
- [ ] Sustained: 100 devices, 1000 readings/day each for 30 days
- [ ] Spike: 1000 devices send simultaneously, no throttle
- [ ] Cost: verify <$10/month per active device

### Test Coverage Targets

| Component | Target | Status |
|-----------|--------|--------|
| Firmware unit tests | 60%+ code coverage | 🔄 P1 |
| iOS unit tests | 60%+ code coverage | 🔄 P1 |
| AWS Lambda | 80%+ code coverage | 🔄 P2A |
| Integration tests | all critical paths | 🔄 P1 |
| UI tests | core screens (dashboard, history, add device) | 🔄 P1 |

### Phase 1 → Production Phase 2A Gate Criteria

Before enabling production cloud sync, Phase 1 must pass all of:

**Firmware:**
- [ ] All firmware unit tests passing (`pytest` suite)
- [ ] 72-hour hardware soak test completed (no crashes, reboots, or data corruption)
- [ ] Sensor accuracy verified ±2cm across tank sizes
- [ ] Queue overflow test: 100 readings/min for 2 hours, verify oldest unsent dropped correctly

**iOS App:**
- [ ] Integration test suite passing: add device → configure → view dashboard → history
- [ ] BLE ↔ WiFi failover tested: enable/disable WiFi 3 times, verify no data loss or duplicate readings
- [ ] Offline recovery tested: disconnect WiFi 1+ hour, reconnect, verify all pending readings synced

**Data Integrity:**
- [ ] No data loss in test sequences (100 queued readings, queue flush, ACK, app import all accounted)
- [ ] Test-mode readings never appear in production history/insights

**Operational:**
- [ ] All P0 items in CLAUDE.md and P0.1-P0.10 here verified in code
- [ ] Battery drain measured (if Phase 1 includes battery-backed devices)
- [ ] Error logging verified (no silent failures in WiFi, queue, or calibration flows)

---

## Performance Targets & Monitoring

Define performance expectations and observability requirements.

### Performance Targets

**Firmware:**
| Operation | Target | Measurement Rule |
|-----------|--------|---|
| Sensor read latency | <300ms for configured sampling path | Measure on hardware with serial timestamps |
| BLE characteristic read | <500ms round-trip | Measure from iOS action to decoded response |
| WiFi GET /api/status | <500ms on local LAN | Measure with app and curl during soak |
| Queue flush (50 entries) | <5s | Measure full fetch/import/ACK cycle |
| WebSocket live update latency | <500ms on local LAN | Measure device timestamp to app receipt |
| Heap usage | No sustained downward trend | Track during 72-hour soak |
| Uptime | 72-hour soak without crash/reset before Phase 2A | Verify on hardware |

**iOS:**
| Operation | Target | Measurement Rule |
|-----------|--------|---|
| BLE scan discovery | <15s | Measure Add Device scan flow |
| BLE connect | <5s after user selection | Measure selection to config read |
| WiFi REST connect | <5s to known device | Measure `fetchStatus()` path |
| Dashboard render | No blank/blocked primary UI | Verify on simulator and device |
| History chart (7 days) | <2s for expected local dataset | Measure after seeding test readings |
| Notification delivery | Promptly after local threshold detection | Verify with notification permission enabled |
| Memory usage | No obvious leak during repeated navigation | Profile before release |

**AWS (Phase 2A):**
| Operation | Target | Measurement Rule |
|-----------|--------|---|
| SQS to Lambda | Low-latency enough for batch sync; exact target after pilot | Measure CloudWatch iterator age and duration |
| Lambda to DynamoDB/RDS | No throttling at expected pilot load | Load test with realistic batches |
| Insights computation | Fast enough for interactive app use or background job SLA | Define once insights endpoint exists |
| Cost per device | Track against budget before production | Use AWS Budgets and cost allocation tags |

### Monitoring & Observability

**Firmware Logging (Serial Console):**

Boot:
```
[INFO] Water Monitor tank-sensor v1.0 starting...
[INFO] Loaded config: WiFi SSID="Home", tank empty=20cm, full=100cm
[INFO] Starting FreeRTOS tasks: sensor, comms, ble
```

WiFi:
```
[INFO] WiFi connecting to "Home"...
[INFO] WiFi connected: IP=192.168.1.100, RSSI=-55dBm
[INFO] mDNS advertised as: waterlevel-a.local
[WARNING] WiFi disconnected (signal lost), retrying...
```

Queue:
```
[INFO] Queue: 25/2000 entries pending
[INFO] Queue flush started (25 entries)
[INFO] Queue flush complete, all ACK'd
[WARNING] Queue: 95% full (1900/2000 entries)
```

Errors:
```
[ERROR] Sensor timeout after 3 retries, using last reading
[ERROR] WiFi connect failed: WRONG_PASSWORD, check credentials
[ERROR] Queue write failed: LittleFS full
```

**iOS Logging (Console now; CloudWatch or remote logging only after cloud observability exists):**

Device Discovery:
```
[DEBUG] Discovered device: waterlevel-a (RSSI -65dBm)
[DEBUG] Connecting to device via WiFi...
[INFO] Connected to device, fetched status: 75% (distance 50.0cm)
```

Data Sync:
```
[INFO] Syncing 50 readings from device queue...
[DEBUG] POST /api/queue/flush → 200 OK (50 entries)
[DEBUG] Imported 50 readings to SwiftData
[INFO] Queue sync complete, device queue cleared
```

Errors:
```
[WARNING] WiFi connect failed, falling back to BLE
[ERROR] Failed to sync readings: connection timeout (retrying in 5s...)
[ERROR] Device offline for >1 hour, showing cached reading
```

**Monitoring Rules (Forbidden):**
- ❌ Never log WiFi passwords, MQTT credentials, AWS tokens
- ❌ Never log high-volume raw sensor samples in production; use bounded debug logs for diagnostics
- ❌ Never log personally identifiable information (PII)
- ❌ Silent failures: ALL errors must be logged with context

**CloudWatch Alarms (Phase 2A):**

| Metric | Threshold | Action |
|--------|-----------|--------|
| SQS queue depth | >500 messages | Investigate sync backlog |
| SQS DLQ depth | >10 messages | Investigate poison messages |
| Lambda error rate | >5% per hour | Roll back latest deployment |
| DynamoDB throttle | any occurrence | Scale up capacity |
| RDS CPU | >80% sustained | Scale up instance |
| RDS storage | >80% usage | Archive old data or scale storage |

**Health Checks (Phase 1):**

App should display:
```
Device: waterlevel-a
Status: Online (WiFi)
Last Reading: 75% (2 minutes ago)
Queue Depth: 0 (synced)
Signal: -55 dBm (good)
Firmware: v1.0.2 (up-to-date)
```

Offline device should display:
```
Device: waterlevel-a
Status: Offline (WiFi down, last BLE 1 hour ago)
Last Reading: 75% (1 hour ago)  ⚠️ STALE
Queue Depth: 45 (pending)
[Fix Connection] button
```

---

## Technical Standards & Best Practices (Round 2 Code Audit Results)

This section consolidates technical patterns, code quality metrics, and industry validation from the comprehensive Round 2 Code Audit.

### Firmware Architecture Patterns

**FreeRTOS Task Structure:**
- Sensor task: reads distance, applies Kalman filter (P = 1000.0f initial), updates gState under mutex
- Comms task: WiFi connect, REST API, WebSocket `/live` with 30s keepalive ping
- BLE task: NimBLE GATT server AA01-AA06 characteristics
- Watchdog/monitoring: desired standard for system health, queue overflow detection, and recovery; verify actual implementation before relying on it.

**State Management:**
- All shared state in `gState` struct, guarded by `gStateMutex` (FreeRTOS mutex)
- No nested locks (deadlock prevention)
- Config centralized through `Config` class (NVS-backed, atomic writes)
- Tunable firmware constants belong in `constants.h`; do not assume every literal in the repo is already extracted.

**Documentation Target: 50-70% ratio** (exceeds industry 40-50% standard)
- Architecture overviews explaining WHY not just WHAT
- Thread safety guarantees documented
- Performance notes and limitations
- Error codes with recovery strategies
- Usage examples

### iOS Architecture Patterns

**MVVM + Service Architecture** (Post-Phase 3 Refactoring):

| Layer | Pattern | Rules |
|-------|---------|-------|
| Views | SwiftUI components | Keep under 150 lines; one responsibility; use @State/@Binding |
| ViewModels | `@Observable` state wrappers | Use main-actor-safe patterns for UI/persistence work; avoid importing SwiftUI unless a view type is truly needed |
| Services | Focused on one domain | 8 services after refactoring (RestClient, WebSocketManager, BLENotificationHandler, TransportManager, QueueDrainer, QueueImporter, DataPruner, ConnectionManager as orchestrator) |
| Models | SwiftData persistence | DeviceReading, SavedDevice, Tank; include `isTest` flag for filtering |

**Single Responsibility Principle** (Validated via Phase 3):
- RestClient = HTTP only (no WebSocket, no caching)
- WebSocketManager = WebSocket only (no HTTP)
- ConnectionManager = orchestrator (delegates to specific transports)
- No circular dependencies
- 532 lines redistributed across 8 new services in Phase 3

**View Component Extraction** (Phase 4 Results):
- 8 large views (567-426 lines) → 22 focused components (avg 110 lines)
- Coordinator pattern: manage state machine + orchestrate components
- Complexity reduction: 48-82% per view
- Example: TankCalibrationView (567 lines) → 5 components + coordinator (150 lines total)

### iOS Code Quality Metrics

| Metric | Target | How to Check |
|--------|--------|-------------|
| Cyclomatic Complexity | ≤10 per function | Add/verify SwiftLint or equivalent before enforcing automatically |
| Lines per Function | ≤30 (views), ≤50 (firmware) | Code review |
| Method Count | ≤20 per class | Code review |
| Test Coverage | ≥60% critical paths | XCTest + manual testing |
| Documentation Ratio | 40-50% (standard), 50-70% (firmware) | Manual review |
| Component Size | 100-200 lines ideal | Code review + refactor if >250 |

### Communication Protocol Patterns

**Transport Priority (Hard Rule):**
1. WiFi (REST + WebSocket) — preferred, fast, enables queue flush
2. BLE — setup and fallback live/status/config path, slower and limited compared with WiFi
3. Offline — queue + retry on reconnect

**Keepalive & Auto-Reconnect:**
- WebSocket: 30s server ping → client pong (automatic in URLSession)
- Reconnect: 5s exponential backoff (5s → 10s → 30s → 1m)
- Retry: 3 attempts REST (1s, 2s, 4s backoff), 2 attempts BLE

**Queue Synchronization:**
- Device: LittleFS circular buffer (2000 × 16 bytes)
- App: POST `/api/queue/flush`, then POST `/api/queue/ack` with `seq_up_to` after the batch is durably persisted/imported
- Idempotent: ACK only persisted/imported entries
- Cloud: SQS standard queue → Lambda → RDS/DynamoDB

### AWS Cloud Patterns

**Failure Domain Isolation Targets:**
- Avoid single hot partitions, global bottleneck tables, or queues that mix unrelated workloads without a reason.
- Prefer partition keys and queue grouping that match access patterns and ownership checks.
- Use FIFO queues only when ordering/dedup semantics are truly required; standard queues still require idempotent consumers.
- In-memory Lambda cache can reduce lookups, but never depend on cache persistence or freshness for authorization.

**Idempotency Rules:**
- Reads: never replayed (read-only operations)
- Writes: SQS message ID + device_id + timestamp = idempotency key
- Lambda: upsert/dedup before writes
- DynamoDB: TTL 1 year, PITR enabled for recovery

**Security Baseline:**
- No long-lived AWS secrets in app (Cognito temporary credentials only)
- Least-privilege IAM (specific resources per user/device)
- Server-side ownership validation (device_users table)
- OTA requires signed firmware + rollback support
- Never log passwords, tokens, AWS credentials

### Data Persistence Rules

**iOS (SwiftData):**
- Schema changes require migration planning (do NOT delete production stores)
- Use DTOs for cloud sync queues (not SwiftData models)
- Exclude `isTest == true` from history and insights
- ModelContext is main-actor-sensitive

**Firmware (NVS + LittleFS):**
- NVS: centralize through `Config` class only
- Queue: circular buffer, versioned format, survives reboot
- Monitor flash wear and queue churn after sustained deployments; do not assume a generic write-cycle number applies to this board/filesystem configuration without measurement.
- Backup: queue ACK semantics prevent data loss

### Code Review Checklist (Mandatory Before Merge)

- ✅ Documentation: 50-70% ratio headers, 40-50% services
- ✅ Constants: no magic numbers (use constants.h or named consts)
- ✅ Single Responsibility: each class does ONE thing
- ✅ Thread Safety: mutex/queue/@MainActor used correctly
- ✅ Error Handling: no silent `try?` in critical flows
- ✅ Testing: unit tests for all public APIs
- ✅ ARCHITECTURE.md: updated in same commit

### Testing Standards

Unit tests:
- Test one behavior per test.
- Use descriptive names that state the scenario and expected result.
- Mock BLE, WiFi, REST, WebSocket, cloud, and persistence boundaries.
- Cover firmware config parsing, sensor math, queue persistence, ACK behavior, BLE decoding, queue importing, and SwiftData migration.

Integration tests:
- Use real hardware for BLE/WiFi commissioning flows.
- Verify queue survives device reboot.
- Verify app restart preserves pending readings.
- Verify offline to online sync produces no duplicates and no lost readings.
- Verify two phones syncing the same device do not corrupt profile or readings.

UI/manual tests:
- Device add flow: scan → configure WiFi → save device → health check.
- Dashboard: live gauge, connection badge, queue depth, test mode.
- Calibration: quick two-point flow, stability display, result save.
- History/insights: multi-device filters and exclusion of `isTest` readings.
- Notifications: permission request and low/high alert throttling.

CI rules:
- CI must fail when tests or builds fail.
- Do not leave `|| true` on important test/build steps.
- Keep GitHub Actions major versions current.

### Common Pitfalls To Avoid

- Creating a second source-of-truth context document. This file is canonical; merge useful guidance here.
- Trusting stale docs over code. Inspect implementation when docs and code disagree.
- Accepting Claude/Codex-generated protocol tables without checking actual UUIDs/endpoints.
- Leaving both original and `_Refactored` Swift files active when they define duplicate types.
- Deleting SwiftData stores to recover from schema errors in production.
- Treating Standard SQS as exactly-once.
- Acknowledging device queue entries before durable local/cloud persistence.
- Using GPIO3/GPIO14 for ordinary I/O on the XIAO ESP32-C6.
- Adding Phase 2 motor work before the phase gate is intentionally opened.
- Merging to `main` by habit.

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

## Final AI Instruction

**This file (PROJECT_CONTEXT.md) is the CANONICAL source of truth for all AI sessions.**

It combines strategic decisions (P0-P3 priorities, product identity, phase gates) with technical standards (architecture patterns, code quality metrics, industry validation). Consult it FIRST for any Water Monitor work.

When in doubt, optimize for:

1. No data loss.
2. Hardware safety.
3. Clear phase boundaries.
4. One canonical product identity (Water Monitor).
5. Source-backed platform decisions (see External Standards section).
6. Small, testable changes.
7. Updated architecture docs in the same change.
8. Single Responsibility in all code (firmware, iOS, cloud).
9. Complete documentation (50-70% ratio for firmware, 40-50% for services).
