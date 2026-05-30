import SwiftUI

/**
 * CalibrationModeSelector — Choose calibration method
 *
 * Presents two options for tank calibration:
 * - Quick Calibration (5 minutes): User-guided, real-time sensor streaming
 * - Auto Calibration (24-48 hours): Background detection of min/max levels
 *
 * User selects their preferred method; TankCalibrationView coordinates the flow.
 */
struct CalibrationModeSelector: View {
    var onQuickSelected: () -> Void
    var onAutoSelected: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Calibration Method")
                .font(.headline)
                .padding(.top, 24)

            VStack(spacing: 12) {
                modeCard(
                    title: "Quick Calibration",
                    subtitle: "5 minutes",
                    description: "Move water level to different heights. App learns from real readings with AI filtering.",
                    icon: "timer.circle.fill",
                    color: .blue,
                    action: onQuickSelected
                )

                modeCard(
                    title: "Auto Calibration",
                    subtitle: "24-48 hours",
                    description: "Device watches naturally and detects min/max automatically. AI improves accuracy over cycles.",
                    icon: "moon.stars.fill",
                    color: .indigo,
                    action: onAutoSelected
                )
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func modeCard(
        title: String,
        subtitle: String,
        description: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.primary)
        }
    }
}

#Preview {
    CalibrationModeSelector(
        onQuickSelected: { print("Quick") },
        onAutoSelected: { print("Auto") }
    )
    .padding()
}
