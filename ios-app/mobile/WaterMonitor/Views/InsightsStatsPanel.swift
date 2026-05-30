import SwiftUI

/**
 * InsightsStatsPanel — Statistics, alerts, and pump estimates
 *
 * Displays:
 * - Alerts (if any, at top)
 * - Usage overview (today, daily avg, trend, peak hour)
 * - Recent fill events (last 5 with details)
 * - Pump/motor estimates (fills/week, duration, kWh estimate)
 *
 * Isolated stats display. Used in InsightsView.
 */
struct InsightsStatsPanel: View {
    let engine: InsightsEngine

    var body: some View {
        VStack(spacing: 20) {
            if !engine.alerts.isEmpty {
                alertsSection
            }

            usageOverviewSection
            fillEventsSection
            if engine.estimatedFillsPerWeek > 0 {
                motorEstimatesSection
            }
        }
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Alerts", icon: "bell.badge.fill", tint: .red)
            ForEach(engine.alerts) { alert in
                alertCard(alert)
            }
        }
    }

    // MARK: - Usage Overview Section

    private var usageOverviewSection: some View {
        let todayLabel = engine.dailyUsage.last.map { String(format: "%.0f L", $0.volumeL) } ?? "--"
        let avgLabel = engine.averageDailyUsageL > 0
            ? String(format: "%.0f L", engine.averageDailyUsageL)
            : "--"
        let trendLabel = engine.weeklyTrend != 0
            ? String(format: "%+.0f%%", engine.weeklyTrend)
            : "—"
        let trendIcon = engine.weeklyTrend >= 0 ? "arrow.up.right" : "arrow.down.right"
        let trendTint: Color = engine.weeklyTrend > 10
            ? .orange
            : (engine.weeklyTrend < -5 ? .green : .secondary)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Usage Overview", icon: "drop.fill", tint: .blue)

            HStack(spacing: 12) {
                statCard("Today", value: todayLabel, icon: "calendar", tint: .blue)
                statCard("Daily Avg", value: avgLabel, icon: "chart.bar.fill", tint: .teal)
                statCard("Trend", value: trendLabel, icon: trendIcon, tint: trendTint)
            }

            if let peakHour = engine.peakUsageHour {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                    Text("Peak usage: \(hourLabel(peakHour))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Fill Events Section

    private var fillEventsSection: some View {
        let recent = Array(engine.fillEvents.suffix(5).reversed())

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Fill Events", icon: "arrow.up.circle.fill", tint: .green)

            if recent.isEmpty {
                emptyState("No fill events detected yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { fill in
                        fillEventRow(fill)
                        Divider()
                            .padding(.leading)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Motor Estimates Section

    private var motorEstimatesSection: some View {
        let fillsPerWeek = String(format: "%.0f", engine.estimatedFillsPerWeek)
        let avgDuration = engine.avgFillDurationMinutes > 0
            ? String(format: "%.0f min", engine.avgFillDurationMinutes)
            : "--"
        let estKwh = engine.avgFillDurationMinutes > 0
            ? String(format: "%.2f", engine.avgFillDurationMinutes / 60.0 * 0.75)
            : "--"

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Pump Estimates", icon: "bolt.fill", tint: .orange)
            Text("Based on fill event durations (exact data requires motor controller)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statCard("Fills/Week", value: fillsPerWeek, icon: "repeat", tint: .orange)
                statCard("Avg Duration", value: avgDuration, icon: "timer", tint: .orange)
                statCard("Est. kWh", value: estKwh, icon: "bolt", tint: .yellow)
            }

            Text("Energy estimated at 0.75 kW. Set actual wattage in device settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func alertCard(_ alert: InsightAlert) -> some View {
        let isCritical = alert.severity == .critical
        let tintColor = isCritical ? Color.red : Color.orange

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.severity.systemImage)
                .foregroundStyle(tintColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.bold())
                Text(alert.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(tintColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tintColor.opacity(0.3), lineWidth: 1))
    }

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

    private func fillEventRow(_ fill: FillEvent) -> some View {
        let summary = String(format: "%d%%→%d%%  %.0f L  %.0f min",
                             fill.startPct, fill.peakPct, fill.volumeL, fill.durationMinutes)

        return HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(fill.startTime, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}

#Preview {
    let engine = InsightsEngine(context: ModelContext(ModelContainer(for: SavedDevice.self, configurations: [])))

    InsightsStatsPanel(engine: engine)
        .padding()
}
