import SwiftUI

/**
 * DashboardStatusBar — Connection and test mode controls
 *
 * Displays:
 * - Connection badge (WiFi/Bluetooth/Offline indicator)
 * - Test mode toggle with indicator
 *
 * Isolated status display. Used in DashboardView.
 */
struct DashboardStatusBar: View {
    let transport: Transport
    let testMode: Bool
    let onTestModeToggle: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Connection badge
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

            // Test mode toggle
            HStack {
                Image(systemName: testMode
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(testMode ? .green : .secondary)

                Toggle("Test Mode (3s polling)", isOn: Binding(
                    get: { testMode },
                    set: { onTestModeToggle($0) }
                ))
                .toggleStyle(.switch)
            }
            .font(.subheadline)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private var transportColor: Color {
        switch transport {
        case .wifi: return .green
        case .ble: return .blue
        case .none: return .gray
        }
    }

    private var transportLabel: String {
        switch transport {
        case .wifi: return "WiFi"
        case .ble: return "Bluetooth"
        case .none: return "Offline"
        }
    }
}

#Preview {
    DashboardStatusBar(
        transport: .wifi,
        testMode: false,
        onTestModeToggle: { _ in }
    )
    .padding()
}
