import SwiftUI

/**
 * HealthCheckStatus — Device connection status display
 *
 * Displays:
 * - BLE connection status (Active/Inactive)
 * - WiFi configuration status (Configured/Not Set)
 * - Last reading time
 * - Signal strength (RSSI dBm)
 *
 * Isolated status display. Used in DeviceHealthCheckView.
 */
struct HealthCheckStatus: View {
    let isBLEConnected: Bool
    let wifiConfigured: Bool
    let lastReadingTime: Date?
    let rssi: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                statusRow("BLE", isBLEConnected ? "Active" : "Inactive")
                statusRow("WiFi", wifiConfigured ? "Configured" : "Not Set")

                if let lastTime = lastReadingTime {
                    statusRow("Last Reading", formatTime(lastTime))
                } else {
                    statusRow("Last Reading", "Never")
                }

                if let signal = rssi, signal != 0 {
                    statusRow("Signal (dBm)", "\(signal)")
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospaced())
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HealthCheckStatus(
        isBLEConnected: true,
        wifiConfigured: true,
        lastReadingTime: Date(),
        rssi: -65
    )
}
