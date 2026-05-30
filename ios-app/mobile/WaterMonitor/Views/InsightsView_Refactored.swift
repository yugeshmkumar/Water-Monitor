import SwiftUI
import SwiftData

/**
 * InsightsView (Refactored) — Orchestrates insights analysis
 *
 * Coordinator pattern: manages state and flow across 3 focused components:
 * - InsightsPredictionCard: Time-to-empty, drain rate, empty date predictions
 * - InsightsChartSuite: All charts (forecast, hourly patterns, trends)
 * - InsightsStatsPanel: Alerts, usage overview, fill events, pump estimates
 *
 * REFACTORING NOTE: Phase 4b extracted complex UI into 3 services.
 * This view reduced from 426 lines to 75 lines (coordinator only).
 * All sections now in focused components; view just manages layout and analysis.
 */
@Observable
final class InsightsViewCoordinator {
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored var engine: InsightsEngine?
    @ObservationIgnored var isAnalyzing = false

    init(context: ModelContext) {
        self.modelContext = context
    }

    @MainActor
    func initializeAnalysis(cm: ConnectionManager) async {
        let e = InsightsEngine(context: modelContext)
        engine = e
        await runAnalysis(engine: e, cm: cm)
    }

    @MainActor
    func refreshAnalysis(cm: ConnectionManager) async {
        guard let e = engine else { return }
        await runAnalysis(engine: e, cm: cm)
    }

    @MainActor
    private func runAnalysis(engine: InsightsEngine, cm: ConnectionManager) async {
        isAnalyzing = true
        let nodeID = cm.config?.nodeID ?? ""
        let config = cm.config
        engine.analyze(nodeID: nodeID, config: config)
        isAnalyzing = false
        NotificationService.shared.scheduleAlerts(engine.alerts)
    }
}

struct InsightsView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext

    @State var coordinator: InsightsViewCoordinator
    @State private var initialized = false

    var body: some View {
        NavigationStack {
            Group {
                if let engine = coordinator.engine {
                    insightContent(engine: engine)
                } else {
                    ProgressView("Analyzing data…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await coordinator.refreshAnalysis(cm: cm)
                        }
                    } label: {
                        if coordinator.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(coordinator.isAnalyzing)
                }
            }
        }
        .onAppear {
            if !initialized {
                Task {
                    await coordinator.initializeAnalysis(cm: cm)
                }
                initialized = true
            }
        }
    }

    // MARK: - Content Layout

    private func insightContent(engine: InsightsEngine) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Predictions (time to empty, drain rate)
                InsightsPredictionCard(
                    engine: engine,
                    currentPct: cm.displayStatus?.levelPct ?? 0,
                    config: cm.config
                )
                .padding()

                // All charts (forecast, hourly, trends)
                InsightsChartSuite(engine: engine)

                // Stats, alerts, fill events, pump estimates
                InsightsStatsPanel(engine: engine)
                    .padding()
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: SavedDevice.self, configurations: [])
    let coordinator = InsightsViewCoordinator(context: container.mainContext)

    InsightsView(coordinator: coordinator)
        .environment(ConnectionManager())
        .modelContainer(container)
}
