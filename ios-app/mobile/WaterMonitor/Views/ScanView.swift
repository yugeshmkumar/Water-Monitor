import SwiftUI
import CoreBluetooth

struct ScanView: View {
    @Environment(ConnectionManager.self) private var cm
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            Group {
                if cm.ble.bleState == .off {
                    ContentUnavailableView("Bluetooth Off",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Enable Bluetooth in Settings to find your sensor."))
                } else {
                    deviceList
                }
            }
            .navigationTitle("Find Sensor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(scanning ? "Stop" : "Scan") { toggleScan() }
                        .disabled(cm.ble.bleState == .off)
                }
            }
        }
        .onAppear { toggleScan() }
        .onDisappear { if scanning { cm.ble.stopScan(); scanning = false } }
    }

    private var deviceList: some View {
        List(cm.ble.discovered, id: \.identifier) { device in
            Button {
                cm.ble.connect(to: device)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name ?? "Unnamed device")
                            .font(.headline)
                        Text(device.identifier.uuidString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if cm.ble.bleState == .connecting,
                       cm.ble.connected?.identifier == device.identifier {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .overlay {
            if cm.ble.discovered.isEmpty && scanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Looking for sensors…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggleScan() {
        if scanning {
            cm.ble.stopScan()
        } else {
            cm.startBLEScan()
        }
        scanning.toggle()
    }
}
