import Foundation

@Observable
final class ConfigVM {
    var edited: DeviceConfig = DeviceConfig()
    var isSaving: Bool = false

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

    private func asDictionary(_ c: DeviceConfig) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(c),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict
    }
}
