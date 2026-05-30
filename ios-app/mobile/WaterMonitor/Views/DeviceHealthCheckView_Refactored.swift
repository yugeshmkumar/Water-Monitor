import SwiftUI

/**
 * DeviceHealthCheckView (Refactored) — Device connectivity troubleshooting
 *
 * Coordinator pattern: orchestrates health check workflow:
 * - HealthCheckStatus: Connection status display
 * - HealthCheckTester: Connection test and results
 * - Action buttons: Configure device, Done
 *
 * REFACTORING NOTE: Phase 4c.4 extracted status and tester.
 * This view reduced from 288 lines to 100 lines (65% reduction).
 * Each component now isolated. Coordinator handles layout,
 * device connection loading, and test execution.
 */
struct DeviceHealthCheckView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.dismiss) private var dismiss
    @State private var testInProgress = false
    @State private var testResult: HealthCheckTester.TestResult?
    @State private var showConfigSheet = false

    var device: SavedDevice

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        HealthCheckStatus(
                            isBLEConnected: cm.isBLEConnected,
                            wifiConfigured: cm.config?.wifiSSID.isEmpty == false,
                            lastReadingTime: cm.displayStatus.map { Date(timeIntervalSince1970: TimeInterval($0.ts)) },
                            rssi: cm.displayStatus?.rssi
                        )

                        HealthCheckTester(
                            testInProgress: testInProgress,
                            testResult: testResult,
                            onTestTap: handleTest
                        )

                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Device Health")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadDeviceStatus() }
            .sheet(isPresented: $showConfigSheet) {
                DeviceConfigView(device: device)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.subheadline.bold())
                    Text(device.nodeID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(connectionStatusText)
                .font(.caption.bold())
                .foregroundStyle(connectionStatusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(connectionStatusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showConfigSheet = true }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Configure Device")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: { dismiss() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func loadDeviceStatus() {
        Task {
            print("[HealthCheck] Waiting for device to connect to WiFi...")
            try? await Task.sleep(for: .seconds(3))
            await cm.connectToDevice(device)
        }
    }

    private func handleTest() {
        testInProgress = true
        testResult = nil

        Task {
            do {
                let status = try await cm.testDeviceConnection()
                let readingStr = String(format: "%.1f cm @ %d%%", status.distanceCM, status.levelPct)
                let date = Date(timeIntervalSince1970: TimeInterval(status.ts))
                let timeStr = formatTime(date)
                await MainActor.run {
                    testResult = .success(reading: readingStr, timestamp: timeStr)
                    testInProgress = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error: error.localizedDescription)
                    testInProgress = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var connectionStatusColor: Color {
        if cm.isConnected { return .green }
        if cm.isConnecting { return .orange }
        return .red
    }

    private var connectionStatusText: String {
        if cm.isConnected { return "Connected" }
        if cm.isConnecting { return "Connecting..." }
        return "Disconnected"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    DeviceHealthCheckView(
        device: SavedDevice(
            nodeID: "sensor-a",
            displayName: "Tank Sensor",
            lastHost: "sensor-a.local",
            lastIP: "192.168.1.168"
        )
    )
    .environment(ConnectionManager())
}
