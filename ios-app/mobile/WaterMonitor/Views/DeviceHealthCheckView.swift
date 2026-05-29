import SwiftUI

struct DeviceHealthCheckView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.dismiss) private var dismiss
    @State private var testInProgress = false
    @State private var testResult: TestResult?
    @State private var showConfigSheet = false

    enum TestResult {
        case success(reading: String, timestamp: String)
        case failure(error: String)
    }

    var device: SavedDevice

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        statusCard
                        testCard
                        if let result = testResult {
                            resultCard(result)
                        }
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

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName).font(.subheadline.bold())
                    Text(device.nodeID).font(.caption).foregroundStyle(.secondary)
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

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                statusRow("BLE", cm.isBLEConnected ? "Active" : "Inactive")
                statusRow("WiFi", cm.config?.wifiSSID.isEmpty == false ? "Configured" : "Not Set")
                if let status = cm.displayStatus, status.ts > 0 {
                    let date = Date(timeIntervalSince1970: TimeInterval(status.ts))
                    statusRow("Last Reading", formatTime(date))
                } else {
                    statusRow("Last Reading", "Never")
                }

                if let rssi = cm.displayStatus?.rssi, rssi != 0 {
                    statusRow("Signal (dBm)", "\(rssi)")
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify Device").font(.headline)

            Button(action: testDeviceConnection) {
                HStack {
                    if testInProgress {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(testInProgress ? "Testing..." : "Test Connection")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(testInProgress)

            if !testInProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sends a ping and waits for device response", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func resultCard(_ result: TestResult) -> some View {
        switch result {
        case .success(let reading, let timestamp):
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Device Responding").font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    resultRow("Latest Reading", reading)
                    resultRow("Timestamp", timestamp)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

        case .failure(let error):
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Connection Failed").font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Troubleshooting:").font(.caption.bold())
                    Label("Verify WiFi is configured (SSID/password)", systemImage: "wifi")
                        .font(.caption)
                    Label("Check device is powered on and in range", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                    Label("Try reconnecting or reconfiguring", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding()
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
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

    // MARK: - Helpers

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold().monospaced())
        }
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced())
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Logic

    private func loadDeviceStatus() {
        Task {
            // Give device time to join WiFi after setup (usually 3-5 seconds)
            print("[HealthCheck] Waiting for device to connect to WiFi...")
            try? await Task.sleep(for: .seconds(3))

            // Try WiFi first (should now be connected), then BLE
            await cm.connectToDevice(device)
        }
    }

    private func testDeviceConnection() {
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
}

#Preview {
    DeviceHealthCheckView(device: SavedDevice(nodeID: "sensor-a", displayName: "Tank Sensor", lastHost: "sensor-a.local", lastIP: "192.168.1.168"))
        .environment(ConnectionManager())
}
