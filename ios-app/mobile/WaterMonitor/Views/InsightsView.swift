import SwiftUI
import Charts
import SwiftData

struct InsightsView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext
    @State private var engine: InsightsEngine?
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            Group {
                if let engine {
                    insightContent(engine: engine)
                } else {
                    ProgressView("Analyzing data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await runAnalysis() } } label: {
                        if isAnalyzing { ProgressView().scaleEffect(0.8) }
                        else           { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isAnalyzing)
                }
            }
        }
        .onAppear {
            let e = InsightsEngine(context: modelContext)
            engine = e
            Task { await runAnalysis(engine: e) }
        }
    }

    // MARK: - Root content

    private func insightContent(engine: InsightsEngine) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if !engine.alerts.isEmpty { alertsSection(engine: engine) }
                predictionsSection(engine: engine)
                usageOverviewSection(engine: engine)
                forecastSection(engine: engine)
                hourlyPatternSection(engine: engine)
                fillEventsSection(engine: engine)
                consumptionTrendSection(engine: engine)
                if engine.estimatedFillsPerWeek > 0 { motorEstimatesSection(engine: engine) }
            }
            .padding()
        }
    }

    // MARK: - Predictions

    private func predictionsSection(engine: InsightsEngine) -> some View {
        let currentPct:  Int          = cm.displayStatus?.levelPct ?? 0
        let config:      DeviceConfig? = cm.config
        let drainRate:   Double       = engine.currentDrainRateLPerHour
        let emptyDate:   Date?        = engine.predictEmptyDate(currentPct: currentPct, config: config)
        let hoursLeft:   Double?      = engine.predictHoursToEmpty(currentPct: currentPct, config: config)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("AI Predictions", icon: "sparkles", tint: .purple)

            HStack(spacing: 12) {
                // Time to empty
                if let hours = hoursLeft {
                    let label: String = hours < 24
                        ? String(format: "%.0fh", hours)
                        : String(format: "%.1f days", hours / 24)
                    let urgent: Bool = hours < 12
                    statCard("Time to Low",
                             value: label,
                             icon: "exclamationmark.triangle",
                             tint: urgent ? .red : .orange)
                } else {
                    statCard("Time to Low", value: "--", icon: "exclamationmark.triangle", tint: .secondary)
                }

                // Drain rate
                let rateLabel: String = drainRate > 0
                    ? String(format: "%.0f L/hr", drainRate) : "--"
                statCard("Drain Rate", value: rateLabel, icon: "arrow.down.circle", tint: .blue)

                // Days until empty (absolute date)
                if let date = emptyDate {
                    let daysUntil: Int = Int(date.timeIntervalSinceNow / 86400)
                    statCard("Empty by",
                             value: daysUntil < 2
                                ? date.formatted(.dateTime.hour().minute())
                                : date.formatted(.dateTime.month(.abbreviated).day()),
                             icon: "calendar.badge.exclamationmark",
                             tint: daysUntil < 3 ? .red : .secondary)
                } else {
                    statCard("Empty by", value: "--", icon: "calendar.badge.exclamationmark", tint: .secondary)
                }
            }

            if drainRate == 0 {
                emptyState("Not enough drain events yet to make predictions. Come back after a few fill cycles.")
            }
        }
    }

    // MARK: - Forecast chart

    private func forecastSection(engine: InsightsEngine) -> some View {
        let forecast: [Double] = engine.forecastNextWeek()
        let avgL:     Double   = engine.averageDailyUsageL
        let today:    Date     = Calendar.current.startOfDay(for: Date())

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("7-Day Usage Forecast", icon: "wand.and.stars", tint: .indigo)
            Text("Predicted from your historical patterns using linear regression")
                .font(.caption)
                .foregroundStyle(.secondary)

            let days: [(day: Date, vol: Double)] = forecast.enumerated().map { i, vol in
                let day = Calendar.current.date(byAdding: .day, value: i + 1, to: today)!
                return (day: day, vol: vol)
            }

            Chart(days, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("L",   item.vol)
                )
                .foregroundStyle(Color.indigo.opacity(0.7).gradient)

                // Historical average reference line
                RuleMark(y: .value("Avg", avgL))
                    .foregroundStyle(Color.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .trailing) {
                        Text("avg")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0) L") }
                    AxisGridLine()
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Alerts

    private func alertsSection(engine: InsightsEngine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Alerts", icon: "bell.badge.fill", tint: .red)
            ForEach(engine.alerts) { alert in alertCard(alert) }
        }
    }

    // MARK: - Usage overview

    private func usageOverviewSection(engine: InsightsEngine) -> some View {
        let todayLabel: String = engine.dailyUsage.last.map { String(format: "%.0f L", $0.volumeL) } ?? "--"
        let avgLabel:   String = engine.averageDailyUsageL > 0 ? String(format: "%.0f L", engine.averageDailyUsageL) : "--"
        let trendLabel: String = engine.weeklyTrend != 0 ? String(format: "%+.0f%%", engine.weeklyTrend) : "—"
        let trendIcon:  String = engine.weeklyTrend >= 0 ? "arrow.up.right" : "arrow.down.right"
        let trendTint:  Color  = engine.weeklyTrend > 10 ? .orange : (engine.weeklyTrend < -5 ? .green : .secondary)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Usage Overview", icon: "drop.fill", tint: .blue)

            HStack(spacing: 12) {
                statCard("Today",     value: todayLabel, icon: "calendar",       tint: .blue)
                statCard("Daily Avg", value: avgLabel,   icon: "chart.bar.fill", tint: .teal)
                statCard("Trend",     value: trendLabel, icon: trendIcon,        tint: trendTint)
            }

            if let peakHour = engine.peakUsageHour {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill").foregroundStyle(.orange)
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

    // MARK: - Hourly pattern chart

    private func hourlyPatternSection(engine: InsightsEngine) -> some View {
        // Pre-compute sorted pairs before entering view builder
        let sortedHours: [(hour: Int, vol: Double)] = engine.hourlyDrain
            .sorted { $0.key < $1.key }
            .map    { (hour: $0.key, vol: $0.value) }

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Usage by Time of Day", icon: "clock", tint: .purple)

            if sortedHours.isEmpty {
                emptyState("Not enough data yet")
            } else {
                Chart(sortedHours, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("L",    item.vol)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { val in
                        AxisValueLabel { Text(hourLabel(val.as(Int.self) ?? 0)) }
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisValueLabel { Text("\(v.as(Int.self) ?? 0) L") }
                        AxisGridLine()
                    }
                }
                .frame(height: 180)
                .overlay(alignment: .bottomLeading) {
                    // Peak hour annotation outside chart builder
                    if let peak = sortedHours.max(by: { $0.vol < $1.vol }) {
                        Text("Peak: \(hourLabel(peak.hour))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Fill events

    private func fillEventsSection(engine: InsightsEngine) -> some View {
        let recent: [FillEvent] = Array(engine.fillEvents.suffix(5).reversed())

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Recent Fill Events", icon: "arrow.up.circle.fill", tint: .green)

            if recent.isEmpty {
                emptyState("No fill events detected yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { fill in
                        fillEventRow(fill)
                        Divider().padding(.leading)
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Consumption trend

    private func consumptionTrendSection(engine: InsightsEngine) -> some View {
        let last7: [DailyUsage] = Array(engine.dailyUsage.suffix(7))

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Daily Consumption (7 days)", icon: "chart.line.uptrend.xyaxis", tint: .indigo)

            if last7.isEmpty {
                emptyState("Not enough historical data")
            } else {
                Chart(last7) { day in
                    LineMark(
                        x: .value("Day",    day.date,    unit: .day),
                        y: .value("Volume", day.volumeL)
                    )
                    .foregroundStyle(Color.indigo)
                    AreaMark(
                        x: .value("Day",    day.date,    unit: .day),
                        y: .value("Volume", day.volumeL)
                    )
                    .foregroundStyle(Color.indigo.opacity(0.12))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisValueLabel { Text("\(v.as(Int.self) ?? 0) L") }
                        AxisGridLine()
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Motor estimates

    private func motorEstimatesSection(engine: InsightsEngine) -> some View {
        let fillsPerWeek: String = String(format: "%.0f", engine.estimatedFillsPerWeek)
        let avgDuration:  String = engine.avgFillDurationMinutes > 0
            ? String(format: "%.0f min", engine.avgFillDurationMinutes) : "--"
        let estKwh:       String = engine.avgFillDurationMinutes > 0
            ? String(format: "%.2f", engine.avgFillDurationMinutes / 60.0 * 0.75) : "--"

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Pump Estimates", icon: "bolt.fill", tint: .orange)
            Text("Based on fill event durations (exact data requires motor controller)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statCard("Fills/Week",   value: fillsPerWeek, icon: "repeat", tint: .orange)
                statCard("Avg Duration", value: avgDuration,  icon: "timer",  tint: .orange)
                statCard("Est. kWh",     value: estKwh,       icon: "bolt",   tint: .yellow)
            }
            Text("Energy estimated at 0.75 kW. Set actual wattage in device settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Reusable components

    private func alertCard(_ alert: InsightAlert) -> some View {
        let isCritical: Bool  = alert.severity == .critical
        let tintColor:  Color = isCritical ? .red : .orange

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
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func fillEventRow(_ fill: FillEvent) -> some View {
        let summary: String = String(format: "%d%%→%d%%  %.0f L  %.0f min",
                                     fill.startPct, fill.peakPct, fill.volumeL, fill.durationMinutes)
        return HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(fill.startTime, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline)
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).font(.headline)
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
        let h: Int = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }

    // MARK: - Analysis

    @MainActor
    private func runAnalysis(engine: InsightsEngine? = nil) async {
        let e = engine ?? self.engine
        guard let e else { return }
        isAnalyzing = true
        let nodeID: String = cm.config?.nodeID ?? ""
        let config: DeviceConfig? = cm.config
        // InsightsEngine is @Observable (main-actor-bound) — call directly.
        // SwiftData ModelContext is also main-actor-only, so background dispatch isn't possible here.
        e.analyze(nodeID: nodeID, config: config)
        isAnalyzing = false
        NotificationService.shared.scheduleAlerts(e.alerts)
    }
}
