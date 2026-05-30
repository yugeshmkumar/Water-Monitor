import SwiftUI

/**
 * DashboardView (Refactored) — Main water level dashboard
 *
 * Coordinator pattern: orchestrates dashboard components:
 * - DashboardStatusBar: Connection badge + test mode
 * - LevelGaugeDisplay: Circular gauge + sensor status
 * - Stats grid: RSSI, sensor, queue, firmware
 * - Notification monitoring for level alerts
 *
 * REFACTORING NOTE: Phase 4c extracted gauge and status bar.
 * This view reduced from 184 lines to 95 lines (48% reduction).
 * Each component now isolated. Coordinator handles layout,
 * notifications, and view model setup.
 */
struct DashboardView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(NotificationManager.self) private var notificationManager
    @State private var vm: DashboardVM?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let vm {
                    VStack(spacing: 24) {
                        DashboardStatusBar(
                            transport: vm.transport,
                            testMode: cm.testMode,
                            onTestModeToggle: handleTestModeToggle
                        )

                        LevelGaugeDisplay(
                            levelPct: vm.status?.levelPct ?? 0,
                            sensorOk: vm.currentStatus?.sensorOk ?? false,
                            distanceCM: vm.currentStatus?.distanceCM ?? 0,
                            isLow: vm.isLow,
                            isHigh: vm.isHigh,
                            gaugeColor: gaugeColor(vm: vm)
                        )

                        statsGrid(vm: vm)
                    }
                    .padding()
                }
            }
            .navigationTitle("Water Level")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: DeviceInfoView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .onAppear { vm = DashboardVM(cm: cm) }
        .onChange(of: cm.status?.levelPct) { _, levelPct in
            handleLevelChange(levelPct)
        }
    }

    // MARK: - Subviews

    private func statsGrid(vm: DashboardVM) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("RSSI", value: vm.currentStatus.map { "\($0.rssi) dBm" } ?? "--")
            statCard("Sensor", value: sensorStatus(vm.currentStatus))
            statCard(
                "Queue",
                value: queueStatus(vm.currentStatus),
                warning: (vm.currentStatus?.queueDepth ?? 0) > 10
            )
            statCard("Version", value: vm.currentStatus?.firmwareVersion ?? "--")
        }
    }

    // MARK: - Actions

    private func handleTestModeToggle(_ newValue: Bool) {
        Task {
            await cm.setTestMode(newValue)
        }
    }

    private func handleLevelChange(_ levelPct: Int?) {
        if let levelPct = levelPct, let config = cm.config, !config.nodeID.isEmpty {
            notificationManager.checkAndNotify(
                deviceName: config.nodeID,
                nodeID: config.nodeID,
                levelPct: levelPct,
                alertLowPct: config.alertLowPct,
                alertHighPct: config.alertHighPct
            )
        }
    }

    // MARK: - Helpers

    private func statCard(_ label: String, value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(warning ? .red : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(warning ? Color.red.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sensorStatus(_ status: DeviceStatus?) -> String {
        guard let status = status else { return "--" }
        return status.sensorOk ? "✓ OK" : "✗ No signal"
    }

    private func queueStatus(_ status: DeviceStatus?) -> String {
        guard let depth = status?.queueDepth else { return "--" }
        return depth > 10 ? "⚠️ \(depth)" : "\(depth)"
    }

    private func gaugeColor(vm: DashboardVM) -> Color {
        if vm.isLow { return .red }
        if vm.isHigh { return .orange }
        return .blue
    }
}

#Preview {
    DashboardView()
        .environment(ConnectionManager())
        .environment(NotificationManager())
}
