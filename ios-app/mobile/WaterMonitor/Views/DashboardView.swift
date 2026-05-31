import SwiftUI
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.modelContext) private var modelContext
    @State private var vm: DashboardVM?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let vm {
                    VStack(spacing: 24) {
                        deviceHeader
                        connectionBadge(vm: vm)
                        testModeSection
                        levelGauge(vm: vm)
                        statsGrid(vm: vm)
                    }
                    .padding()
                }
            }
            .navigationTitle("Water Level")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: DeviceInfoView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .onAppear { vm = DashboardVM(cm: cm) }
        .onChange(of: cm.status?.levelPct) { _, levelPct in
            // Check tank level and send notifications if needed
            if let levelPct = levelPct, let config = cm.config, !config.nodeID.isEmpty {
                // Get the user-friendly display name for the device
                let displayName = getDeviceDisplayName(nodeID: config.nodeID)
                
                notificationManager.checkAndNotify(
                    deviceName: displayName,
                    nodeID: config.nodeID,
                    levelPct: levelPct,
                    alertLowPct: config.alertLowPct,
                    alertHighPct: config.alertHighPct
                )
            }
        }
    }

    // MARK: - Sub-views
    
    private var deviceHeader: some View {
        HStack {
            Text(getDeviceDisplayName(nodeID: cm.config?.nodeID ?? ""))
                .font(.title2.bold())
            
            Spacer()
            
            // ✅ Prominent test mode button with clear visual distinction
            Button(action: {
                let currentMode = cm.config?.testingMode ?? false
                print("[Dashboard] Test mode toggle: \(!currentMode)")
                Task {
                    if let nodeID = cm.config?.nodeID {
                        await cm.setTestMode(!currentMode, for: nodeID)
                        try? await Task.sleep(for: .milliseconds(500))
                        print("[Dashboard] Test mode set complete")
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: cm.config?.testingMode == true ? "flame.fill" : "flame")
                        .font(.system(size: 14, weight: .semibold))
                    Text("TEST")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(cm.config?.testingMode == true ? .white : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cm.config?.testingMode == true ? Color.orange : Color.orange.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.orange, lineWidth: cm.config?.testingMode == true ? 0 : 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
    
    private var testModeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: cm.config?.testingMode == true ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(cm.config?.testingMode == true ? .orange : .secondary)
                Text("Test Mode Polling")
                    .font(.subheadline.bold())
                Spacer()
            }
            
            HStack {
                Text("Interval:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Slider(value: Binding(
                    get: { Double(cm.config?.testPollIntervalS ?? 3) },
                    set: { newValue in
                        Task {
                            if let nodeID = cm.config?.nodeID {
                                await cm.writeConfig(["test_poll_interval_s": Int(newValue)], for: nodeID)
                            }
                        }
                    }
                ), in: 1...10, step: 1)
                .disabled(cm.config?.testingMode != true)
                
                Text("\(cm.config?.testPollIntervalS ?? 3)s")
                    .font(.caption.monospacedDigit())
                    .frame(width: 30, alignment: .trailing)
                    .foregroundStyle(cm.config?.testingMode == true ? .primary : .secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .opacity(cm.config?.testingMode == true ? 1.0 : 0.5)
    }

    private func connectionBadge(vm: DashboardVM) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(transportColor(vm.transport))
                .frame(width: 8, height: 8)
            Text(transportLabel(vm.transport))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private func levelGauge(vm: DashboardVM) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: Double(vm.status?.levelPct ?? 0) / 100.0)
                    .stroke(gaugeColor(vm: vm),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: vm.status?.levelPct)
                VStack(spacing: 0) {
                    Text("\(vm.status?.levelPct ?? 0)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 210, height: 210)

            // Show sensor status
            if let current = vm.currentStatus {
                if !current.sensorOk {
                    Label("No sensor signal (showing last valid reading)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if current.distanceCM > 0 {
                    Text(String(format: "%.1f cm from sensor", current.distanceCM))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.isLow {
                Label("Low water level", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if vm.isHigh {
                Label("Tank nearly full", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func statsGrid(vm: DashboardVM) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("RSSI",    value: vm.currentStatus.map { "\($0.rssi) dBm" } ?? "--")
            statCard("Sensor",  value: sensorStatus(vm.currentStatus))
            statCard("Queue",   value: queueStatus(vm.currentStatus), 
                     warning: (vm.currentStatus?.queueDepth ?? 0) > 10)
            statCard("Version", value: vm.currentStatus?.firmwareVersion ?? "--")
        }
    }
    
    private func queueStatus(_ status: DeviceStatus?) -> String {
        guard let depth = status?.queueDepth else { return "--" }
        return depth > 10 ? "⚠️ \(depth)" : "\(depth)"
    }
    
    private func sensorStatus(_ status: DeviceStatus?) -> String {
        guard let status = status else { return "--" }
        return status.sensorOk ? "✓ OK" : "✗ No signal"
    }

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
        .background(warning ? Color.red.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func gaugeColor(vm: DashboardVM) -> Color {
        if vm.isLow { return .red }
        if vm.isHigh { return .orange }
        return .blue
    }

    private func transportColor(_ t: Transport) -> Color {
        switch t {
        case .wifi: return .green
        case .ble:  return .blue
        case .none: return .gray
        }
    }

    private func transportLabel(_ t: Transport) -> String {
        switch t {
        case .wifi: return "WiFi"
        case .ble:  return "Bluetooth"
        case .none: return "Offline"
        }
    }
    
    private func getDeviceDisplayName(nodeID: String) -> String {
        let descriptor = FetchDescriptor<SavedDevice>(
            predicate: #Predicate { $0.nodeID == nodeID }
        )
        
        guard let device = try? modelContext.fetch(descriptor).first else {
            return nodeID  // Fallback to nodeID if device not found
        }
        
        return device.displayName
    }
}
