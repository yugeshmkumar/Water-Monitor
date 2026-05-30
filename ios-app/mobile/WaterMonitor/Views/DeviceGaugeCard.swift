import SwiftUI

/**
 * DeviceGaugeCard — Circular water level gauge with status indicators
 *
 * Displays:
 * - Animated circular progress gauge (0-100%)
 * - Percentage text in center
 * - Sensor signal status (OK or error)
 * - Distance from sensor (if available)
 * - Alert indicators (low/high level warnings)
 * - Color-coded by alert status (blue normal, red low, orange high)
 *
 * Isolated gauge display. Used in DeviceDetailView and dashboards.
 */
struct DeviceGaugeCard: View {
    let levelPct: Int
    let sensorOk: Bool
    let distanceCM: Double
    let gaugeColor: Color
    let alertConfig: (lowPct: Int, highPct: Int)?

    var body: some View {
        VStack(spacing: 12) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: Double(levelPct) / 100.0)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: levelPct)

                VStack(spacing: 0) {
                    Text("\(levelPct)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            // Sensor status
            sensorStatusView

            // Alert indicators
            alertIndicators
        }
    }

    // MARK: - Subviews

    private var sensorStatusView: some View {
        Group {
            if !sensorOk {
                Label("No sensor signal — showing last valid reading",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else if distanceCM > 0 {
                Text(String(format: "%.1f cm from sensor", distanceCM))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var alertIndicators: some View {
        if let config = alertConfig {
            if levelPct <= config.lowPct {
                Label("Low water level", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if levelPct >= config.highPct {
                Label("Tank nearly full", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    DeviceGaugeCard(
        levelPct: 75,
        sensorOk: true,
        distanceCM: 50.0,
        gaugeColor: .blue,
        alertConfig: (lowPct: 20, highPct: 80)
    )
    .padding()
}
