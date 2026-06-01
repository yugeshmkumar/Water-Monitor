import SwiftUI

struct DeviceDetailView: View {
    @Environment(ConnectionManager.self) private var cm

    let device: SavedDevice

    @State private var selectedTab = 0
    @State private var testModeLoading = false
    @State private var showCalibration = false
    @State private var showHealthCheck = false
    
    // ✅ Local state for test mode controls
    @State private var localTestMode: Bool = false
    @State private var localTestInterval: Int = 3
    @State private var sliderDebounceTask: Task<Void, Never>?
    
    // ✅ Live mode toggle (UI-only, forces real-time updates)
    @State private var liveMode: Bool = false
    
    // ✅ Chart throttling
    @State private var displayedLevelPct: Int = 0
    @State private var chartUpdateTask: Task<Void, Never>?

    // ✅ Check if THIS specific device is connected
    private var isConnected: Bool {
        cm.isConnected(nodeID: device.nodeID)
    }
    
    // ✅ Get THIS device's status
    private var deviceStatus: DeviceStatus? {
        cm.getStatus(for: device.nodeID)
    }
    
    // ✅ Get THIS device's config
    private var deviceConfig: DeviceConfig? {
        cm.getConfig(for: device.nodeID)
    }

    private var gaugeColor: Color {
        guard let config = deviceConfig, let status = deviceStatus else { return .blue }
        if status.levelPct <= config.alertLowPct { return .red }
        if status.levelPct >= config.alertHighPct { return .orange }
        return .blue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                connectionHeader
                if cm.isDrainingQueue {
                    syncBanner
                }
                mainGaugeSection
                statsGrid
                quickActionsSection
                deviceInfoSection
            }
            .padding()
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarContent
        }
        .overlay {
            if !isConnected {
                connectingOverlay
            }
        }
        .sheet(isPresented: $showCalibration) {
            TankCalibrationView(device: device)
        }
        .sheet(isPresented: $showHealthCheck) {
            DeviceHealthCheckView(device: device)
        }
        .onChange(of: deviceStatus?.levelPct) { _, newValue in
            // ✅ Throttle chart updates to max 1 per second
            chartUpdateTask?.cancel()
            chartUpdateTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    displayedLevelPct = newValue ?? 0
                }
            }
        }
        .onAppear {
            displayedLevelPct = deviceStatus?.levelPct ?? 0
        }
        .onDisappear {
            // ✅ Cancel all background tasks
            sliderDebounceTask?.cancel()
            chartUpdateTask?.cancel()
        }
    }

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            testModeButton
        }
        
        ToolbarItem(placement: .primaryAction) {
            NavigationLink(destination: DeviceConfigView(device: device)) {
                Image(systemName: "gearshape")
            }
        }
    }
    
    private var testModeButton: some View {
        Button(action: {
            liveMode.toggle()
            Task {
                if liveMode {
                    _ = await cm.writeConfig([
                        "testing_mode": true,
                        "test_poll_interval_s": localTestInterval
                    ], for: device.nodeID)
                } else {
                    _ = await cm.writeConfig([
                        "testing_mode": false
                    ], for: device.nodeID)
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: liveMode ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .semibold))
                Text("TEST")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(liveMode ? .white : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(liveMode ? Color.orange : Color.orange.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.orange, lineWidth: liveMode ? 0 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isConnected)
        .opacity(isConnected ? 1.0 : 0.5)
    }

    // MARK: - Subviews

    private var connectionHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(transportColor)
                .frame(width: 8, height: 8)
            Text(transportLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var syncBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Syncing history…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var mainGaugeSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: Double(displayedLevelPct) / 100.0)  // ✅ Use throttled value
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: displayedLevelPct)  // ✅ Smoother animation
                VStack(spacing: 0) {
                    Text("\(displayedLevelPct)")  // ✅ Use throttled value
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            if let status = deviceStatus {
                if !status.sensorOk {
                    Label("No sensor signal — showing last valid reading",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if status.distanceCM > 0 {
                    Text(String(format: "%.1f cm from sensor", status.distanceCM))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let config = deviceConfig, let status = deviceStatus {
                if status.levelPct <= config.alertLowPct {
                    Label("Low water level", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if status.levelPct >= config.alertHighPct {
                    Label("Tank nearly full", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("RSSI",
                     value: deviceStatus.map { "\($0.rssi) dBm" } ?? "--")
            statCard("Sensor",
                     value: deviceStatus.map { $0.sensorOk ? "OK" : "No signal" } ?? "--",
                     warning: deviceStatus.map { !$0.sensorOk } ?? false)
            statCard("Queue",
                     value: deviceStatus.map { "\($0.queueDepth)" } ?? "--",
                     warning: (deviceStatus?.queueDepth ?? 0) > 10)
            statCard("Firmware",
                     value: deviceStatus?.firmwareVersion ?? "--")
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                // ✅ Test Mode Polling Interval (always visible)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: liveMode ? "flame.fill" : "flame")
                            .foregroundStyle(liveMode ? .orange : .secondary)
                        Text("Test Mode Polling")
                            .font(.subheadline)
                        Spacer()
                        Text(liveMode ? "ACTIVE" : "OFF")
                            .font(.caption.bold())
                            .foregroundStyle(liveMode ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(liveMode ? Color.orange : Color.gray.opacity(0.2), in: Capsule())
                    }
                    
                    HStack(spacing: 12) {
                        Text("Interval")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(localTestInterval) },
                            set: { newVal in
                                localTestInterval = Int(newVal)
                                
                                // Only save if live mode is enabled
                                guard liveMode else { return }
                                
                                // Debounce: wait 500ms after user stops dragging
                                sliderDebounceTask?.cancel()
                                sliderDebounceTask = Task {
                                    try? await Task.sleep(for: .milliseconds(500))
                                    guard !Task.isCancelled else { return }
                                    // Enable test mode on device with this interval
                                    _ = await cm.writeConfig([
                                        "testing_mode": true,
                                        "test_poll_interval_s": Int(newVal)
                                    ], for: device.nodeID)
                                }
                            }
                        ), in: 1...15, step: 1)
                        .disabled(!liveMode)  // ✅ Disabled when test mode is OFF
                        
                        Text("\(localTestInterval)s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(liveMode ? .primary : .secondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                    
                    if !liveMode {
                        Text("Tap TEST button in top right to enable fast polling")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(liveMode ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )

            HStack(spacing: 12) {
                Button(action: { showCalibration = true }) {
                    Label("Calibrate", systemImage: "target")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)  // ✅ Use isConnected

                Button(action: { showHealthCheck = true }) {
                    Label("Health Check", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)  // ✅ Use isConnected
            }

            NavigationLink(destination: HistoryView()) {
                Label("History", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Info")
                .font(.headline)

            VStack(spacing: 0) {
                if let config = deviceConfig {  // ✅ Use deviceConfig
                    infoRow("IP Address", config.ip.isEmpty ? "--" : config.ip)
                    Divider().padding(.leading)
                    infoRow("MAC", config.mac.isEmpty ? "--" : config.mac)
                    Divider().padding(.leading)
                    infoRow("Firmware", config.firmwareVersion)
                    Divider().padding(.leading)
                    infoRow("Node ID", config.nodeID)
                } else {
                    infoRow("Node ID", device.nodeID)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var connectingOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.85)
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Connecting…")
                    .font(.headline)
                Text("Waiting for device data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func statCard(_ label: String, value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(warning ? .red : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(warning ? Color.red.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transportColor: Color {
        // ✅ Check if THIS device is connected
        return isConnected ? .green : .gray
    }

    private var transportLabel: String {
        // ✅ Check if THIS device is connected
        return isConnected ? "WiFi" : "Offline"
    }
}
