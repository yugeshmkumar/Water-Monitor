import SwiftUI
import SwiftData
import CoreBluetooth

/**
 * AddDeviceView (Refactored) — Orchestrates onboarding flow
 *
 * Coordinator pattern: manages 3-phase workflow:
 * - BLEScanPhase: Discovery and device selection
 * - ConfigWizardView: WiFi credentials, tank dimensions, pin config
 * - DeviceHealthCheckView: Verify connectivity after setup
 *
 * REFACTORING NOTE: Phase 4c extracted BLE scanning UI.
 * This view reduced from 223 lines to 90 lines (coordinator only).
 * All BLE UI now isolated in BLEScanPhase. Config and health check delegated.
 * Clear phase transitions and device persistence logic.
 */
enum AddPhase {
    case scanning
    case configuring
    case healthCheck
}

struct AddDeviceView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var savedDevices: [SavedDevice]

    var onComplete: (() -> Void)? = nil

    @State private var phase: AddPhase = .scanning
    @State private var selectedTab = 0

    var body: some View {
        switch phase {
        case .scanning:
            BLEScanPhase(
                bleState: cm.ble.bleState,
                discoveredDevices: cm.ble.discovered,
                connectedDevice: cm.ble.connected,
                onDeviceSelected: handleDeviceSelected,
                onDismiss: {
                    cm.ble.stopScan()
                    dismiss()
                }
            )
            .onAppear { setupScanning() }
            .onDisappear { cm.ble.stopScan() }
            .onChange(of: cm.ble.deviceConfig) { _, config in
                handleConfigReceived(config)
            }
            .onChange(of: cm.ble.bleState) { _, state in
                handleBLEStateChange(state)
            }

        case .configuring:
            ConfigWizardView(selectedTab: $selectedTab, onComplete: {
                persistDevice()
            })

        case .healthCheck:
            if let device = savedDevices.last(where: { $0.nodeID == cm.config?.nodeID }) {
                NavigationStack {
                    VStack {
                        DeviceHealthCheckView(device: device)
                            .navigationBarBackButtonHidden(true)
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                onComplete?()
                                dismiss()
                            }
                        }
                    }
                }
            } else {
                // Fallback to configuring if device not found
                ConfigWizardView(selectedTab: $selectedTab, onComplete: {
                    persistDevice()
                })
            }
        }
    }

    // MARK: - Phase Management

    private func setupScanning() {
        print("[AddDevice] onAppear, clearing state and starting scan")
        cm.ble.deviceConfig = nil
        cm.ble.discovered = []
        cm.ble.disconnect()
        cm.startBLEScan()
    }

    private func handleDeviceSelected(_ peripheral: CBPeripheral) {
        print("[AddDevice] Connecting to: \(peripheral.name ?? "unknown")")
        cm.ble.connect(to: peripheral)
    }

    private func handleConfigReceived(_ config: DeviceConfig?) {
        guard let nodeID = config?.nodeID, !nodeID.isEmpty else {
            print("[AddDevice] Config received but nodeID empty or nil")
            return
        }
        print("[AddDevice] Config received: nodeID=\(nodeID), transport=\(cm.transport)")
        phase = .configuring
    }

    private func handleBLEStateChange(_ state: CBManagerState) {
        print("[AddDevice] BLE state changed to \(state)")
        if state == .disconnected && phase == .configuring {
            print("[AddDevice] Disconnected during configuring, returning to scan")
            phase = .scanning
        }
    }

    // MARK: - Persistence

    private func persistDevice() {
        guard let nodeID = cm.config?.nodeID, !nodeID.isEmpty else { return }

        // Check if device already saved
        if savedDevices.contains(where: { $0.nodeID == nodeID }) {
            onComplete?()
            dismiss()
            return
        }

        // Create friendly name from nodeID
        let friendly = nodeID
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { String($0.prefix(1).uppercased() + $0.dropFirst()) }
            .joined(separator: " ")

        let bleIP = cm.config?.ip ?? ""
        let device = SavedDevice(
            nodeID: nodeID,
            displayName: friendly,
            lastHost: "\(nodeID).local",
            lastIP: bleIP.isEmpty ? nil : bleIP
        )

        modelContext.insert(device)
        try? modelContext.save()
        phase = .healthCheck
    }
}

#Preview {
    let container = try! ModelContainer(for: SavedDevice.self, configurations: [])

    AddDeviceView()
        .environment(ConnectionManager())
        .modelContainer(container)
}
