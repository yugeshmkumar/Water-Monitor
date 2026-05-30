import SwiftUI

/**
 * InsightsPredictionCard — AI-powered tank level predictions
 *
 * Displays:
 * - Time to empty (hours or days)
 * - Current drain rate (L/hour)
 * - Absolute date when tank will be empty
 * - Color-coded urgency (red < 12h, orange < critical)
 *
 * Isolated prediction logic. Used in InsightsView and dashboards.
 */
struct InsightsPredictionCard: View {
    let engine: InsightsEngine
    let currentPct: Int
    let config: DeviceConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("AI Predictions", icon: "sparkles", tint: .purple)

            HStack(spacing: 12) {
                timeToEmptyCard
                drainRateCard
                emptyDateCard
            }

            if drainRate == 0 {
                emptyStateMessage
            }
        }
    }

    // MARK: - Subviews

    private var timeToEmptyCard: some View {
        Group {
            if let hours = hoursToEmpty {
                let label = hours < 24
                    ? String(format: "%.0fh", hours)
                    : String(format: "%.1f days", hours / 24)
                let urgent = hours < 12

                statCard(
                    "Time to Low",
                    value: label,
                    icon: "exclamationmark.triangle",
                    tint: urgent ? .red : .orange
                )
            } else {
                statCard(
                    "Time to Low",
                    value: "--",
                    icon: "exclamationmark.triangle",
                    tint: .secondary
                )
            }
        }
    }

    private var drainRateCard: some View {
        let rateLabel = drainRate > 0
            ? String(format: "%.0f L/hr", drainRate)
            : "--"

        return statCard(
            "Drain Rate",
            value: rateLabel,
            icon: "arrow.down.circle",
            tint: .blue
        )
    }

    private var emptyDateCard: some View {
        Group {
            if let date = emptyDate {
                let daysUntil = Int(date.timeIntervalSinceNow / 86400)
                let label = daysUntil < 2
                    ? date.formatted(.dateTime.hour().minute())
                    : date.formatted(.dateTime.month(.abbreviated).day())

                statCard(
                    "Empty by",
                    value: label,
                    icon: "calendar.badge.exclamationmark",
                    tint: daysUntil < 3 ? .red : .secondary
                )
            } else {
                statCard(
                    "Empty by",
                    value: "--",
                    icon: "calendar.badge.exclamationmark",
                    tint: .secondary
                )
            }
        }
    }

    private var emptyStateMessage: some View {
        Text("Not enough drain events yet to make predictions. Come back after a few fill cycles.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    // MARK: - Computed Properties

    private var drainRate: Double {
        engine.currentDrainRateLPerHour
    }

    private var hoursToEmpty: Double? {
        engine.predictHoursToEmpty(currentPct: currentPct, config: config)
    }

    private var emptyDate: Date? {
        engine.predictEmptyDate(currentPct: currentPct, config: config)
    }

    // MARK: - Helpers

    private func statCard(_ label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
        }
    }
}

#Preview {
    let engine = InsightsEngine(context: ModelContext(ModelContainer(for: SavedDevice.self, configurations: [])))

    InsightsPredictionCard(
        engine: engine,
        currentPct: 75,
        config: nil
    )
    .padding()
}
