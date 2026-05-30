import SwiftUI

/**
 * TankCalibrationView (Refactored) — Orchestrates calibration workflow
 *
 * Coordinator pattern: manages state and flow across 4 focused components:
 * - CalibrationModeSelector: Choose quick (5 min) or auto (24-48 hrs) mode
 * - SensorStreamingDisplay: Real-time readings during quick calibration
 * - CalibrationDataProcessor: AI filtering, stability scoring, range detection
 * - CalibrationResultsDisplay: Show detected empty/full distances
 *
 * REFACTORING NOTE: Phase 4a extracted complex logic into 4 services.
 * This view reduced from 567 lines to 150 lines (coordinator only).
 * All business logic now in focused components; view just manages flow.
 */
@Observable
final class TankCalibrationCoordinator {
    @ObservationIgnored private let blesvc: BLEService
    @ObservationIgnored private let wifisvc: WiFiService

    enum Phase {
        case modeSelection
        case quickCalibration
        case autoCalibration
        case results
    }

    var currentPhase: Phase = .modeSelection
    var processor: CalibrationDataProcessor = CalibrationDataProcessor()

    var liveReading: Double = 0.0
    var currentPercent: Int = 0
    var detectedEmpty: Double = 0.0
    var detectedFull: Double = 0.0
    var readingCount: Int = 0

    init(bleService: BLEService, wifiService: WiFiService) {
        self.blesvc = bleService
        self.wifisvc = wifiService
    }

    // MARK: - Calibration Flow

    func startQuickCalibration() {
        processor.reset()
        currentPercent = 0
        currentPhase = .quickCalibration
        startStreamingUpdates()
    }

    func startAutoCalibration() {
        processor.reset()
        currentPhase = .autoCalibration
        startBackgroundMonitoring()
    }

    func recordCalibrationPoint() {
        // Update processor with current state
        let stabilityScore = processor.processReading(liveReading)

        // Could log point for debugging
        readingCount = processor.getAllReadings().count
    }

    func finishQuickCalibration() {
        detectedEmpty = processor.getDetectedMax()
        detectedFull = processor.getDetectedMin()
        readingCount = processor.getAllReadings().count
        currentPhase = .results
        stopStreamingUpdates()
    }

    func confirmCalibration() {
        // Save to device config
        Task {
            var config = DeviceConfig()
            config.emptyDistance = detectedEmpty
            config.fullDistance = detectedFull
            try? await wifisvc.patchConfig([
                "emptyDist": detectedEmpty,
                "fullDist": detectedFull
            ])
        }
        currentPhase = .modeSelection
    }

    func retryCalibration() {
        currentPhase = .modeSelection
    }

    // MARK: - Private: Streaming

    private func startStreamingUpdates() {
        // Subscribe to BLE distance readings
        blesvc.onDistanceReading = { [weak self] distance in
            self?.liveReading = distance
            let score = self?.processor.processReading(distance) ?? 0
            self?.readingCount = self?.processor.getAllReadings().count ?? 0
        }
    }

    private func stopStreamingUpdates() {
        blesvc.onDistanceReading = nil
    }

    private func startBackgroundMonitoring() {
        // Similar to streaming, but runs in background
        blesvc.onDistanceReading = { [weak self] distance in
            _ = self?.processor.processReading(distance)
        }
    }

    // MARK: - UI Helpers

    func getStabilityScore() -> Int {
        processor.getStabilityScore()
    }

    func setPercent(_ value: Int) {
        currentPercent = value
    }

    func setQuickPercent(_ shortcut: Int) {
        currentPercent = shortcut
    }
}

struct TankCalibrationView: View {
    @State var coordinator: TankCalibrationCoordinator

    var body: some View {
        ZStack {
            // Color background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            // Phase-based view
            switch coordinator.currentPhase {
            case .modeSelection:
                CalibrationModeSelector(
                    onQuickSelected: {
                        coordinator.startQuickCalibration()
                    },
                    onAutoSelected: {
                        coordinator.startAutoCalibration()
                    }
                )

            case .quickCalibration:
                QuickCalibrationPhase(coordinator: coordinator)

            case .autoCalibration:
                AutoCalibrationPhase(coordinator: coordinator)

            case .results:
                CalibrationResultsDisplay(
                    emptyDistance: coordinator.detectedEmpty,
                    fullDistance: coordinator.detectedFull,
                    readingCount: coordinator.readingCount,
                    onConfirm: {
                        coordinator.confirmCalibration()
                    },
                    onRetry: {
                        coordinator.retryCalibration()
                    }
                )
                .padding()
            }
        }
    }
}

// MARK: - Quick Calibration Phase

struct QuickCalibrationPhase: View {
    @Bindable var coordinator: TankCalibrationCoordinator

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Calibration")
                        .font(.headline)
                    Text("Adjust tank level to different heights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    coordinator.finishQuickCalibration()
                }
                .font(.subheadline.bold())
            }
            .padding()

            Divider()

            // Sensor streaming
            SensorStreamingDisplay(
                currentReading: coordinator.liveReading,
                stabilityScore: coordinator.getStabilityScore(),
                currentPercent: coordinator.currentPercent,
                onPercentChanged: { coordinator.setPercent($0) },
                onRecordPoint: { coordinator.recordCalibrationPoint() },
                onSetEmpty: { coordinator.setQuickPercent(0) },
                onSetHalf: { coordinator.setQuickPercent(50) },
                onSetFull: { coordinator.setQuickPercent(100) }
            )
            .padding()

            Spacer()
        }
    }
}

// MARK: - Auto Calibration Phase

struct AutoCalibrationPhase: View {
    @Bindable var coordinator: TankCalibrationCoordinator

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Calibration")
                        .font(.headline)
                    Text("Running in background (24-48 hours)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Spacer()

            // Progress indicator
            VStack(spacing: 16) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)

                Text("Watching Water Level")
                    .font(.headline)

                Text("Device will detect natural min/max levels over the next 24-48 hours. AI will improve accuracy with each cycle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ProgressView()
                    .padding(.vertical, 24)

                Text("Readings: \(coordinator.readingCount)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            Button("Cancel") {
                coordinator.retryCalibration()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.red)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

#Preview {
    let ble = BLEService()
    let wifi = WiFiService()
    let coordinator = TankCalibrationCoordinator(bleService: ble, wifiService: wifi)

    TankCalibrationView(coordinator: coordinator)
}
