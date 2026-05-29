import SwiftUI

struct ConfigWizardView: View {
    @Environment(ConnectionManager.self) private var cm
    @Binding var selectedTab: Int
    var onComplete: (() -> Void)? = nil  // Called after successful save in first-time setup

    @State private var edited = DeviceConfig()
    @State private var step = 0
    @State private var showingSaveAlert = false
    @State private var showPassword = false
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
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Connecting to device...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
        }
        .onAppear {
            if let cfg = cm.config { edited = cfg }
            print("[ConfigWizard] Appeared, cm.config: \(cm.config?.nodeID ?? "nil")")

            // Set timeout: if config doesn't arrive in 5 seconds, show error
            timeoutTask = Task {
                try? await Task.sleep(for: .seconds(5))
                if cm.config == nil && !Task.isCancelled {
                    print("[ConfigWizard] Config timeout!")
                    await MainActor.run { configTimeout = true }
                }
            }
        }
        .onChange(of: cm.config) { _, config in
            if let cfg = config {
                print("[ConfigWizard] Config received: \(cfg.nodeID)")
                edited = cfg
                timeoutTask?.cancel()  // Cancel timeout once config arrives
            }
        }
        .onDisappear {
            timeoutTask?.cancel()
        }
        .alert(cm.saveStatus ?? "Saved", isPresented: $showingSaveAlert) {
            Button("OK") {
                print("[ConfigWizard] Alert dismissed, saveStatus: \(cm.saveStatus ?? "nil")")
                if cm.saveStatus?.contains("✓") == true {
                    print("[ConfigWizard] Save successful, calling onComplete")
                    onComplete?()
                    selectedTab = 0
                }
            }
        }
        .sheet(isPresented: $showCalibration) {
            TankCalibrationView()
                .onDisappear {
                    // Refresh edited config from device after calibration completes
                    if let cfg = cm.config { edited = cfg }
                }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        if step == 0 {
            wifiForm
        } else if step == 1 {
            tankForm
        } else {
            PinConfigView(isEmbedded: true)
        }
    }

    private var wifiForm: some View {
        Form {
            Section("WiFi Credentials") {
                TextField("SSID", text: $edited.wifiSSID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                HStack {
                    if showPassword {
                        TextField("Password", text: $edited.wifiPass)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Password", text: $edited.wifiPass)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Node") {
                TextField("Node ID", text: $edited.nodeID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("MQTT Broker IP (optional)", text: $edited.mqttBrokerIP)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
    }

    private var tankForm: some View {
        Form {
            Section("Tank Dimensions") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Empty point")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f cm", edited.tankEmptyCM))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Full point")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f cm", edited.tankFullCM))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    let range = edited.tankEmptyCM - edited.tankFullCM
                    HStack {
                        Text("Range")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f cm", range))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { showCalibration = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                            Text("Calibrate Tank")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(.vertical, 8)

                LabeledContent("Volume (litres)") {
                    TextField("L", value: $edited.tankVolumeL, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            Section("Alert Thresholds") {
                LabeledContent("Low level alert (%)") {
                    TextField("%", value: $edited.alertLowPct, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                LabeledContent("High level alert (%)") {
                    TextField("%", value: $edited.alertHighPct, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            Section("Polling") {
                LabeledContent("Normal polling interval") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(edited.pollIntervalS) },
                            set: { edited.pollIntervalS = Int($0) }
                        ), in: 15...900, step: 15)
                        Text("\(edited.pollIntervalS)s")
                            .font(.caption.monospacedDigit())
                            .frame(width: 45, alignment: .trailing)
                    }
                }
                .help("Range: 15 seconds to 15 minutes")

                Toggle("Test Mode", isOn: $edited.testingMode)

                if edited.testingMode {
                    LabeledContent("Test polling interval") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(edited.testPollIntervalS) },
                                set: { edited.testPollIntervalS = Int($0) }
                            ), in: 1...10, step: 1)
                            Text("\(edited.testPollIntervalS)s")
                                .font(.caption.monospacedDigit())
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    .help("Range: 1 second to 10 seconds")
                }
            }
        }
    }

    // MARK: - Step indicator

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

    // MARK: - Nav

    private var navButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step < steps.count - 1 {
                Button("Next") {
                    save()  // Save changes if any
                    step += 1
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Done") {
                    save()  // Save final changes
                    // For first-time setup, always complete even if no changes
                    if onComplete != nil {
                        print("[ConfigWizard] First-time setup complete")
                        onComplete?()
                    } else {
                        // Regular settings edit - show alert only if something was saved
                        if cm.saveStatus != nil {
                            showingSaveAlert = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
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
