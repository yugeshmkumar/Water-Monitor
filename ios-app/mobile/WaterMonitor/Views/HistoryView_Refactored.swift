import SwiftUI
import SwiftData

/**
 * HistoryView (Refactored) — Orchestrates history time-series view
 *
 * Coordinator pattern: manages state and flow across 3 focused components:
 * - HistoryDevicePicker: Select device/nodeID to view
 * - HistoryLevelChart: Time-series water level visualization
 * - HistoryStatsTable: Summary stats and recent readings
 *
 * REFACTORING NOTE: Phase 4c extracted multi-device filtering and charts.
 * This view reduced from 244 lines to 70 lines (coordinator only).
 * All UI components now isolated and reusable. Data flow simplified.
 */
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
                if savedDevices.count > 1 {
                    HistoryDevicePicker(
                        savedDevices: savedDevices,
                        selectedNodeID: $selectedNodeID,
                        onSelectionChanged: fetchReadings
                    )
                }

                mainContent
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }
        }
        .onAppear { setup() }
        .onChange(of: range) { _, _ in fetchReadings() }
        .onChange(of: selectedNodeID) { _, _ in fetchReadings() }
    }

    // MARK: - Content Layout

    @ViewBuilder
    private var mainContent: some View {
        if readings.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.line.downtrend.xyaxis",
                description: Text("Readings will appear here once the sensor is active.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HistoryLevelChart(
                        readings: readings,
                        axisFormat: axisFormat
                    )

                    HistoryStatsTable(readings: readings)
                        .padding()
                }
                .padding()
            }
        }
    }

    // MARK: - Data Management

    private var axisFormat: Date.FormatStyle {
        switch range {
        case .day:
            return .dateTime.hour().minute()
        case .week:
            return .dateTime.weekday(.abbreviated).hour()
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
        let since = Date().addingTimeInterval(-range.lookback)
        let nodeID: String? = selectedNodeID.isEmpty ? nil : selectedNodeID
        readings = cache.readings(since: since, nodeID: nodeID)
    }
}

#Preview {
    let container = try! ModelContainer(for: SavedDevice.self, configurations: [])

    HistoryView()
        .environment(ConnectionManager())
        .modelContainer(container)
}
