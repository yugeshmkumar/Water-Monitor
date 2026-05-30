import SwiftUI
import Charts

/**
 * HistoryLevelChart — Time-series water level visualization
 *
 * Displays:
 * - Water level line chart (blue line with area fill)
 * - Sensor error points (orange dots)
 * - Y-axis: 0-100% in 25% increments
 * - X-axis: Time labels (hour/minute or weekday.hour)
 * - Legend showing what each color means
 *
 * Isolated chart logic. Used in HistoryView.
 */
struct HistoryLevelChart: View {
    let readings: [DeviceReading]
    let axisFormat: Date.FormatStyle

    var body: some View {
        let validReadings = readings.filter { $0.sensorOk }
        let errorReadings = readings.filter { !$0.sensorOk }
        let hasErrors = !errorReadings.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            // Legend
            HStack(spacing: 16) {
                legendDot(.blue, "Water Level")
                if hasErrors {
                    legendDot(.orange, "Sensor Error")
                }
            }

            // Chart
            if validReadings.isEmpty && errorReadings.isEmpty {
                Text("No readings available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Valid readings: line + area
                    ForEach(validReadings) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Level %", reading.levelPct)
                        )
                        .foregroundStyle(Color.blue)

                        AreaMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Level %", reading.levelPct)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1))
                    }

                    // Error readings: point marks
                    ForEach(errorReadings) { reading in
                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Level %", reading.levelPct)
                        )
                        .foregroundStyle(Color.orange)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: axisFormat)
                    }
                }
                .frame(height: 240)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let sampleReadings = [
        DeviceReading(timestamp: Date(), levelPct: 50, distanceCM: 100, sensorOk: true, nodeID: "test"),
        DeviceReading(timestamp: Date().addingTimeInterval(3600), levelPct: 55, distanceCM: 95, sensorOk: true, nodeID: "test"),
        DeviceReading(timestamp: Date().addingTimeInterval(7200), levelPct: 45, distanceCM: 110, sensorOk: true, nodeID: "test"),
    ]

    HistoryLevelChart(
        readings: sampleReadings,
        axisFormat: .dateTime.hour().minute()
    )
    .padding()
}
