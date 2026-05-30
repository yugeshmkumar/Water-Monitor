import SwiftUI

/**
 * HealthCheckTester — Device connection test and results
 *
 * Displays:
 * - Test button (with loading state)
 * - Help text about what test does
 * - Result display (success with reading or failure with troubleshooting)
 *
 * Isolated test logic display. Used in DeviceHealthCheckView.
 */
struct HealthCheckTester: View {
    enum TestResult {
        case success(reading: String, timestamp: String)
        case failure(error: String)
    }

    let testInProgress: Bool
    let testResult: TestResult?
    let onTestTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            testCard
            if let result = testResult {
                resultCard(result)
            }
        }
    }

    // MARK: - Subviews

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify Device")
                .font(.headline)

            Button(action: onTestTap) {
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
                    Label("Sends a ping and waits for device response",
                          systemImage: "info.circle")
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
                    Text("Device Responding")
                        .font(.headline)
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
                    Text("Connection Failed")
                        .font(.headline)
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
                    Text("Troubleshooting:")
                        .font(.caption.bold())
                    Label("Verify WiFi is configured (SSID/password)",
                          systemImage: "wifi")
                        .font(.caption)
                    Label("Check device is powered on and in range",
                          systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                    Label("Try reconnecting or reconfiguring",
                          systemImage: "arrow.triangle.2.circlepath")
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

    // MARK: - Helpers

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
        }
    }
}

#Preview {
    HealthCheckTester(
        testInProgress: false,
        testResult: .success(reading: "50.0 cm @ 75%", timestamp: "5/30/26, 2:30 PM"),
        onTestTap: {}
    )
}
