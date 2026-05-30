import SwiftUI

/**
 * HistoryStatsTable — Summary statistics and recent readings
 *
 * Displays:
 * - Stats row: average, min, max level, sample count
 * - Recent readings: last 20 readings in reverse chronological order
 * - Shows timestamp, percentage, distance, or error indicator
 * - Dividers between readings for clarity
 *
 * Isolated stats display. Used in HistoryView.
 */
struct HistoryStatsTable: View {
    let readings: [DeviceReading]

    var body: some View {
        VStack(spacing: 20) {
            statsRow
            readingsTable
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let validReadings = readings.filter { $0.sensorOk }
        let total = validReadings.reduce(0) { $0 + $1.levelPct }
        let average = validReadings.isEmpty ? 0 : total / validReadings.count
        let minValue = validReadings.map(\.levelPct).min() ?? 0
        let maxValue = validReadings.map(\.levelPct).max() ?? 0
        let count = validReadings.count

        return HStack(spacing: 0) {
            statPill("Avg", "\(average)%")
            Divider()
                .frame(height: 40)
            statPill("Min", "\(minValue)%")
            Divider()
                .frame(height: 40)
            statPill("Max", "\(maxValue)%")
            Divider()
                .frame(height: 40)
            statPill("Samples", "\(count)")
        }
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Readings Table

    private var readingsTable: some View {
        let recent = Array(readings.suffix(20).reversed())

        return VStack(alignment: .leading, spacing: 0) {
            Text("Recent Readings")
                .font(.headline)
                .padding(.bottom, 8)

            if recent.isEmpty {
                Text("No readings yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(recent) { reading in
                    readingRow(reading)
                    Divider()
                }
            }
        }
    }

    // MARK: - Helpers

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func readingRow(_ reading: DeviceReading) -> some View {
        HStack {
            // Timestamp
            Text(reading.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            // Data or error indicator
            if reading.sensorOk {
                HStack(spacing: 8) {
                    Text("\(reading.levelPct)%")
                        .font(.caption.bold())
                    Text(String(format: "%.1f cm", reading.distanceCM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("No signal", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    let sampleReadings = [
        DeviceReading(timestamp: Date().addingTimeInterval(-3600), levelPct: 50, distanceCM: 100, sensorOk: true, nodeID: "test"),
        DeviceReading(timestamp: Date().addingTimeInterval(-1800), levelPct: 55, distanceCM: 95, sensorOk: true, nodeID: "test"),
        DeviceReading(timestamp: Date(), levelPct: 45, distanceCM: 110, sensorOk: true, nodeID: "test"),
    ]

    HistoryStatsTable(readings: sampleReadings)
        .padding()
}
