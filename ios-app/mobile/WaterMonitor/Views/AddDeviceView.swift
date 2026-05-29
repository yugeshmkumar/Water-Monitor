// /Users/yugeshmluv/Work/Projects/code/Water-Monitor/os-app/WaterMonitor/WaterMonitor/Views/AddDeviceView.swift
import SwiftUI
import SwiftData
import CoreBluetooth

enum AddPhase {
    case scanning, configuring, healthCheck
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
            scanningView
        case .configuring:
            configuringView
        case .healthCheck:
            if let device = savedDevices.last(where: { $0.nodeID == cm.config?.nodeID }) {
                healthCheckView(device: device)
            } else {
                configuringView
            }
        }
    }

    // MARK: - Scanning phase

    private var scanningView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scanningHeader
                Divider()
                deviceList
                scanningFooter
            }
            .navigationTitle("Add Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cm.ble.stopScan()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Clear stale BLE state from any previous session before scanning
            print("[AddDevice] onAppear, clearing state and starting scan")
            cm.ble.deviceConfig = nil
            cm.ble.discovered = []  // Clear discovered list to refresh
            cm.ble.disconnect()      // Disconnect any previous connection
            cm.startBLEScan()
        }
        .onDisappear {
            print("[AddDevice] onDisappear, stopping scan")
            cm.ble.stopScan()
        }
        .onChange(of: cm.ble.deviceConfig) { _, config in
            guard let nodeID = config?.nodeID, !nodeID.isEmpty else {
                print("[AddDevice] Config received but nodeID empty or nil")
                return
            }
            print("[AddDevice] Config received: nodeID=\(nodeID), transport=\(cm.transport)")
            // Transition to configuring (BLE is implied by how we got here)
            phase = .configuring
        }
        .onChange(of: cm.ble.bleState) { _, state in
            print("[AddDevice] BLE state changed to \(state)")
            if state == .disconnected && phase == .configuring {
                print("[AddDevice] Disconnected during configuring, returning to scan")
                phase = .scanning
            }
        }
    }

    private var scanningHeader: some View {
        VStack(spacing: 8) {
            if cm.ble.bleState == .scanning {
                ProgressView()
                Text("Scanning for sensors…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Tap a device to connect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var deviceList: some View {
        Group {
            if cm.ble.bleState == .off {
                ContentUnavailableView(
                    "Bluetooth Off",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Enable Bluetooth in Settings to find your sensor.")
                )
            } else {
                let relevantDevices = cm.ble.discovered.filter { peripheral in
                    guard let name = peripheral.name else { return false }
                    let lower = name.lowercased()
                    return lower.starts(with: "sensor-") ||
                           lower.starts(with: "motor-") ||
                           lower.starts(with: "tank-")
                }

                if relevantDevices.isEmpty {
                    ContentUnavailableView(
                        "No Sensors Found",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Make sure your Water Monitor sensor is powered on and nearby.")
                    )
                } else {
                    List(relevantDevices, id: \.identifier) { peripheral in
                        Button {
                            print("[AddDevice] Connecting to: \(peripheral.name ?? "unknown")")
                            cm.ble.connect(to: peripheral)
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
                                if cm.ble.bleState == .connecting,
                                   cm.ble.connected?.identifier == peripheral.identifier {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(cm.ble.bleState == .connecting || cm.ble.connected?.identifier == peripheral.identifier)
                    }
                }
            }
        }
    }

    private var scanningFooter: some View {
        Text("Make sure your sensor is powered on and nearby")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }

    // MARK: - Configuring phase

    private var configuringView: some View {
        ConfigWizardView(selectedTab: $selectedTab, onComplete: {
            persistDevice()
        })
    }

    // MARK: - Health Check phase

    @ViewBuilder
    private func healthCheckView(device: SavedDevice) -> some View {
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
    }

    // MARK: - Persistence

    private func persistDevice() {
        guard let nodeID = cm.config?.nodeID, !nodeID.isEmpty else { return }
        guard !savedDevices.contains(where: { $0.nodeID == nodeID }) else {
            onComplete?()
            dismiss()
            return
        }
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
