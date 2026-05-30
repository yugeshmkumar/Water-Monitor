import SwiftUI
import CoreBluetooth

/**
 * BLEScanPhase — BLE device discovery and selection
 *
 * Displays:
 * - Scanning status (progress indicator or idle state)
 * - List of discovered Water Monitor sensors
 * - Device names, UUIDs, connection status
 * - Bluetooth off warning if needed
 * - Empty state when no devices found
 *
 * Isolated BLE discovery UI. Used in AddDeviceView and other onboarding flows.
 */
struct BLEScanPhase: View {
    let bleState: CBManagerState
    let discoveredDevices: [CBPeripheral]
    let connectedDevice: CBPeripheral?
    let onDeviceSelected: (CBPeripheral) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scanHeader
                Divider()
                deviceListView
                scanFooter
            }
            .navigationTitle("Add Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }

    // MARK: - Subviews

    private var scanHeader: some View {
        VStack(spacing: 8) {
            if bleState == .poweredOn && discoveredDevices.isEmpty {
                ProgressView()
                Text("Scanning for sensors…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if bleState == .poweredOn {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Tap a device to connect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                Text("Bluetooth is off")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var deviceListView: some View {
        Group {
            if bleState != .poweredOn {
                ContentUnavailableView(
                    "Bluetooth Off",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Enable Bluetooth in Settings to find your sensor.")
                )
            } else {
                let relevantDevices = filteredDevices
                if relevantDevices.isEmpty {
                    ContentUnavailableView(
                        "No Sensors Found",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Make sure your Water Monitor sensor is powered on and nearby.")
                    )
                } else {
                    deviceList(relevantDevices)
                }
            }
        }
    }

    private func deviceList(_ devices: [CBPeripheral]) -> some View {
        List(devices, id: \.identifier) { peripheral in
            Button {
                onDeviceSelected(peripheral)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(peripheral.name ?? "Unnamed device")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if bleState == .poweredOn && isConnecting(peripheral) {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .disabled(
                bleState != .poweredOn ||
                isConnecting(peripheral) ||
                isConnected(peripheral)
            )
        }
    }

    private var scanFooter: some View {
        Text("Make sure your sensor is powered on and nearby")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }

    // MARK: - Helpers

    private var filteredDevices: [CBPeripheral] {
        discoveredDevices.filter { peripheral in
            guard let name = peripheral.name else { return false }
            let lower = name.lowercased()
            return lower.starts(with: "sensor-") ||
                   lower.starts(with: "motor-") ||
                   lower.starts(with: "tank-")
        }
    }

    private func isConnecting(_ peripheral: CBPeripheral) -> Bool {
        bleState == .poweredOn &&
        connectedDevice == nil &&
        discoveredDevices.contains(where: { $0.identifier == peripheral.identifier })
    }

    private func isConnected(_ peripheral: CBPeripheral) -> Bool {
        connectedDevice?.identifier == peripheral.identifier
    }
}

#Preview {
    BLEScanPhase(
        bleState: .poweredOn,
        discoveredDevices: [],
        connectedDevice: nil,
        onDeviceSelected: { _ in },
        onDismiss: {}
    )
}
