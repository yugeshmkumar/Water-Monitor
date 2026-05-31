import SwiftUI

struct TankCalibrationView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.dismiss) private var dismiss
    
    let device: SavedDevice?  // ✅ Optional device parameter (nil for legacy single-device mode)

    @State private var mode: CalibrationMode = .selection
    @State private var currentReading: Double = 0
    @State private var recordedPoints: [(distance: Double, percent: Int)] = []
    @State private var detectedMin: Double = Double.infinity
    @State private var detectedMax: Double = -Double.infinity
    @State private var readingsCollected: [Double] = []
    @State private var stabilityScore: Int = 0
    @State private var currentPercent: Int = 50
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var lastReadingTime: Date?
    @State private var calculatedFullCM: Double?  // ✅ Store calculated values to display
    @State private var calculatedEmptyCM: Double?
    
    // ✅ Get status for THIS device
    private var deviceStatus: DeviceStatus? {
        if let device = device {
            return cm.getStatus(for: device.nodeID)
        }
        return cm.displayStatus  // Legacy fallback
    }

    enum CalibrationMode {
        case selection, quick, auto, complete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()

                ScrollView {
                    VStack(spacing: 20) {
                        if mode == .selection {
                            modeSelectionContent
                        } else if mode == .quick {
                            quickCalibrationContent
                        } else if mode == .auto {
                            autoCalibrationContent
                        } else {
                            completionContent
                        }
                    }
                    .padding()
                }

                Spacer()
                footerActions
            }
            .navigationTitle("Calibrate Tank")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { startLiveReadings() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(modeTitle).font(.subheadline.bold())
                Spacer()
                Text(modeSubtitle).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    // MARK: - Content

    private var modeSelectionContent: some View {
        VStack(spacing: 16) {
            Text("Choose Calibration Method").font(.headline).padding(.top, 24)

            VStack(spacing: 12) {
                modeCard(
                    title: "Quick Calibration",
                    subtitle: "5 minutes",
                    description: "Move water level to different heights. App learns from real readings with AI filtering.",
                    icon: "timer.circle.fill",
                    color: .blue,
                    action: { mode = .quick }
                )

                modeCard(
                    title: "Auto Calibration",
                    subtitle: "24-48 hours",
                    description: "Device watches naturally and detects min/max automatically. AI improves accuracy over cycles.",
                    icon: "moon.stars.fill",
                    color: .indigo,
                    action: { mode = .auto }
                )
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var quickCalibrationContent: some View {
        VStack(spacing: 20) {
            // Live distance reading
            VStack(spacing: 12) {
                Text("Current Distance").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", currentReading))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                    Text("cm").font(.title3).foregroundStyle(.secondary)
                }
                .frame(height: 60)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Stability indicator
            VStack(spacing: 12) {
                HStack {
                    Text("Reading Stability").font(.subheadline.bold())
                    Spacer()
                    stabilityBadge
                }

                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < stabilityScore ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 8)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Tank percentage input
            VStack(spacing: 12) {
                HStack {
                    Text("Tank Fullness").font(.subheadline.bold())
                    Spacer()
                    Text("\(currentPercent)%").font(.headline.monospaced()).foregroundStyle(.blue)
                }

                Slider(value: Binding(
                    get: { Double(currentPercent) },
                    set: { currentPercent = Int($0) }
                ), in: 0...100, step: 1)
                    .tint(.blue)

                HStack(spacing: 12) {
                    Button("Empty (0%)") { currentPercent = 0 }
                        .font(.caption).buttonStyle(.bordered)
                    Button("Half (50%)") { currentPercent = 50 }
                        .font(.caption).buttonStyle(.bordered)
                    Button("Full (100%)") { currentPercent = 100 }
                        .font(.caption).buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Detected range
            if detectedMin != Double.infinity || detectedMax != -Double.infinity {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detected Range").font(.subheadline.bold())

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min Detected").font(.caption).foregroundStyle(.secondary)
                            Text(detectedMin == Double.infinity ? "--" : String(format: "%.1f cm", detectedMin))
                                .font(.headline.monospaced())
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Max Detected").font(.caption).foregroundStyle(.secondary)
                            Text(detectedMax == -Double.infinity ? "--" : String(format: "%.1f cm", detectedMax))
                                .font(.headline.monospaced())
                        }
                    }

                    Text("Range: \(String(format: "%.1f cm", detectedMax - detectedMin))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            // Recorded points
            if !recordedPoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recorded Points (\(recordedPoints.count))").font(.subheadline.bold())

                    ForEach(recordedPoints.indices, id: \.self) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Point \(i + 1)").font(.caption.bold())
                                Text(String(format: "%.1f cm @ %d%%", recordedPoints[i].distance, recordedPoints[i].percent))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            // Record button
            Button(action: recordPoint) {
                HStack {
                    Image(systemName: stabilityScore >= 3 ? "checkmark.circle.fill" : "circle")
                    Text(recordedPoints.count == 0 ? "Record Point 1" : recordedPoints.count == 1 ? "Record Point 2" : "Record Point")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(stabilityScore < 2 || recordedPoints.count >= 2)

            if stabilityScore < 2 {
                Label("Wait for reading to stabilize (green bars)", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if recordedPoints.count >= 2 {
                Label("Two points recorded. Ready to calculate calibration.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }

    private var autoCalibrationContent: some View {
        VStack(spacing: 20) {
            if let config = cm.config, config.autoCalibrationEnabled {
                VStack(spacing: 16) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.indigo)

                    VStack(spacing: 8) {
                        Text("Auto Calibration Active")
                            .font(.headline)
                        Text("Monitoring water level continuously...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Detected Range").font(.caption.bold())
                            Spacer()
                            if config.autoCalMinCM < 999 && config.autoCalMaxCM > 0 {
                                Text(String(format: "%.0f–%.0f cm", config.autoCalMaxCM, config.autoCalMinCM))
                                    .font(.caption.monospaced())
                            } else {
                                Text("Waiting for readings...").font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Fill/Drain Cycles").font(.caption.bold())
                            Spacer()
                            Text("\(config.calibrationCycles)").font(.caption.monospaced())
                        }

                        HStack {
                            Text("Confidence").font(.caption.bold())
                            Spacer()
                            HStack(spacing: 4) {
                                ProgressView(value: Double(config.calibrationConfidence) / 100)
                                    .frame(width: 60)
                                Text("\(config.calibrationConfidence)%").font(.caption.monospaced()).frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("More cycles = more accurate. Let it run 24-48 hours.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: startAutoCalibration) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start 24-Hour Auto Watch")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Device monitors water level continuously", systemImage: "checkmark.circle").font(.caption)
                        Label("Detects natural min/max automatically", systemImage: "checkmark.circle").font(.caption)
                        Label("AI improves accuracy with each cycle", systemImage: "checkmark.circle").font(.caption)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding()
    }

    private var completionContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Calibration Complete").font(.headline)
                    Text("Tank boundaries calculated and saved").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Calibration Points Used:").font(.caption).foregroundStyle(.secondary)
                ForEach(recordedPoints.indices, id: \.self) { i in
                    Text("Point \(i+1): \(String(format: "%.1f cm @ %d%%", recordedPoints[i].distance, recordedPoints[i].percent))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                
                Divider().padding(.vertical, 4)
                
                Text("Calculated Tank Boundaries:").font(.caption.bold())
                resultRow("Full Point (100%)", calculatedFullCM ?? 0)
                Divider()
                resultRow("Empty Point (0%)", calculatedEmptyCM ?? 0)
                Divider()
                resultRow("Tank Range", (calculatedEmptyCM ?? 0) - (calculatedFullCM ?? 0))
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footerActions: some View {
        VStack(spacing: 12) {
            if mode == .selection {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            } else if mode == .complete {
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            } else if mode == .quick {
                if recordedPoints.count >= 2 {
                    Button(action: confirmCalibration) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Calculate & Save")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)

                    Button("Back") { mode = .selection; recordedPoints = []; readingsCollected = [] }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                } else {
                    Button("Back") { mode = .selection; recordedPoints = []; readingsCollected = [] }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                }
            } else {
                Button(action: confirmCalibration) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Done")
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button("Back") { mode = .selection }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private var modeTitle: String {
        switch mode {
        case .selection: return "Calibration"
        case .quick: return "Quick Calibration"
        case .auto: return "Auto Calibration"
        case .complete: return "Complete"
        }
    }

    private var modeSubtitle: String {
        switch mode {
        case .selection: return "Choose method"
        case .quick: return "AI-filtered real-time detection"
        case .auto: return "Background watch"
        case .complete: return "Done"
        }
    }

    private var stabilityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: stabilityScore >= 4 ? "checkmark.circle.fill" : "circle.fill")
                .font(.caption)
                .foregroundStyle(stabilityScore >= 4 ? .green : stabilityScore >= 2 ? .orange : .red)
            Text(stabilityScore >= 4 ? "Stable" : stabilityScore >= 2 ? "Acceptable" : "Unstable")
                .font(.caption.bold())
        }
    }

    private func modeCard(title: String, subtitle: String, description: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.subheadline.bold())
                        Spacer()
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Image(systemName: icon).font(.title2).foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.primary)
        }
    }

    private func resultRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f cm", value)).font(.caption.bold().monospaced())
        }
    }

    // MARK: - Live reading logic

    private func startLiveReadings() {
        Task {
            while !Task.isCancelled {
                if let status = deviceStatus {  // ✅ Use device-specific status
                    await MainActor.run {
                        currentReading = status.distanceCM
                        lastReadingTime = Date()
                        updateStabilityAndRange(status.distanceCM)
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func updateStabilityAndRange(_ distance: Double) {
        // Keep last 10 readings for median-based filtering
        readingsCollected.append(distance)
        if readingsCollected.count > 10 {
            readingsCollected.removeFirst()
        }

        // Calculate median and standard deviation for outlier detection
        let sorted = readingsCollected.sorted()
        let median = readingsCollected.count % 2 == 0
            ? (sorted[readingsCollected.count / 2 - 1] + sorted[readingsCollected.count / 2]) / 2
            : sorted[readingsCollected.count / 2]

        let variance = readingsCollected.map { pow($0 - median, 2) }.reduce(0, +) / Double(readingsCollected.count)
        let stdDev = sqrt(variance)

        // Stability score: how close is current reading to median (0-5)
        let deviation = abs(distance - median)
        stabilityScore = Int(max(0, 5 - (deviation / max(stdDev, 1))))

        // Update min/max only from stable readings (stdDev < 1cm)
        if stdDev < 1 && stabilityScore >= 3 {
            detectedMin = min(detectedMin, median)
            detectedMax = max(detectedMax, median)
        }
    }

    private func recordPoint() {
        recordedPoints.append((distance: currentReading, percent: currentPercent))

        if recordedPoints.count == 2 {
            errorMessage = nil
        }
    }

    private func startAutoCalibration() {
        isSaving = true
        Task {
            if let device = device {
                await cm.writeConfig(["auto_calibration_enabled": true], for: device.nodeID)
            } else {
                await cm.writeConfig(["auto_calibration_enabled": true])  // Legacy
            }
            await MainActor.run { isSaving = false; mode = .auto }
        }
    }

    private func confirmCalibration() {
        isSaving = true
        errorMessage = nil

        if mode == .quick && recordedPoints.count == 2 {
            // ✅ Sort points: smaller distance = more full (closer to sensor)
            let sortedPoints = recordedPoints.sorted { $0.distance < $1.distance }
            
            let dist1 = sortedPoints[0].distance  // Smaller distance (fuller)
            let dist2 = sortedPoints[1].distance  // Larger distance (emptier)
            let pct1 = Double(sortedPoints[0].percent)  // Higher percentage
            let pct2 = Double(sortedPoints[1].percent)  // Lower percentage
            
            print("[Calibration] Point 1: \(dist1)cm = \(pct1)%")
            print("[Calibration] Point 2: \(dist2)cm = \(pct2)%")

            // ✅ Correct linear interpolation formula
            // percent = 100 * (tank_empty_cm - distance) / (tank_empty_cm - tank_full_cm)
            // 
            // From two points:
            //   pct1 = 100 * (empty - dist1) / (empty - full)
            //   pct2 = 100 * (empty - dist2) / (empty - full)
            //
            // Solving:
            //   pct1/100 * (empty - full) = empty - dist1
            //   pct2/100 * (empty - full) = empty - dist2
            //
            // Subtracting: (pct1 - pct2)/100 * (empty - full) = dist2 - dist1
            //              (empty - full) = 100 * (dist2 - dist1) / (pct1 - pct2)
            //
            // From first equation: empty = dist1 + pct1/100 * (empty - full)
            
            let range = 100.0 * (dist2 - dist1) / (pct1 - pct2)
            let emptyCM = dist1 + (pct1 / 100.0) * range
            let fullCM = emptyCM - range
            
            // ✅ Store for display
            calculatedEmptyCM = emptyCM
            calculatedFullCM = fullCM
            
            print("[Calibration] Calculated: tank_full_cm=\(fullCM), tank_empty_cm=\(emptyCM)")
            print("[Calibration] Range: \(range) cm")

            // Validation
            guard abs(emptyCM - fullCM) > 5 else {
                print("[Calibration] ERROR: Invalid range (too small)")
                errorMessage = "Invalid calibration: points too close"
                isSaving = false
                return
            }

            Task {
                if let device = device {
                    await cm.writeConfig([
                        "tank_empty_cm": emptyCM,
                        "tank_full_cm": fullCM
                    ], for: device.nodeID)
                } else {
                    await cm.writeConfig([
                        "tank_empty_cm": emptyCM,
                        "tank_full_cm": fullCM
                    ])  // Legacy
                }
                await MainActor.run {
                    mode = .complete
                    isSaving = false
                }
            }
        } else if mode == .auto {
            mode = .complete
            isSaving = false
        }
    }
}

#Preview {
    TankCalibrationView(device: nil)
        .environment(ConnectionManager())
}
