# Phase 3: iOS Service Refactoring Analysis

**Status:** Identified 4 major services with Single Responsibility Principle violations  
**Target:** Reduce responsibilities, improve testability, enable code reuse

---

## Issue iOS-1: ConnectionManager — Over 10 Responsibilities

**Current Size:** 366 lines, 11 public methods  
**Root Cause:** Acts as both transport coordinator AND state manager

### Current Responsibilities:

1. **Transport Selection** — Choose WiFi vs BLE based on availability
   - `upgradeToWiFi()` — Switch from BLE to WiFi
   - `startBLEScan()` — Initiate BLE scan
   - Property: `var transport: Transport`

2. **State Management** — Hold device status across transports
   - `status` property (WiFi or BLE reading)
   - `config` property (device configuration)
   - `lastValidStatus` (fallback for invalid readings)
   - Properties: `testMode`, `isDrainingQueue`, `connectedWiFiHost`

3. **Connection Lifecycle** — Connect to new devices
   - `tryWiFi(host:)` — WiFi connection attempt
   - `connectToDevice(_:)` — Full connection handshake
   - `testDeviceConnection()` — Health check

4. **Configuration Sync** — Push updates to device
   - `writeConfig(_:)` — Update device configuration
   - `setTestMode(_:)` — Toggle test mode
   - `sendCommand(_:)` — Send arbitrary commands

5. **Queue Management** — Fetch readings from device buffer
   - `drainQueue()` — Async loop to fetch pending readings
   - `flushQueueViaREST()` — Trigger queue flush

6. **Callback Coordination** — Manage multiple closures
   - `onDeviceActivity` — New reading arrives
   - `onUpdateDevice` — Configuration received
   - `onDeviceIPUpdated` — IP changes
   - Wires BLE/WiFi callbacks into DataCache

### Refactoring Strategy:

**Extract TransportManager:**
- Owns `ble` and `wifi` services
- Selects active transport based on availability
- Exposes: `upgradeToWiFi()`, `startBLEScan()`, `transport` property

**Keep in ConnectionManager:**
- Device state snapshots: `status`, `config`, `displayStatus`
- Callback forwarding: `onDeviceActivity`, etc.
- High-level device operations: `connectToDevice()`, `testDeviceConnection()`

**Extract QueueDrainer:**
- Owns queue draining logic
- Coordinates REST flush with timestamp reconstruction
- Exposes: `drainQueue()`, `isDrainingQueue`

---

## Issue iOS-2: BLEService — Mixed Concerns (Scanning + Notifications)

**Current Size:** 231 lines, 16 methods  
**Root Cause:** Scanning, connection, and notification handling in one class

### Current Responsibilities:

1. **BLE Scanning** — Find nearby devices
   - `startScan(timeout:)` — Begin scan
   - `stopScan()` — Stop scan
   - Delegate: `centralManagerDidUpdateState()`

2. **Connection Lifecycle** — Connect/disconnect from device
   - `connect(to:)` — Initiate connection
   - `disconnect()` — Drop connection
   - Delegate: `centralManager(_:didConnect:)`

3. **Service Discovery** — Find GATT services
   - Delegate: `peripheral(_:didDiscoverServices:)`
   - Discover characteristics per service

4. **Notification Handlers** — Respond to incoming data
   - `onLiveReading` — New sensor reading
   - `onConfigReceived` — Configuration pushed
   - Multiple `didUpdateValueFor` callbacks

### Refactoring Strategy:

**Extract BLENotificationHandler:**
- Subscribes to characteristic changes
- Decodes incoming JSON
- Calls `onLiveReading` / `onConfigReceived` callbacks
- Exposes: Simple interface for registering callbacks

**Keep in BLEService:**
- Scanning and discovery
- Connection/disconnection
- GATT service management

---

## Issue iOS-3: WiFiService — Protocol Mixing (REST + WebSocket)

**Current Size:** 202 lines, 14 methods  
**Root Cause:** REST calls and WebSocket streaming in single service

### Current Responsibilities:

1. **REST Client** — Fetch status and config via HTTP
   - `fetchStatus()` — GET /api/status
   - `fetchConfig()` — GET /api/config
   - `ackQueue(_:)` — POST /api/queue/ack
   - Property: `commandResult`

2. **WebSocket Streaming** — Real-time sensor data
   - `startWebSocket()` — Open connection
   - `closeWebSocket()` — Close connection
   - Delegate: `websocketDidReceiveMessage()`
   - Callback: `onLiveReading`

3. **Ping/Keepalive** — Detect stale connections
   - `pingTimer` — Periodic ping
   - Timeout logic if no pong

### Refactoring Strategy:

**Extract RestClient:**
- Owns URLSession and REST endpoints
- Exposes: `fetchStatus()`, `fetchConfig()`, `ackQueue()`, `sendCommand()`

**Extract WebSocketManager:**
- Owns WebSocket connection
- Decodes incoming JSON messages
- Calls `onLiveReading` callback
- Handles ping/keepalive

**Keep in WiFiService:**
- High-level orchestration: `connect(host:)`, `disconnect()`
- State: `isConnected`, `liveStatus`, `deviceConfig`

---

## Issue iOS-4: DataCache — Persistence + Logic Mixed

**Current Size:** 154 lines, 5 methods  
**Root Cause:** Import logic, pruning, and deduplication tangled with SwiftData

### Current Responsibilities:

1. **Persistence** — Save/fetch readings from SwiftData
   - `save(_:)` — Store a live reading
   - `readings(since:nodeID:)` — Fetch history
   - Properties: `currentNodeID`, `testModeEnabled`

2. **Queue Import** — Bulk import from device buffer
   - `saveQueueEntries(_:bootTime:)` — Import batch from `/api/queue/flush`
   - Timestamp reconstruction from device boot time
   - Deduplication: `hasDuplicate(near:)`

3. **Maintenance** — Auto-cleanup
   - `pruneOldEntries()` — Remove >30-day entries
   - Runs after every save

### Refactoring Strategy:

**Extract QueueImporter:**
- Converts queue entries to timestamps
- Deduplicates against DataCache
- Exposes: `importQueueEntries(entries:bootTime:)`

**Extract DataPruner:**
- Removes entries older than retention window
- Runs on schedule (not after every save)
- Exposes: `pruneOlderThan(date:)`

**Keep in DataCache:**
- SwiftData integration: `save()`, `readings()`
- Node/test-mode context: `currentNodeID`, `testModeEnabled`

---

## Summary of Extractions

| Service | Extract | New Responsibility |
|---------|---------|-------------------|
| ConnectionManager | TransportManager | Choose active transport |
| ConnectionManager | QueueDrainer | Coordinate queue flushing |
| BLEService | BLENotificationHandler | Decode + forward notifications |
| WiFiService | RestClient | HTTP REST operations |
| WiFiService | WebSocketManager | WebSocket streaming + keepalive |
| DataCache | QueueImporter | Bulk import with deduplication |
| DataCache | DataPruner | Auto-cleanup and retention |

---

## Expected Benefits

✓ **Testability:** Can mock RestClient without WebSocket logic  
✓ **Reusability:** TransportManager can be used in Settings screen  
✓ **Maintainability:** Each class has ~1-2 reasons to change  
✓ **Clarity:** Clear data flow between services  
✓ **Concurrency:** Isolate async operations per handler  

---

## Implementation Order (Phases 3a-3d)

1. **Phase 3a:** Extract RestClient + WebSocketManager from WiFiService
2. **Phase 3b:** Extract BLENotificationHandler from BLEService
3. **Phase 3c:** Extract TransportManager + QueueDrainer from ConnectionManager
4. **Phase 3d:** Extract QueueImporter + DataPruner from DataCache

Each phase includes:
- New service/handler file creation
- Method extraction to new class
- Updated call sites
- Documentation updates
