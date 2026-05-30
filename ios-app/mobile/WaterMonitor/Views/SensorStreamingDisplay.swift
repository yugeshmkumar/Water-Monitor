import SwiftUI

/**
 * SensorStreamingDisplay — Real-time sensor data visualization
 *
 * Displays:
 * - Current distance reading (live, updates frequently)
 * - Stability score (5-bar indicator, measures consistency)
 * - Tank fullness slider (0-100%, user adjusts to calibrate)
 * - Quick reference buttons (Empty 0%, Half 50%, Full 100%)
 *
 * Used during quick calibration to guide user through recording points.
 */
struct SensorStreamingDisplay: View {
    let currentReading: Double
    let stabilityScore: Int
    let currentPercent: Int
    let onPercentChanged: (Int) -> Void
    let onRecordPoint: () -> Void
    let onSetEmpty: () -> Void
    let onSetHalf: () -> Void
    let onSetFull: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Live distance reading
            distanceDisplay

            // Stability indicator
            stabilityIndicator

            // Tank percentage slider
            percentageControl

            // Quick buttons
            quickButtons

            // Record button
            recordButton
        }
    }

    // MARK: - Subviews

    private var distanceDisplay: some View {
        VStack(spacing: 12) {
            Text("Current Distance")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", currentReading))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                Text("cm")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var stabilityIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Reading Stability")
                    .font(.subheadline.bold())
                Spacer()
                stabilityBadge
            }

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < stabilityScore ? Color.green : Color.gray.opacity(0.3))
                        .frame(height: 8)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var stabilityBadge: some View {
        Group {
            if stabilityScore < 2 {
                Text("Unstable").font(.caption).foregroundStyle(.red)
            } else if stabilityScore < 4 {
                Text("Fair").font(.caption).foregroundStyle(.orange)
            } else {
                Text("Stable").font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var percentageControl: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tank Fullness")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(currentPercent)%")
                    .font(.headline.monospaced())
                    .foregroundStyle(.blue)
            }

            Slider(
                value: Binding(
                    get: { Double(currentPercent) },
                    set: { onPercentChanged(Int($0)) }
                ),
                in: 0...100,
                step: 1
            )
            .tint(.blue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var quickButtons: some View {
        HStack(spacing: 12) {
            Button("Empty (0%)") { onSetEmpty() }
                .font(.caption)
                .buttonStyle(.bordered)

            Button("Half (50%)") { onSetHalf() }
                .font(.caption)
                .buttonStyle(.bordered)

            Button("Full (100%)") { onSetFull() }
                .font(.caption)
                .buttonStyle(.bordered)
        }
    }

    private var recordButton: some View {
        Button(action: onRecordPoint) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Record Point")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.white)
            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    SensorStreamingDisplay(
        currentReading: 87.5,
        stabilityScore: 4,
        currentPercent: 50,
        onPercentChanged: { _ in },
        onRecordPoint: {},
        onSetEmpty: {},
        onSetHalf: {},
        onSetFull: {}
    )
    .padding()
}
