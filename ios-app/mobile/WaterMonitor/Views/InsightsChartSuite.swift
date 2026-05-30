import SwiftUI
import Charts

/**
 * InsightsChartSuite — All data visualization charts for insights
 *
 * Displays:
 * - 7-day usage forecast (bar chart with avg reference line)
 * - Hourly consumption pattern (bar chart by time of day)
 * - Daily consumption trend (line + area chart for last 7 days)
 *
 * Isolated chart logic. Used in InsightsView.
 */
struct InsightsChartSuite: View {
    let engine: InsightsEngine

    var body: some View {
        VStack(spacing: 20) {
            forecastChart
            hourlyPatternChart
            consumptionTrendChart
        }
    }

    // MARK: - Forecast Chart

    private var forecastChart: some View {
        let forecast = engine.forecastNextWeek()
        let avgL = engine.averageDailyUsageL
        let today = Calendar.current.startOfDay(for: Date())

        let days: [(day: Date, vol: Double)] = forecast.enumerated().map { i, vol in
            let day = Calendar.current.date(byAdding: .day, value: i + 1, to: today)!
            return (day: day, vol: vol)
        }

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("7-Day Usage Forecast", icon: "wand.and.stars", tint: .indigo)
            Text("Predicted from your historical patterns using linear regression")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(days, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("L", item.vol)
                )
                .foregroundStyle(Color.indigo.opacity(0.7).gradient)

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

    // MARK: - Hourly Pattern Chart

    private var hourlyPatternChart: some View {
        let sortedHours: [(hour: Int, vol: Double)] = engine.hourlyDrain
            .sorted { $0.key < $1.key }
            .map { (hour: $0.key, vol: $0.value) }

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Usage by Time of Day", icon: "clock", tint: .purple)

            if sortedHours.isEmpty {
                emptyState("Not enough data yet")
            } else {
                Chart(sortedHours, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("L", item.vol)
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

    // MARK: - Consumption Trend Chart

    private var consumptionTrendChart: some View {
        let last7 = Array(engine.dailyUsage.suffix(7))

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Daily Consumption (7 days)", icon: "chart.line.uptrend.xyaxis", tint: .indigo)

            if last7.isEmpty {
                emptyState("Not enough historical data")
            } else {
                Chart(last7) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Volume", day.volumeL)
                    )
                    .foregroundStyle(Color.indigo)

                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
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

    // MARK: - Helpers

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

    InsightsChartSuite(engine: engine)
}
