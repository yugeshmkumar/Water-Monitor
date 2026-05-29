import SwiftUI
import Charts
import SwiftData

struct HistoryView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext
    @Query private var savedDevices: [SavedDevice]

    @State private var range: HistoryRange = .day
    @State private var selectedNodeID: String = ""
    @State private var readings: [DeviceReading] = []
    @State private var cache: DataCache?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if savedDevices.count > 1 { devicePicker }
                mainContent
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
        }
        .onAppear { setup() }
        .onChange(of: range)          { _, _ in fetchReadings() }
        .onChange(of: selectedNodeID) { _, _ in fetchReadings() }
    }

    // MARK: - Device picker

    private var devicePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                deviceChip("All", id: "")
                ForEach(savedDevices) { d in deviceChip(d.displayName, id: d.nodeID) }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    private func deviceChip(_ label: String, id: String) -> some View {
        let isSelected: Bool  = selectedNodeID == id
        let strokeWidth: CGFloat = isSelected ? 0 : 1
        return Button { selectedNodeID = id } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.clear, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(Capsule().stroke(.secondary.opacity(0.3), lineWidth: strokeWidth))
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if readings.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.line.downtrend.xyaxis",
                description: Text("Readings will appear here once the sensor is active.")
            )
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                levelChartSection
                statsRow
                readingsTable
            }
            .padding()
        }
    }

    // MARK: - Chart

    private var levelChartSection: some View {
        let validReadings:  [DeviceReading] = readings.filter { $0.sensorOk }
        let errorReadings:  [DeviceReading] = readings.filter { !$0.sensorOk }
        let hasErrors:      Bool = !errorReadings.isEmpty
        let xFormat:        Date.FormatStyle = axisFormat

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                legendDot(.blue, "Water Level")
                if hasErrors { legendDot(.orange, "Sensor Error") }
            }

            Chart {
                ForEach(validReadings) { r in
                    LineMark(
                        x: .value("Time",    r.timestamp),
                        y: .value("Level %", r.levelPct)
                    )
                    .foregroundStyle(Color.blue)

                    AreaMark(
                        x: .value("Time",    r.timestamp),
                        y: .value("Level %", r.levelPct)
                    )
                    .foregroundStyle(Color.blue.opacity(0.1))
                }
                ForEach(errorReadings) { r in
                    PointMark(
                        x: .value("Time",    r.timestamp),
                        y: .value("Level %", r.levelPct)
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                    AxisGridLine()
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%") }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xFormat)
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let valid:   [DeviceReading] = readings.filter { $0.sensorOk }
        let total:   Int = valid.reduce(0) { $0 + $1.levelPct }
        let avg:     Int = valid.isEmpty ? 0 : total / valid.count
        let minVal:  Int = valid.map(\.levelPct).min() ?? 0
        let maxVal:  Int = valid.map(\.levelPct).max() ?? 0
        let count:   Int = valid.count

        return HStack(spacing: 0) {
            statPill("Avg",     "\(avg)%")
            Divider().frame(height: 40)
            statPill("Min",     "\(minVal)%")
            Divider().frame(height: 40)
            statPill("Max",     "\(maxVal)%")
            Divider().frame(height: 40)
            statPill("Samples", "\(count)")
        }
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Readings table

    private var readingsTable: some View {
        let recent: [DeviceReading] = Array(readings.suffix(20).reversed())

        return VStack(alignment: .leading, spacing: 0) {
            Text("Recent Readings")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(recent) { r in
                HStack {
                    Text(r.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if r.sensorOk {
                        let pctText: String = "\(r.levelPct)%"
                        let cmText:  String = String(format: "  %.1f cm", r.distanceCM)
                        Text(pctText).font(.caption.bold())
                        Text(cmText).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("No signal", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    // MARK: - Reusable

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private var axisFormat: Date.FormatStyle {
        switch range {
        case .day:  return .dateTime.hour().minute()
        case .week: return .dateTime.weekday(.abbreviated).hour()
        }
    }

    private func setup() {
        let c = DataCache(context: modelContext)
        cache = c
        if selectedNodeID.isEmpty {
            selectedNodeID = cm.config?.nodeID ?? savedDevices.first?.nodeID ?? ""
        }
        fetchReadings()
    }

    private func fetchReadings() {
        guard let cache else { return }
        let since: Date   = Date().addingTimeInterval(-range.lookback)
        let nodeID: String? = selectedNodeID.isEmpty ? nil : selectedNodeID
        readings = cache.readings(since: since, nodeID: nodeID)
    }
}
