import SwiftUI

/**
 * CalibrationResultsDisplay — Show calibration results
 *
 * Displays:
 * - Detected empty distance (cm)
 * - Detected full distance (cm)
 * - Estimated tank capacity
 * - Confidence indicator
 * - Options to confirm or retry calibration
 *
 * Isolated results display. Called after quick calibration completes.
 */
struct CalibrationResultsDisplay: View {
    let emptyDistance: Double
    let fullDistance: Double
    let readingCount: Int
    let onConfirm: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection

            // Results cards
            resultCards

            // Tank estimate
            estimateSection

            // Confidence info
            confidenceSection

            // Action buttons
            actionButtons

            Spacer()
        }
        .padding()
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Calibration Complete")
                .font(.headline)

            Text("Detected empty and full positions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultCards: some View {
        HStack(spacing: 16) {
            resultCard(
                title: "Empty",
                value: String(format: "%.1f", emptyDistance),
                unit: "cm",
                color: .red
            )

            resultCard(
                title: "Full",
                value: String(format: "%.1f", fullDistance),
                unit: "cm",
                color: .blue
            )
        }
    }

    private func resultCard(
        title: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private var estimateSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Estimated Tank Capacity")
                    .font(.subheadline.bold())
                Spacer()
                Text(capacityEstimate)
                    .font(.headline.monospaced())
                    .foregroundStyle(.blue)
            }

            ProgressView(
                value: min(capacityValue / 1000.0, 1.0)
            )
            .tint(.blue)

            Text("Total height: \(String(format: "%.0f", heightDifference)) cm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var confidenceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Calibration Quality")
                    .font(.caption.bold())

                Text("\(readingCount) readings collected. AI filtering removed spikes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onConfirm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm & Save")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Recalibrate")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.blue)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var heightDifference: Double {
        abs(fullDistance - emptyDistance)
    }

    private var capacityValue: Double {
        heightDifference * 10  // Rough estimate: height * cross-section
    }

    private var capacityEstimate: String {
        let capacity = capacityValue
        if capacity < 100 {
            return String(format: "%.0f cm³", capacity)
        } else if capacity < 1000 {
            return String(format: "%.1f L", capacity / 1000)
        } else {
            return String(format: "%.0f L", capacity / 1000)
        }
    }
}

#Preview {
    CalibrationResultsDisplay(
        emptyDistance: 200.0,
        fullDistance: 15.0,
        readingCount: 47,
        onConfirm: { print("Confirmed") },
        onRetry: { print("Retry") }
    )
    .padding()
}
