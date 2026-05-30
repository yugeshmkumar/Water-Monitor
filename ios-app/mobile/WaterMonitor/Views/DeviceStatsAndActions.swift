import SwiftUI

/**
 * DeviceStatsAndActions — Device metrics and control buttons
 *
 * Displays:
 * - Stats grid (RSSI, sensor status, queue depth, firmware)
 * - Quick actions (test mode toggle, interval slider)
 * - Action buttons (calibrate, health check, history)
 *
 * Isolated stats and controls. Used in DeviceDetailView.
 */
struct DeviceStatsAndActions: View {
    let rssi: Int
    let sensorOk: Bool
    let queueDepth: Int
    let firmwareVersion: String
    let testMode: Bool
    let testModeLoading: Bool
    let testInterval: Int?
    let isActive: Bool
    let onTestModeToggle: (Bool) -> Void
    let onTestIntervalChange: (Int) -> Void
    let onCalibrateTap: () -> Void
    let onHealthCheckTap: () -> Void
    let onHistoryTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Stats Grid
            statsGrid

            // Quick Actions
            quickActionsPanel

            // Action Buttons
            actionButtons
        }
    }

    // MARK: - Subviews

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("RSSI", value: "\(rssi) dBm")
            statCard("Sensor", value: sensorOk ? "OK" : "No signal", warning: !sensorOk)
            statCard("Queue", value: "\(queueDepth)", warning: queueDepth > 10)
            statCard("Firmware", value: firmwareVersion)
        }
    }

    private var quickActionsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: testMode
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(testMode ? .green : .secondary)

                Toggle("Test Mode", isOn: Binding(
                    get: { testMode },
                    set: { onTestModeToggle($0) }
                ))
                .disabled(testModeLoading || !isActive)

                if testModeLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .font(.subheadline)

            if testMode, let interval = testInterval {
                HStack(spacing: 12) {
                    Text("Test Interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(interval) },
                            set: { onTestIntervalChange(Int($0)) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    Text("\(interval)s")
                        .font(.caption.monospacedDigit())
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(testMode ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: onCalibrateTap) {
                    Label("Calibrate", systemImage: "target")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isActive)

                Button(action: onHealthCheckTap) {
                    Label("Health Check", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isActive)
            }

            NavigationLink(action: onHistoryTap) {
                Label("History", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
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
}

#Preview {
    DeviceStatsAndActions(
        rssi: -65,
        sensorOk: true,
        queueDepth: 5,
        firmwareVersion: "1.0.0",
        testMode: false,
        testModeLoading: false,
        testInterval: 5,
        isActive: true,
        onTestModeToggle: { _ in },
        onTestIntervalChange: { _ in },
        onCalibrateTap: {},
        onHealthCheckTap: {},
        onHistoryTap: {}
    )
    .padding()
}
