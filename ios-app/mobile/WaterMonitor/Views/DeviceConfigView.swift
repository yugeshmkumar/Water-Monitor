import SwiftUI
import SwiftData
import CoreBluetooth

// Opened from AppSettingsView (device row tap) OR auto-redirected from DeviceDetailView
// when the device has been offline too long. Auto-attempts BLE connection on appear.
struct DeviceConfigView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext
    let device: SavedDevice

    @State private var selectedTab = 0
    @State private var bleStatus: BLEConnectStatus = .idle
    @State private var bleTask: Task<Void, Never>?

    enum BLEConnectStatus {
        case idle, connecting, connected, failed

        func label(transport: Transport) -> String {
            switch self {
            case .idle:
                return "Not connected"
            case .connecting:
                return "Connecting…"
            case .connected:
                switch transport {
                case .wifi: return "Connected via WiFi"
                case .ble: return "Connected via Bluetooth"
                case .none: return "Connected"
                }
            case .failed:
                return "Unable to connect"
            }
        }

        var label: String {
            label(transport: .none)
        }
        var color: Color {
            switch self {
            case .idle:       return .secondary
            case .connecting: return .orange
            case .connected:  return .green
            case .failed:     return .red
            }
        }
        var icon: String {
            switch self {
            case .idle:       return "dot.radiowaves.left.and.right"
            case .connecting: return "dot.radiowaves.left.and.right"
            case .connected:  return "checkmark.circle.fill"
            case .failed:     return "exclamationmark.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            connectionBanner
            Divider()
            ConfigWizardView(selectedTab: $selectedTab)
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startBLEConnect() }
        .onDisappear { bleTask?.cancel() }
        .onChange(of: cm.ble.bleState) { _, state in
            switch state {
            case .connected:
                if cm.ble.deviceConfig?.nodeID == device.nodeID || cm.ble.deviceConfig == nil {
                    bleStatus = .connected
                }
            case .disconnected:
                if bleStatus == .connecting { bleStatus = .failed }
            default: break
            }
        }
        .onChange(of: cm.ble.deviceConfig) { _, config in
            guard let config else { return }
            if config.nodeID == device.nodeID { bleStatus = .connected }
        }
    }

    // MARK: - BLE Connection Banner

    private var connectionBanner: some View {
        HStack(spacing: 10) {
            if bleStatus == .connecting {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: bleStatus.icon)
                    .foregroundStyle(bleStatus.color)
            }

            Text(bleStatus.label(transport: cm.transport))
                .font(.subheadline)
                .foregroundStyle(bleStatus.color)

            Spacer()

            if bleStatus == .failed || bleStatus == .idle {
                Button("Retry") { startBLEConnect() }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(bleStatus.color.opacity(0.08))
    }

    // MARK: - BLE auto-connect

    private func startBLEConnect() {
        guard cm.transport != .wifi || cm.config?.nodeID != device.nodeID else {
            bleStatus = .connected
            return
        }
        guard cm.ble.bleState != .connected else {
            bleStatus = .connected
            return
        }

        bleStatus = .connecting
        cm.startBLEScan()

        bleTask?.cancel()
        bleTask = Task {
            // Poll discovered devices for 20 seconds looking for this device
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if cm.ble.bleState == .connected { return }
                if cm.ble.bleState == .connecting { continue }

                if let peripheral = cm.ble.discovered.first(where: { $0.name == device.nodeID }) {
                    cm.ble.connect(to: peripheral)
                }
            }
            // Timeout
            await MainActor.run {
                if bleStatus == .connecting { bleStatus = .failed }
                cm.ble.stopScan()
            }
        }
    }
}
