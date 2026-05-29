# Water Monitor — Implementation TODO List

## Phase 2A: Cloud Sync Infrastructure (Priority 1)

### 2A.1: Cloud Backend Setup

#### Choose Cloud Provider
- [ ] Compare Firebase vs AWS vs Custom (see decision matrix in REQUIREMENTS.md)
- [ ] Set up project/account
- [ ] Configure authentication (OAuth 2.0)
- [ ] Set up monitoring/logging

#### Database Schema (Cloud)
- [ ] Create users table
- [ ] Create profiles table
- [ ] Create devices table
- [ ] Create readings table (with UNIQUE constraint for dedup)
- [ ] Create sync_queue table
- [ ] Create anomalies table
- [ ] Create insights table
- [ ] Add indices for performance
- [ ] Write migrations script
- [ ] Test schema with sample data

#### API Endpoints (REST/GraphQL)
- [ ] `POST /api/readings` — Batch ingest readings from app
  - Input: `[{device_id, timestamp, distance_cm, level_pct}]`
  - Output: `{status, synced_ids, conflicts}`
  - Handle deduplication, return last 10 readings
  
- [ ] `GET /api/readings` — Fetch readings for app
  - Query: `?device_id=X&since=UNIX_TS&limit=100`
  - Output: `[{id, device_id, timestamp, distance_cm, level_pct, is_anomaly}]`
  
- [ ] `POST /api/profiles` — Create profile
- [ ] `GET /api/profiles/{id}` — Fetch profile with devices
- [ ] `PUT /api/profiles/{id}` — Update profile config
- [ ] `POST /api/profiles/{id}/devices` — Add device to profile
- [ ] `PUT /api/profiles/{id}/devices/{device_id}` — Update device config
  
- [ ] `GET /api/sync-status` — Check pending syncs
- [ ] `POST /api/sync-queue/ack` — Mark queue item as synced

#### MQTT Setup (Optional but Recommended)
- [ ] Set up MQTT broker (AWS IoT Core or custom)
- [ ] Configure topics:
  - `tank/{device_id}/reading/live` — Device publishes live readings
  - `tank/{device_id}/config/request` — App requests config
  - `tank/{device_id}/config/response` — Device responds
  
- [ ] Implement QoS 2 (exactly-once)
- [ ] Test message retention for offline clients
- [ ] Write bridge to sync MQTT → Cloud DB

### 2A.2: Device (ESP32) Firmware Updates

#### Queue Management Enhancements
- [ ] Increase queue capacity from 2000 to 5000 readings
  - Calculate: 5000 × 16 bytes = 80KB (fits in LittleFS)
  
- [ ] Add queue metadata:
  - `queue_version` (for compatibility)
  - `last_synced_ts` (track progress)
  - `sync_status` per entry (pending/acked/failed)
  
- [ ] Implement queue persistence across reboots
  - Test: Reboot → queue survives
  
- [ ] Add acknowledgment protocol:
  - When app asks for queue, device sends: `{readings: [...], last_ack_idx: N}`
  - App confirms: `{ack_idx: N}` (only ack if sync to cloud succeeded)
  - Device removes acked items from queue

#### Device API Enhancements
- [ ] New REST endpoint: `GET /api/queue`
  - Response: `{count, size_bytes, readings: [{ts, distance_cm, ...}]}`
  
- [ ] New REST endpoint: `GET /api/queue/ack`
  - Query: `?up_to_idx=N` (acknowledge up to index N)
  
- [ ] New BLE characteristic: AA07 for queue metadata
  - Publish: `{queue_count, last_sync_ts, app_connected_status}`
  
- [ ] Firmware version API: `GET /api/version`
  - Response: `{fw: "1.1.0", build_date: "2026-05-29"}`

#### Device-to-App ACK Flow
- [ ] Device broadcasts queue metadata every 5s (via BLE AA07)
- [ ] When app syncs to cloud, app sends ACK back to device
- [ ] Device removes synced items from queue
- [ ] Device logs: `[Queue] Synced 42 readings, remaining: 158`

### 2A.3: iOS App Queue Layer

#### SyncQueue Model (SwiftData)
```swift
@Model final class SyncQueueItem {
    var id: UUID = UUID()
    var deviceID: String
    var readings: [DeviceReadingDTO] // Codable struct, not DeviceReading model
    var status: String = "pending" // pending, synced, failed
    var attempts: Int = 0
    var lastAttemptAt: Date?
    var syncedAt: Date?
    var createdAt: Date = Date()
}
```

- [ ] Create SyncQueue model in SwiftData
- [ ] Add migration if needed (schema versioning)
- [ ] Write batch insert logic: `syncQueue.append(items)`
- [ ] Write query logic: `fetch all where status == "pending"`

#### Offline Detection & Queueing
- [ ] In ConnectionManager, detect when app goes offline:
  - Monitor: Internet connectivity (Network framework)
  - Monitor: Cloud API reachability
  
- [ ] When offline detected:
  - Set `ConnectionManager.isCloudOnline = false`
  - New readings go to SyncQueue (don't attempt cloud push)
  - UI shows: "Cloud sync offline, queuing locally"
  
- [ ] When online detected:
  - Trigger `syncQueueToCloud()` immediately
  - Retry pending items from SyncQueue

#### Cloud Sync Logic
- [ ] Function: `syncReadingsToCloud()`
  ```swift
  - Get all pending SyncQueue items
  - Batch: Send 100 readings per request
  - POST /api/readings with array
  - On success: Mark as "synced", record syncedAt
  - On failure: Increment attempts, backoff retry
  - Update UI with sync progress
  ```
  
- [ ] Retry strategy:
  - Attempt 1: Immediate (if online)
  - Attempt 2: 5s delay
  - Attempt 3: 15s delay
  - Attempt 4: 60s delay
  - Attempt 5+: Every 5 min (up to 24h)
  
- [ ] Store in SyncQueue:
  ```swift
  struct DeviceReadingDTO: Codable {
    var deviceID: String
    var timestamp: Int // Unix seconds
    var distanceCM: Double
    var levelPct: Int
    var sensorOk: Bool
    var isTest: Bool
  }
  ```
  
  Note: Use DTO (not DeviceReading model) so we can store in JSON queue

#### New UI: Sync Status
- [ ] Settings tab: Show "Cloud Sync Status"
  - "Online — Syncing" (green)
  - "Offline — X readings in queue" (yellow)
  - "Sync failed — Retrying..." (red)
  
- [ ] Add manual "Force Sync" button for testing
- [ ] Show: "Last synced: 2 minutes ago"
- [ ] Show: "Pending readings: 42"

### 2A.4: Integration Testing

#### Test Scenarios
- [ ] **Scenario 1: Normal online sync**
  - Device reads sensor → App receives (WebSocket) → App syncs to cloud (REST)
  - Verify: No data loss, no duplicates
  
- [ ] **Scenario 2: App loses internet**
  - Turn off WiFi on phone
  - Device still sending readings
  - App queues readings in SyncQueue
  - Turn WiFi back on
  - App auto-syncs queue to cloud
  - Verify: All readings arrived, no duplicates
  
- [ ] **Scenario 3: App offline for 24h**
  - Device keeps queuing in NVS (5000 capacity)
  - App queues in SwiftData (unlimited)
  - When app online: Pull device queue, merge with app queue, sync to cloud
  - Verify: ~4000 device readings + ~500 app readings = all synced
  
- [ ] **Scenario 4: Multiple apps for same device**
  - Start App A, connect device
  - App A syncs reading to cloud
  - Open App B (different phone, same user)
  - App B fetches readings from cloud
  - Verify: Both apps show same data
  
- [ ] **Scenario 5: Device reconnects after reboot**
  - Device offline for 5 min (simulated by unplugging)
  - Device queues readings in NVS
  - Reboot device (queue survives)
  - Device comes online
  - App pulls queue and syncs
  - Verify: No readings lost

#### Stress Testing
- [ ] **Test:** Device sends 100 readings/sec for 10 min
  - Verify: Queue doesn't overflow
  - Verify: No data loss
  
- [ ] **Test:** App syncs 50K readings to cloud
  - Verify: Batching works (100 per request)
  - Verify: Deduplication works
  - Verify: No timeouts

### 2A.5: Documentation

- [ ] API docs: Endpoint spec + examples
- [ ] Firmware: Queue format + wire protocol
- [ ] App: How to handle offline mode
- [ ] Operations: Backup queue, recover from corruption

---

## Phase 2B: AI Data Validation (Priority 2)

### 2B.1: Device-Side Validation (ESP32)

#### Motor Specs Configuration
- [ ] Add to NVS config:
  ```json
  {
    "motor_power_w": 750,      // Watts
    "motor_efficiency": 0.85,   // 0-1
    "tank_volume_l": 1000,
    "tank_empty_cm": 60,
    "tank_full_cm": 15
  }
  ```

#### Rate-of-Change Validator
- [ ] Function: `bool isValidFillRate(float deltaPercent, uint32_t deltaSeconds)`
  ```cpp
  float maxChangePercent = (motor_power_w * efficiency / 3600) 
                         * (tank_volume_l / 100) 
                         * (deltaSeconds / 60.0);
  return fabsf(deltaPercent) <= maxChangePercent * 1.5; // 1.5x safety margin
  ```
  
- [ ] Call during sensor reading validation
- [ ] Log if rate exceeds: `[Validate] Rate exceeded: 45%/min > 10%/min allowed`

#### Bounds Checking
- [ ] Reject if reading outside [tank_full_cm - 2, tank_empty_cm + 2]
- [ ] Reject if level_pct outside [0, 100]

#### Time Gap Detection
- [ ] If gap > 1 hour since last reading: Don't flag as anomaly (expected overnight)
- [ ] If gap < 5 min but reading differs >5%: Investigate
- [ ] Log: `[Validate] Unexpected jump: 45% → 85% in 3 min`

#### Sensor Quality Monitoring
- [ ] Track pulseIn() success rate per 100 reads
  - If <90% success: Flag sensor as degrading
  - Log: `[Sensor] Quality: 87% (was 95% yesterday)`
  
- [ ] Send sensor quality to app via AA02 characteristic

### 2B.2: Cloud-Side ML (Optional Phase 2B)

#### Historical Pattern Analyzer
- [ ] Collect 2 weeks of user readings
- [ ] Learn patterns:
  - Peak usage hours
  - Typical fill volumes
  - Typical drain rates
  
- [ ] Flag anomalies:
  - "Filling at 2 AM (unusual, normally 7 AM)"
  - "Drain rate 2x faster than normal"

#### Anomaly Detection API
- [ ] Cloud function: `validateReading(device_id, reading)`
  - Input: `{timestamp, distance_cm, level_pct}`
  - Output: `{is_anomaly, severity, reason, suggestion}`
  
- [ ] Return to app: Mark anomalous readings, don't use in averages

#### Monthly Model Retraining
- [ ] Cron job: Last day of month
  - Fetch readings for all users
  - Retrain anomaly detection model
  - Push updated thresholds to all devices

### 2B.3: App-Side Insights Enhancement

#### Leak Detection
- [ ] In InsightsEngine, calculate:
  ```swift
  // Drain rate when pump is OFF
  if !pumpRunning && levelDropping {
    let drainRateL_per_hour = computeDrainRate(readings)
    if drainRateL_per_hour > 0.5 { // Configurable threshold
      insights.alerts.append("Possible leak: 0.5 L/h drain")
    }
  }
  ```

#### Motor Efficiency Tracking
- [ ] Track fill time per 50% (e.g., 30% → 80%)
- [ ] Compare to baseline: `fillTime > baseline * 1.2 → Efficiency degrading`
- [ ] Alert: "Motor efficiency down 20% — may need service"

#### Sensor Drift Detection
- [ ] After calibration, track if readings consistently off
- [ ] Alert: "Readings 5% lower than expected for this water level"

#### Predictive Fills
- [ ] Analyze: "How often does tank fill to >90%?"
- [ ] Estimate: Next fill in ~2.3 days
- [ ] Alert: "Tank likely to need refill in 48 hours"

---

## Phase 2C: Multi-Device Profile Support (Priority 3)

### 2C.1: Cloud Profile Schema

#### Profile CRUD
- [ ] Create profile on first login
  - Auto-create profile: `{name: "My Home", user_id: X, devices: []}`
  
- [ ] GET profile with full device list + latest readings
- [ ] PATCH profile (name, settings)
- [ ] Share profile with other accounts (future: family features)

#### Device-Profile Binding
- [ ] When app connects to device:
  - Ask device: `GET /api/device-info` → device_id
  - App: Create entry in profile.devices
  - Cloud: Link device_id → profile_id
  
- [ ] Device config persists in profile:
  ```json
  {
    "tank_config": {
      "empty_cm": 60,
      "full_cm": 15,
      "volume_l": 1000
    },
    "alert_thresholds": {
      "low_pct": 20,
      "high_pct": 90
    },
    "calibration": {
      "last_calibrated": "2026-05-29T10:30:00Z",
      "method": "two-point",
      "points": [{pct: 5, cm: 58}, {pct: 95, cm: 18}]
    }
  }
  ```

### 2C.2: Cross-App Profile Sync

#### Scenario: Config Change on Phone A
1. User changes low_pct alert from 20% → 25% on Phone A
2. Phone A PATCH /api/profiles/{id}/devices/{device_id} with new threshold
3. Cloud updates device config
4. Phone B subscribes to profile changes (via MQTT or polling)
5. Phone B fetches updated config, updates local view
6. Device (ESP32) fetches from /api/config on next BLE/WiFi connect, applies new threshold

#### Conflict Resolution
- [ ] If Phone A and Phone B edit simultaneously:
  - Cloud uses `version` field (increment on each change)
  - Loser: Fetch latest from cloud, re-apply edit
  - User: Notified of conflict, shown merged config
  
- [ ] UI: "Config conflict — your change + other phone's change merged"
  - Show before/after
  - Allow user to resolve manually

### 2C.3: Historical Data Download

#### On App Launch
- [ ] Check: Is profile.devices populated?
  - YES → App has seen this device, skip
  - NO → First time, download from cloud
  
- [ ] Fetch from cloud: `GET /api/readings?device_id=X&limit=1000`
  - Get last 1000 readings (3-4 weeks of data)
  - Import into SwiftData
  
- [ ] Show: "Syncing history (15%)" during import
- [ ] After import, subscribe to live readings (MQTT or WebSocket)

#### Staying Up-to-Date
- [ ] Poll every 5 min: `GET /api/readings?device_id=X&since=LAST_FETCH_TS`
- [ ] Or MQTT subscription: `tank/{device_id}/reading/live`
- [ ] Merge into local DB

---

## Phase 3: Testing & Validation (Throughout)

### Unit Tests
- [ ] Queue insertion/deletion (device + app)
- [ ] Sync batching logic
- [ ] Anomaly detection thresholds
- [ ] Deduplication (same reading twice)

### Integration Tests
- [ ] Device → App (BLE/WiFi)
- [ ] App → Cloud (API/MQTT)
- [ ] Cloud → App (polling/subscription)
- [ ] Multi-device sync scenarios (from 2A.4)

### Load Tests
- [ ] 10K readings per second ingestion
- [ ] 1M historical readings per user
- [ ] 10K concurrent app connections

### UAT Checklist
- [ ] User can see readings on 2 phones (same profile)
- [ ] No data loss after 24h offline
- [ ] Anomalies flagged correctly
- [ ] Leak alerts work
- [ ] Config changes propagate across devices

---

## Phase 4: Deployment & Operations

### Staging
- [ ] Set up staging cloud environment
- [ ] Staging device (test sensor)
- [ ] Staging app (TestFlight)
- [ ] Run full integration test suite

### Production Rollout
- [ ] Firmware: v1.1.0 (queue + API enhancements)
- [ ] App: v2.0.0 (cloud sync + queue)
- [ ] Backend: v1.0.0 (cloud API + dedup)
- [ ] Feature flag: Cloud sync OFF by default, enable for beta users

### Monitoring
- [ ] Cloud: Monitor readings ingest rate, errors
- [ ] App: Monitor sync failures, queue size
- [ ] Device: Monitor queue overflow, reconnect frequency

### Support
- [ ] Help doc: "Data synced to cloud — here's how"
- [ ] FAQ: "Why do I see different data on my 2 phones?"
- [ ] Troubleshooting: Clear queue, force sync, reset app

---

## Summary: Effort Estimate

| Phase | Duration | Engineers | Notes |
|-------|----------|-----------|-------|
| 2A (Cloud sync) | 6-8 weeks | 2 | Backend + iOS |
| 2B (AI validation) | 4-6 weeks | 1 | Device + Cloud ML |
| 2C (Multi-device) | 3-4 weeks | 1 | Cloud + App UI |
| 3 (Testing) | 2-3 weeks | 1 | Throughout |
| 4 (Deployment) | 1-2 weeks | 1 | Rollout + monitoring |
| **Total** | **4-5 months** | **2-3** | **Full stack** |

---

## Next Immediate Actions (Week 1)

- [ ] Decision: Firebase vs AWS vs Custom? (affects all tasks)
- [ ] Setup cloud account + initial schema
- [ ] Assign engineers to Phase 2A backend
- [ ] Start device queue refactoring
- [ ] Create cloud API spec document

