import Foundation

@Observable
final class ConfigVM {
    var edited: DeviceConfig = DeviceConfig()
    var isSaving: Bool = false

    let availablePins = ["D0","D1","D2","D3","D4","D5","D6","D7","D8","D9","D10"]

    private var cm: ConnectionManager?

    init() {}

    func configure(with cm: ConnectionManager) {
        self.cm = cm
        edited = cm.config ?? DeviceConfig()
    }

    func save() {
        guard let cm else { return }
        let patch: [String: Any]
        if let current = cm.config {
            patch = current.patch(from: edited)
        } else {
            patch = asDictionary(edited)
        }
        guard !patch.isEmpty else { return }
        Task {
            await cm.writeConfig(patch)
        }
    }

    func testPin() {
        cm?.sendCommand(["cmd": "test_pin", "peripheral": "sensor"])
    }

    func reboot() {
        cm?.sendCommand(["cmd": "reboot"])
    }

    var pinsConflict: Bool { edited.pinTrig == edited.pinEcho }

    // asDictionary(_:)
    // ────────────────────────────────────────────────────────
    // Converts a DeviceConfig object to a dictionary for API patching.
    // Returns empty dict on encoding error (non-critical path).
    private func asDictionary(_ c: DeviceConfig) -> [String: Any] {
        do {
            let data = try JSONEncoder().encode(c)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return dict
        } catch {
            print("[ConfigVM] Failed to encode config: \(error)")
            return [:]
        }
    }
}
