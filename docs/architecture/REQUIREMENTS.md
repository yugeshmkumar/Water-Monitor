# Water Monitor System — Complete Architecture & Requirements v2.0

## Executive Summary

Phase 2 redesign to add cloud synchronization, multi-device profile support, AI-powered data validation, and zero-data-loss offline-first architecture.

**Key Principles:**
- Data loss is unacceptable—queue at multiple layers
- No stale data across devices—eventual consistency
- AI validates readings before storage
- Cloud-agnostic (API + MQTT options)

---

## Part 1: AI/ML Data Validation Engine

### 1.1 Anomaly Detection Requirements

**Problem:** Raw sensor readings contain:
- Hardware glitches (sudden jumps: 37% → 100% in 3 sec)
- Spurious readings (ice on sensor, air bubbles)
- Calibration drift over time

**Solution:** Multi-layer validation

#### Layer 1: Physics-Based Rules
- **Rate-of-change limit:** Tank fill/drain rate (L/min) based on motor specs
  - Input: motor power (W), pump efficiency (%), tank capacity (L)
  - Output: max valid change per 30s = `(motor_watts * efficiency / 3600) * tank_capacity / 100`
  - Rule: Reject if Δ% exceeds calculated max
  
- **Tank bounds:** Reading must be 0–100% (or calibrated min/max)
  
- **Sensor stability:** Distance must stay within [tank_full_cm - tolerance, tank_empty_cm + tolerance]

#### Layer 2: Statistical ML Validator (Local to Device)
- **Dual-criterion outlier detection** — Welford running mean (z-score) + linear trend prediction (z-score)
- **Online learning** — warmup phase (30 readings), adaptive statistics with forgetting factor
- **Mini-confirmation** — 2-reading agreement within tolerance threshold before emission
- **Implementation:** Replaces previous Kalman filter; ~200 bytes of state, no pre-trained models needed

#### Layer 3: Historical Pattern Recognition (Device + Cloud AI)
- **Detect fill/drain cycles:** Identify when user is intentionally filling/draining
- **Expected patterns:** 
  - Morning: typically fills (e.g., 6–8 AM)
  - Evening: typically drains (e.g., 6–10 PM)
  - Anomaly: Fill at 2 AM suggests malfunction or manual intervention
  
- **Leak detection:** Continuous slow drain when no pump running = leak alert

#### Layer 4: Cloud ML (Optional—Phase 2B)
- Train model on historical valid readings per user
- Detect out-of-distribution readings
- Learn user's unique tank behavior patterns

### 1.2 Insights Engine Requirements

**Current state:** InsightsEngine.swift computes basic stats

**Enhancements needed:**

1. **Predictive Insights**
   - Time to empty (already done)
   - Time to next fill event (based on historical patterns)
   - Expected fill volume (L) at next cycle
   - Anomaly alerts: "Tank drained 15% overnight (possible leak)"

2. **Health Warnings**
   - Motor efficiency degradation (fill time increasing)
   - Sensor drift (readings don't match expected range for volume)
   - WiFi/BLE reliability score per device

3. **Usage Patterns**
   - Daily average consumption (L)
   - Peak usage hours
   - Week-on-week trend
   - Consumption per person (if household size known)

4. **Maintenance Alerts**
   - "Pump hasn't been serviced in X months"
   - "Sensor error rate >5% this week"
   - "Battery voltage low" (if applicable)

---

## Part 2: Cloud Sync Architecture

### 2.1 Data Flow (Happy Path)

```
Device (ESP32)
    ↓ (BLE/WiFi)
App (iOS)
    ├→ [Queue: unsync data]
    ├→ [Local DB: SwiftData]
    ↓ (When online)
Cloud (Firebase/Custom API)
    ↓ (MQTT/REST)
All other apps (same user) ← Real-time update
```

### 2.2 Layered Queue Strategy

#### Queue Layer 1: Device (ESP32)
- **When:** App loses WiFi connection
- **What:** Store readings in `queue_store` (already ~2000 capacity)
- **Behavior:** Keep queue even if device reboots
- **Flush:** When app reconnects AND is online

#### Queue Layer 2: App (iOS)
- **When:** App goes offline (WiFi + cellular down)
- **What:** Store readings in `DeviceReading` table + separate `SyncQueue`
- **Behavior:** 
  - Batch readings every 30s (or when queue reaches 100 items)
  - If sync fails, retry exponentially (2s → 5s → 10s → 30s)
  - Never drop data
- **Flush:** When connectivity restored + cloud reachable

#### Queue Layer 3: Cloud
- **When:** Multiple apps try to sync for same device
- **What:** Deduplicate by reading `(device_id, timestamp, distance_cm)`
- **Behavior:** Last write wins for same timestamp
- **Retention:** Keep 1 year (configurable per plan)

### 2.3 Sync Modes

#### Mode 1: App Online & Cloud Reachable
```
Device reading → App (real-time via WebSocket) → Cloud (via API/MQTT)
                                              ↓
                                     All other apps (via subscription)
```
- Latency: <2 seconds end-to-end
- Guarantee: Exactly-once (deduplication on cloud)

#### Mode 2: App Online, Device Offline
```
App polls device status every 30s
App shows: "Device last seen 5 minutes ago"
App doesn't push stale readings from queue
```

#### Mode 3: App Offline, Device Online
```
Device queues readings in `queue_store`
When app comes back online:
  - App asks device: "Readings since timestamp X?"
  - Device streams queued + live readings
  - App syncs with cloud if online
```

#### Mode 4: Both Offline
```
App: Queue readings locally
Device: Queue readings in NVS
Neither pushes anything
When app online → pulls from device queue + syncs to cloud
```

### 2.4 Multi-Device Profile Sync

**Scenario:** User has 3 tanks, 2 phones, wants profile/settings everywhere

#### Profile Schema
```
Profile {
  id (UUID),
  user_id,
  name: "Home Water System",
  created_at,
  updated_at,
  devices: [
    {
      device_id: "Tank-1",
      tank_config: { empty_cm, full_cm, volume_l, ... },
      alert_thresholds: { low_pct, high_pct },
      last_sync: timestamp,
      last_reading: { level_pct, distance_cm, ts },
    }
  ],
  sync_metadata: {
    version (for conflict resolution),
    last_modified_by_app_id,
    last_modified_at,
  }
}
```

#### Sync Rules
1. **Initial setup:** App downloads profile from cloud on first launch
2. **Reading sync:** Device → App → Cloud (always)
3. **Config changes:** App → Cloud → Other apps (polling or push)
4. **Conflict resolution:** Last write wins (with user notification)
5. **Offline profile edits:** App queues config change, syncs when online

---

## Part 3: Zero Data Loss Guarantees

### 3.1 Deduplication Strategy

**Problem:** Device queued reading, app synced it, app offline, device sends again

**Solution:** Idempotent keys

```
Reading {
  id: hash(device_id + timestamp + distance_cm),
  device_id,
  timestamp (server time when received),
  distance_cm,
  level_pct,
  sensor_ok,
  created_at (device boot time),
  synced_at (when pushed to cloud),
  is_test (exclude from history),
}
```

**Dedup logic:**
- Cloud: `UNIQUE (device_id, created_at, distance_cm)` constraint
- App: Track synced reading IDs, don't re-push same ID
- Device: UUID for each reading, don't re-queue if already acked

### 3.2 Acknowledgment Protocol

```
Device sends reading
  ↓ (via BLE/WiFi to App)
App receives & stores locally
  ↓ (ACK back to Device)
Device marks as "synced" in queue
  ↓ (App goes online)
App batch-pushes to Cloud with timestamps
  ↓ (Cloud returns ACK + latest version)
App updates SwiftData with sync status
```

### 3.3 Retry Strategy

**For app → cloud sync:**
```
Attempt 1: Immediate (if online detected)
Attempt 2: After 5s (exponential backoff)
Attempt 3: After 15s
Attempt 4: After 60s
Attempt 5+: Every 5 minutes (until success or 24h)
```

**Persistence:**
- Queue stays in app DB even after app restart
- Background task every 5 min checks if online
- User notification: "X readings pending sync"

---

## Part 4: Industry Standards & Reference

### 4.1 Cloud Sync Patterns (Adopted)

**MQTT (Recommended for IoT)**
- Pub/sub: Device publishes to `tank/{device_id}/reading`
- App subscribes to `tank/{device_id}/reading` + `tank/{device_id}/config`
- QoS 2 (exactly-once): Broker guarantees delivery
- Persistent sessions: Broker queues messages while app offline

**REST API (Alternative)**
- Batch push: `POST /api/readings` with array of {timestamp, distance_cm}
- Batch pull: `GET /api/readings?since=UNIX_TS&device_id=X`
- Conflict resolution: Server compares versions, returns latest

### 4.2 Similar Apps & Their Approach

| App | Cloud | Sync | Multi-Device | Queue | AI Validation |
|-----|-------|------|--------------|-------|---------------|
| **Home Assistant** | MQTT/REST | Event-driven | ✅ (profiles) | ✅ (DB) | ✅ (ML) |
| **Aqua (smart water)** | Proprietary | Real-time push | ✅ | ✅ | ✅ (anomaly) |
| **SmartThings** | MQTT/REST | Event + polling | ✅ | ✅ | ✓ (basic) |
| **Wyze** | REST API | Real-time | ✅ | ✅ | ✓ (basic) |
| **ESPHome** | MQTT | Publish/subscribe | ✅ | ✅ (queue) | ✓ (filters) |

**Key takeaways:**
- **MQTT** is standard for IoT (better than REST for real-time)
- **Event-driven** syncs faster than polling
- **Queue at app layer** is essential
- **Local validation** (Kalman/filters) before cloud
- **Cloud dedup** is critical for multi-device

### 4.3 Database Schema Reference (Cloud)

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE,
  created_at TIMESTAMP,
  subscription_plan VARCHAR,
);

-- Profiles (tap water systems)
CREATE TABLE profiles (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  name VARCHAR,
  location VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  version INT (for conflict detection),
  last_modified_by_app_id VARCHAR,
);

-- Devices (tanks, pumps, motors)
CREATE TABLE devices (
  id UUID PRIMARY KEY,
  profile_id UUID REFERENCES profiles(id),
  device_id VARCHAR UNIQUE, -- "Tank-1"
  type VARCHAR, -- "tank", "motor", "sensor"
  config JSONB, -- {empty_cm, full_cm, volume_l, motor_power_w, ...}
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
);

-- Readings (sensor data)
CREATE TABLE readings (
  id UUID PRIMARY KEY,
  device_id VARCHAR REFERENCES devices(device_id),
  timestamp BIGINT, -- Unix seconds (from device boot)
  distance_cm FLOAT,
  level_pct INT,
  sensor_ok BOOLEAN,
  is_test BOOLEAN DEFAULT false,
  is_anomaly BOOLEAN DEFAULT false, -- Flagged by AI
  anomaly_reason VARCHAR,
  created_at TIMESTAMP (server time),
  updated_at TIMESTAMP,
  synced_from_app_id VARCHAR,
  UNIQUE(device_id, timestamp, distance_cm), -- Dedup key
  INDEX(device_id, created_at DESC),
  INDEX(created_at DESC),
);

-- Sync Queue (pending reads from app)
CREATE TABLE sync_queue (
  id UUID PRIMARY KEY,
  app_id VARCHAR,
  device_id VARCHAR,
  readings_json JSONB,
  status VARCHAR, -- "pending", "synced", "failed"
  attempts INT DEFAULT 0,
  created_at TIMESTAMP,
  synced_at TIMESTAMP,
);

-- Anomalies (detected issues)
CREATE TABLE anomalies (
  id UUID PRIMARY KEY,
  device_id VARCHAR REFERENCES devices(device_id),
  type VARCHAR, -- "leak", "motor_inefficiency", "sensor_drift"
  severity VARCHAR, -- "info", "warning", "critical"
  description TEXT,
  data JSONB,
  created_at TIMESTAMP,
  resolved_at TIMESTAMP,
);

-- Insights (daily/hourly aggregates)
CREATE TABLE insights (
  id UUID PRIMARY KEY,
  device_id VARCHAR REFERENCES devices(device_id),
  period VARCHAR, -- "hourly", "daily"
  period_start TIMESTAMP,
  period_end TIMESTAMP,
  avg_level_pct FLOAT,
  min_level_pct INT,
  max_level_pct INT,
  fill_count INT,
  drain_count INT,
  total_usage_l FLOAT,
  data JSONB, -- {peak_hour, patterns, ...}
  created_at TIMESTAMP,
);
```

---

## Part 5: Technology Stack Recommendations

### Backend (Cloud)

**Option A: Firebase (Easiest)**
- Firestore for readings + profiles
- Realtime Database for live sync
- Cloud Functions for anomaly detection
- Cloud Pub/Sub for MQTT bridge

**Option B: Custom (AWS + Node.js) (Most Control)**
- DynamoDB for readings
- SQS for queue
- Lambda for sync logic
- API Gateway + WebSocket for real-time
- S3 for historical exports

**Option C: InfluxDB + Node.js (IoT-Optimized)**
- InfluxDB for time-series readings
- PostgreSQL for profiles/metadata
- Node.js Express for API
- Redis for queue + dedup cache

### AI/ML

**On-Device (ESP32):**
- **TensorFlow Lite Micro** for anomaly detection (lightweight)
- ~50KB model size for rate-of-change validation
- Pre-compute thresholds from calibration

**Cloud (Optional Phase 2B):**
- **TensorFlow/PyTorch** for pattern learning
- Train on aggregated user data
- Update app with new anomaly rules monthly

---

## Part 6: Implementation Strategy (Phased)

### Phase 2A: Cloud Sync Infrastructure (6-8 weeks)
1. Backend: Firebase setup + Firestore schema
2. App: Queue layer + sync logic
3. Device: ACK protocol + queue management
4. Testing: Multi-device sync scenarios

### Phase 2B: AI Validation (4-6 weeks)
1. Device: TensorFlow Lite Micro model
2. Cloud: Historical pattern analyzer
3. Insights: Enhanced predictions
4. Testing: Anomaly detection accuracy

### Phase 2C: Multi-Device Profile (3-4 weeks)
1. Profile CRUD on cloud
2. App: Profile management UI
3. Cross-app sync logic
4. Conflict resolution UI

### Phase 3: Advanced Features (Future)
1. Energy consumption tracking (motor power draw)
2. Water quality monitoring (pH, turbidity)
3. Motor health diagnostics
4. Predictive maintenance (ML-based)

---

## Part 7: Non-Functional Requirements

| Requirement | Target | Notes |
|---|---|---|
| **Data loss** | 0 | Queue at device, app, cloud |
| **Read latency** | <2s | Device → App → Cloud |
| **Sync latency** | <5s | Cloud → All apps |
| **Offline capacity** | 1000+ readings | Device queue + app DB |
| **Historical retention** | 1 year | Cloud storage |
| **Availability** | 99.9% | 3 replicants, failover |
| **API throughput** | 10K reads/s | Per user |
| **Model update frequency** | Monthly | Retrain on cloud |

---

## Part 8: Security & Privacy

1. **Authentication:** OAuth 2.0 (Google/Apple ID)
2. **Encryption:** TLS 1.3 (transport), AES-256 (at-rest for readings)
3. **API Keys:** Device gets scoped key (read/write only to own device)
4. **Queue Security:** Encrypt queue file on device NVS
5. **Cloud:** Per-user data isolation (no cross-account access)

---

## Next Steps

1. ✅ Finalize requirements (this document)
2. 📋 Create detailed TODO list (separate file)
3. 🏗️ Design database schema (SQL migrations)
4. 🔌 Choose cloud provider (Firebase vs Custom)
5. 💻 Implement Phase 2A: Cloud sync backend
6. 📱 Implement Phase 2A: App queue layer
7. 🧪 Integration testing (multi-device scenarios)

