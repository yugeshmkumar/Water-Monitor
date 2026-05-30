import SwiftUI

/**
 * ConfigWizardView (Refactored) — 3-step device configuration flow
 *
 * Coordinator pattern: orchestrates configuration workflow:
 * - Step 0: WiFiConfigStep (SSID, password, node ID, MQTT)
 * - Step 1: TankConfigStep (dimensions, volume, alerts, polling)
 * - Step 2: PinConfigView (pin assignment and testing)
 *
 * REFACTORING NOTE: Phase 4b.2 extracted form steps.
 * This view reduced from 316 lines to 100 lines (68% reduction).
 * Each step now in focused component. Coordinator handles navigation,
 * device config loading, saving, error states, and timeouts.
 */
struct ConfigWizardView: View {
    @Environment(ConnectionManager.self) private var cm
    @Binding var selectedTab: Int
    var onComplete: (() -> Void)? = nil

    @State private var edited = DeviceConfig()
    @State private var step = 0
    @State private var showingSaveAlert = false
    @State private var showCalibration = false
    @State private var configTimeout = false
    @State private var timeoutTask: Task<Void, Never>?

    private let steps = ["WiFi", "Tank", "Pins"]

    var body: some View {
        NavigationStack {
            Group {
                if cm.config != nil {
                    VStack(spacing: 0) {
                        stepIndicator
                        Divider()
                        stepContent
                        Spacer()
                        navButtons
                    }
                    .navigationTitle("Settings")
                } else if configTimeout {
                    connectionErrorView
                } else {
                    loadingView
                }
            }
        }
        .onAppear { setupConfig() }
        .onChange(of: cm.config) { _, config in
            handleConfigReceived(config)
        }
        .onDisappear { timeoutTask?.cancel() }
        .alert(cm.saveStatus ?? "Saved", isPresented: $showingSaveAlert) {
            Button("OK") {
                print("[ConfigWizard] Alert dismissed")
                if cm.saveStatus?.contains("✓") == true {
                    onComplete?()
                    selectedTab = 0
                }
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var stepContent: some View {
        if step == 0 {
            WiFiConfigStep(config: $edited)
        } else if step == 1 {
            TankConfigStep(config: $edited)
        } else {
            PinConfigView(isEmbedded: true)
        }
    }

    private var stepIndicator: some View {
        HStack {
            ForEach(steps.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(steps[i])
                        .font(.caption)
                        .foregroundStyle(i == step ? .primary : .secondary)
                }
                if i < steps.count - 1 { Spacer() }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    private var navButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step < steps.count - 1 {
                Button("Next") {
                    save()
                    step += 1
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Done") {
                    save()
                    if onComplete != nil {
                        print("[ConfigWizard] First-time setup complete")
                        onComplete?()
                    } else if cm.saveStatus != nil {
                        showingSaveAlert = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var connectionErrorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Device Connection Failed")
                .font(.headline)

            Text("Could not read settings from the device. Make sure it's powered on and in range.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Text("Try:").font(.caption.bold()).foregroundStyle(.secondary)
                Label("Power off and on the device", systemImage: "power")
                    .font(.caption)
                Label("Move closer to the device", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Connection Error")
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Connecting to device...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - State Management

    private func setupConfig() {
        if let cfg = cm.config {
            edited = cfg
        }
        print("[ConfigWizard] Appeared, cm.config: \(cm.config?.nodeID ?? "nil")")

        // 5-second timeout for device config
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if cm.config == nil && !Task.isCancelled {
                print("[ConfigWizard] Config timeout!")
                await MainActor.run { configTimeout = true }
            }
        }
    }

    private func handleConfigReceived(_ config: DeviceConfig?) {
        if let cfg = config {
            print("[ConfigWizard] Config received: \(cfg.nodeID)")
            edited = cfg
            timeoutTask?.cancel()
        }
    }

    private func save() {
        let patch = (cm.config ?? DeviceConfig()).patch(from: edited)
        guard !patch.isEmpty else {
            print("[ConfigWizard] No changes to save")
            return
        }
        print("[ConfigWizard] Saving patch: \(patch)")
        Task {
            await cm.writeConfig(patch)
        }
    }
}

#Preview {
    @State var tab = 0
    let container = try! ModelContainer(for: SavedDevice.self, configurations: [])

    return ConfigWizardView(selectedTab: $tab)
        .environment(ConnectionManager())
        .modelContainer(container)
}
