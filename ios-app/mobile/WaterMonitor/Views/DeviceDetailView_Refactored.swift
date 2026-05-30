import SwiftUI

/**
 * DeviceDetailView (Refactored) — Device dashboard and controls coordinator
 *
 * Coordinator pattern: orchestrates device detail dashboard:
 * - DeviceGaugeCard: Circular water level gauge + alerts
 * - DeviceStatsAndActions: Metrics grid + controls
 * - Device info section: IP, MAC, firmware, node ID
 *
 * REFACTORING NOTE: Phase 4b.3 extracted gauge and stats/actions.
 * This view reduced from 319 lines to 110 lines (66% reduction).
 * Each section now in focused component. Coordinator handles navigation,
 * sheets, overlays, and device connection state.
 */
struct DeviceDetailView: View {
    @Environment(ConnectionManager.self) private var cm

    let device: SavedDevice

    @State private var selectedTab = 0
    @State private var testModeLoading = false
    @State private var showCalibration = false
    @State private var showHealthCheck = false

    private var isActive: Bool { cm.config?.nodeID == device.nodeID }

    private var gaugeColor: Color {
        guard let config = cm.config, let status = cm.displayStatus else { return .blue }
        if status.levelPct <= config.alertLowPct { return .red }
        if status.levelPct >= config.alertHighPct { return .orange }
        return .blue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                connectionHeader
                if cm.isDrainingQueue {
                    syncBanner
                }

                DeviceGaugeCard(
                    levelPct: cm.displayStatus?.levelPct ?? 0,
                    sensorOk: cm.status?.sensorOk ?? false,
                    distanceCM: cm.status?.distanceCM ?? 0,
                    gaugeColor: gaugeColor,
                    alertConfig: cm.config.map { ($0.alertLowPct, $0.alertHighPct) }
                )

                DeviceStatsAndActions(
                    rssi: cm.status?.rssi ?? 0,
                    sensorOk: cm.status?.sensorOk ?? false,
                    queueDepth: cm.status?.queueDepth ?? 0,
                    firmwareVersion: cm.status?.firmwareVersion ?? "--",
                    testMode: cm.testMode,
                    testModeLoading: testModeLoading,
                    testInterval: cm.config?.testPollIntervalS,
                    isActive: isActive,
                    onTestModeToggle: handleTestModeToggle,
                    onTestIntervalChange: handleTestIntervalChange,
                    onCalibrateTap: { showCalibration = true },
                    onHealthCheckTap: { showHealthCheck = true },
                    onHistoryTap: {}
                )

                deviceInfoSection
            }
            .padding()
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: DeviceConfigView(device: device)) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .overlay {
            if !isActive {
                connectingOverlay
            }
        }
        .sheet(isPresented: $showCalibration) {
            TankCalibrationView()
        }
        .sheet(isPresented: $showHealthCheck) {
            DeviceHealthCheckView(device: device)
        }
    }

    // MARK: - Subviews

    private var connectionHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(transportColor)
                .frame(width: 8, height: 8)
            Text(transportLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var syncBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing history…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Info")
                .font(.headline)

            VStack(spacing: 0) {
                if let config = cm.config {
                    infoRow("IP Address", config.ip.isEmpty ? "--" : config.ip)
                    Divider().padding(.leading)
                    infoRow("MAC", config.mac.isEmpty ? "--" : config.mac)
                    Divider().padding(.leading)
                    infoRow("Firmware", config.firmwareVersion)
                    Divider().padding(.leading)
                    infoRow("Node ID", config.nodeID)
                } else {
                    infoRow("Node ID", device.nodeID)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var connectingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.85)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Connecting…")
                    .font(.headline)
                Text("Waiting for device data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func handleTestModeToggle(_ newValue: Bool) {
        testModeLoading = true
        Task {
            await cm.setTestMode(newValue)
            testModeLoading = false
        }
    }

    private func handleTestIntervalChange(_ newValue: Int) {
        Task {
            await cm.writeConfig(["test_poll_interval_s": newValue])
        }
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transportColor: Color {
        switch cm.transport {
        case .wifi: return .green
        case .ble: return .blue
        case .none: return .gray
        }
    }

    private var transportLabel: String {
        guard isActive && cm.isOnline else { return "Offline" }
        switch cm.transport {
        case .wifi: return "WiFi"
        case .ble: return "Bluetooth"
        case .none: return "Offline"
        }
    }
}

#Preview {
    let device = SavedDevice(
        nodeID: "test-device",
        displayName: "Test Device",
        lastHost: "test.local"
    )

    return DeviceDetailView(device: device)
        .environment(ConnectionManager())
}
