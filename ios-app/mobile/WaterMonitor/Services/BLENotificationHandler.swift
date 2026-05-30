import CoreBluetooth
import Foundation

/**
 * BLENotificationHandler — Decode and process BLE characteristic notifications
 *
 * Handles incoming GATT notifications from device, decodes JSON payloads,
 * updates state, and calls registered callbacks.
 * Extracted from BLEService to isolate notification handling.
 *
 * GATT Characteristics:
 * - AA01 (levelRead):   Level + distance + timestamp (sensor reading)
 * - AA02 (statusRead):  WiFi/sensor status + RSSI + queue depth
 * - AA03 (cfgRead):     Device configuration (read on connection)
 * - AA06 (cmdResult):   Command response as text
 *
 * Merging Strategy:
 * - AA01: Merge level/distance into existing status, set sensor_ok=true
 * - AA02: Merge WiFi/sensor status without overwriting level
 * - AA03: Decode full config, update firmware version in status
 */
final class BLENotificationHandler {
    // Updated state (read by BLEService)
    private(set) var liveStatus: DeviceStatus?
    private(set) var deviceConfig: DeviceConfig?
    private(set) var commandResult: String?

    // Callbacks registered by ConnectionManager
    var onLiveReading: ((DeviceStatus) -> Void)?
    var onConfigReceived: ((DeviceConfig) -> Void)?

    // GATT UUIDs
    private enum GATT {
        static let levelRead  = CBUUID(string: "AA01")
        static let statusRead = CBUUID(string: "AA02")
        static let cfgRead    = CBUUID(string: "AA03")
        static let cmdResult  = CBUUID(string: "AA06")
    }

    /**
     * Process an incoming characteristic notification.
     * Decodes JSON based on UUID and updates corresponding state.
     *
     * Parameters:
     *   characteristic - The characteristic that was updated
     */
    func handleNotification(_ characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        let raw = String(data: data, encoding: .utf8) ?? "<binary \(data.count)B>"

        switch characteristic.uuid {
        case GATT.levelRead:
            handleLevelNotification(data, raw: raw)
        case GATT.statusRead:
            handleStatusNotification(data, raw: raw)
        case GATT.cfgRead:
            handleConfigNotification(data, raw: raw)
        case GATT.cmdResult:
            handleCommandResultNotification(raw: raw)
        default:
            print("[BLE] unknown char \(characteristic.uuid): \(raw)")
        }
    }

    // MARK: - Private: Notification Handlers

    /**
     * AA01: Level notification (distance + tank fill percentage)
     *
     * Payload: {"level_pct":N,"distance_cm":N,"ts":N}
     * Note: Firmware only sends AA01 when sensor_ok=true, so receipt implies validity.
     * Merges into existing status without overwriting other fields.
     */
    private func handleLevelNotification(_ data: Data, raw: String) {
        if let s = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
            var merged = liveStatus ?? DeviceStatus()
            merged.levelPct   = s.levelPct
            merged.distanceCM = s.distanceCM
            merged.ts         = s.ts
            merged.sensorOk   = true  // receipt of AA01 proves sensor is valid
            liveStatus = merged
            onLiveReading?(s)
            print("[BLE] AA01 level: \(raw)")
        }
    }

    /**
     * AA02: Status notification (WiFi, sensor, signal, queue)
     *
     * Payload: {"wifi_ok":B,"sensor_ok":B,"rssi":N,"queue_depth":N,"local_ip":"..."}
     * Merges status fields without overwriting level (which came from AA01).
     * Only logs when something meaningful changes (reduces log noise).
     */
    private func handleStatusNotification(_ data: Data, raw: String) {
        if let s = try? JSONDecoder().decode(DeviceStatus.self, from: data) {
            let prev = liveStatus
            var merged = liveStatus ?? DeviceStatus()
            merged.wifiOk     = s.wifiOk
            merged.sensorOk   = s.sensorOk
            merged.rssi       = s.rssi
            merged.queueDepth = s.queueDepth
            merged.localIP    = s.localIP
            liveStatus = merged

            // Log only when something interesting changed
            if prev == nil || s.queueDepth != prev?.queueDepth ||
               s.sensorOk != prev?.sensorOk || s.localIP != prev?.localIP {
                print("[BLE] AA02 status: \(raw)")
            }
        }
    }

    /**
     * AA03: Configuration notification (read on connection)
     *
     * Payload: Full DeviceConfig JSON
     * Updates device config state and calls onConfigReceived callback.
     * Also updates firmware version in live status.
     */
    private func handleConfigNotification(_ data: Data, raw: String) {
        print("[BLE] AA03 raw data: \(raw)")
        do {
            let cfg = try JSONDecoder().decode(DeviceConfig.self, from: data)
            deviceConfig = cfg
            var merged = liveStatus ?? DeviceStatus()
            merged.firmwareVersion = cfg.firmwareVersion
            liveStatus = merged
            onConfigReceived?(cfg)
            print("[BLE] AA03 config decoded: node=\(cfg.nodeID) empty=\(cfg.tankEmptyCM) full=\(cfg.tankFullCM)")
        } catch {
            print("[BLE] ❌ AA03 decode error: \(error)")
        }
    }

    /**
     * AA06: Command result notification
     *
     * Payload: Plain text response to command
     * Stores result string for app to display.
     */
    private func handleCommandResultNotification(raw: String) {
        commandResult = raw
        print("[BLE] AA06 result: \(raw)")
    }

    /**
     * Update liveStatus property (called by BLEService after processing)
     */
    func updateLiveStatus(_ status: DeviceStatus) {
        liveStatus = status
    }
}
