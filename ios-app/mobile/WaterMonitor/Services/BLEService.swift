import CoreBluetooth
import Foundation

private enum GATT {
    static let service    = CBUUID(string: "0000AA01-0000-1000-8000-00805F9B34FB")
    static let levelRead  = CBUUID(string: "AA01")
    static let statusRead = CBUUID(string: "AA02")
    static let cfgRead    = CBUUID(string: "AA03")
    static let cfgWrite   = CBUUID(string: "AA04")
    static let command    = CBUUID(string: "AA05")
    static let cmdResult  = CBUUID(string: "AA06")
}

enum BLEState: Equatable {
    case off, idle, scanning, connecting, connected, disconnected
}

@Observable
final class BLEService: NSObject {
    var bleState: BLEState = .off
    var discovered: [CBPeripheral] = []
    var connected: CBPeripheral?
    var liveStatus: DeviceStatus? {
        didSet { notificationHandler.updateLiveStatus(liveStatus ?? DeviceStatus()) }
    }
    var deviceConfig: DeviceConfig?
    var commandResult: String?
    // Callbacks set by ConnectionManager
    var onLiveReading: ((DeviceStatus) -> Void)? {
        didSet { notificationHandler.onLiveReading = onLiveReading }
    }
    var onConfigReceived: ((DeviceConfig) -> Void)? {
        didSet { notificationHandler.onConfigReceived = onConfigReceived }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var charMap: [CBUUID: CBCharacteristic] = [:]
    private var pendingScan = false
    private let notificationHandler = BLENotificationHandler()  // Handle GATT notifications

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            // CBCentralManager isn't ready yet (state is .unknown on first init).
            // Set a flag — centralManagerDidUpdateState will fire startScan() once ready.
            pendingScan = true
            return
        }
        pendingScan = false
        discovered = []
        bleState = .scanning
        print("[BLE] scan started")
        // Scan without a service filter: NimBLE 2.x advertises service UUIDs in the scan
        // response, not the advertisement packet, so withServices: filter silently misses it.
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        central.stopScan()
        if bleState == .scanning { bleState = .idle }
    }

    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        bleState = .connecting
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    func writeConfig(_ patch: [String: Any]) {
        guard let char = charMap[GATT.cfgWrite],
              let data = try? JSONSerialization.data(withJSONObject: patch) else { return }
        peripheral?.writeValue(data, for: char, type: .withResponse)
    }

    func sendCommand(_ cmd: [String: Any]) {
        guard let char = charMap[GATT.command],
              let data = try? JSONSerialization.data(withJSONObject: cmd) else { return }
        // Use .withResponse since the characteristic has properties = 0x8 (write with response)
        peripheral?.writeValue(data, for: char, type: .withResponse)
    }

    private func subscribeAll() {
        print("[BLE] subscribeAll: discovered \(charMap.count) characteristics")
        for uuid in [GATT.levelRead, GATT.statusRead, GATT.cmdResult] {
            if let c = charMap[uuid] {
                peripheral?.setNotifyValue(true, for: c)
            }
        }

        // Delay reading AA03 slightly to ensure peripheral is ready
        if let c = charMap[GATT.cfgRead] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak c] in
                guard let c = c else { return }
                print("[BLE] reading AA03 config...")
                self?.peripheral?.readValue(for: c)
            }
        } else {
            print("[BLE] ⚠️ AA03 config characteristic not found!")
        }
    }

}

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bleState = central.state == .poweredOn ? .idle : .off
        print("[BLE] central state → \(central.state.rawValue)")
        if central.state == .poweredOn && pendingScan {
            startScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.name != nil else { return }
        guard !discovered.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        print("[BLE] found: \(peripheral.name ?? "?")  RSSI: \(RSSI)")
        discovered.append(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] connected to \(peripheral.name ?? peripheral.identifier.uuidString)")
        connected = peripheral
        bleState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([GATT.service])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        print("[BLE] disconnected: \(error?.localizedDescription ?? "clean")")
        connected = nil
        charMap = [:]
        bleState = .disconnected
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        bleState = .disconnected
    }
}

extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let svc = peripheral.services?.first(where: { $0.uuid == GATT.service }) else { return }
        peripheral.discoverCharacteristics(nil, for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error = error {
            print("[BLE] error discovering characteristics: \(error)")
            return
        }
        let chars = service.characteristics ?? []
        print("[BLE] discovered \(chars.count) characteristics:")
        for c in chars {
            charMap[c.uuid] = c
            print("[BLE]   - \(c.uuid.uuidString) (props: \(c.properties.rawValue))")
        }
        subscribeAll()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error = error {
            print("[BLE] error reading \(characteristic.uuid.uuidString): \(error)")
            return
        }
        notificationHandler.handleNotification(characteristic)
        // Sync notification handler state back to BLEService for Observable
        liveStatus = notificationHandler.liveStatus
        deviceConfig = notificationHandler.deviceConfig
        commandResult = notificationHandler.commandResult
    }
}
