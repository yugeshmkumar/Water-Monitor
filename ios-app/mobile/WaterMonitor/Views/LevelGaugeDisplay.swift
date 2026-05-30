import SwiftUI

/**
 * LevelGaugeDisplay — Animated circular water level gauge
 *
 * Displays:
 * - Large circular progress gauge (0-100%)
 * - Percentage in center
 * - Sensor status (OK or error)
 * - Distance from sensor
 * - Alert indicators (low/high level)
 * - Color-coded by alert state (blue normal, red low, orange high)
 *
 * Isolated gauge display. Used in DashboardView.
 */
struct LevelGaugeDisplay: View {
    let levelPct: Int
    let sensorOk: Bool
    let distanceCM: Double
    let isLow: Bool
    let isHigh: Bool
    let gaugeColor: Color

    var body: some View {
        VStack(spacing: 8) {
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
            .frame(width: 210, height: 210)

            // Sensor status
            if !sensorOk {
                Label("No sensor signal (showing last valid reading)",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if distanceCM > 0 {
                Text(String(format: "%.1f cm from sensor", distanceCM))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Alert indicators
            if isLow {
                Label("Low water level", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if isHigh {
                Label("Tank nearly full", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    LevelGaugeDisplay(
        levelPct: 75,
        sensorOk: true,
        distanceCM: 50.0,
        isLow: false,
        isHigh: false,
        gaugeColor: .blue
    )
    .padding()
}
