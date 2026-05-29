import SwiftUI

struct PinConfigView: View {
    // When embedded inside ConfigWizardView as step 3, suppress the alert
    // and auto-dismiss — the wizard handles navigation after save.
    var isEmbedded: Bool = false

    @Environment(ConnectionManager.self) private var cm
    @Environment(\.dismiss) private var dismiss
    @State private var pinTrig = "D2"
    @State private var pinEcho = "D1"
    @State private var testResult: String?
    @State private var testing = false
    @State private var testTask: Task<Void, Never>?
    @State private var showingSaveSuccess = false

    private let availablePins = ["D0","D1","D2","D3","D4","D5","D6","D7","D8","D9","D10"]
    private var pinsConflict: Bool { pinTrig == pinEcho }

    var body: some View {
        Form {
            Section("Pin Assignment") {
                Picker("Trigger pin", selection: $pinTrig) {
                    ForEach(availablePins, id: \.self) { Text($0) }
                }
                Picker("Echo pin", selection: $pinEcho) {
                    ForEach(availablePins, id: \.self) { Text($0) }
                }
                if pinsConflict {
                    Label("Trigger and echo pins must differ", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(testing ? "Testing…" : "Test Sensor") { testSensor() }
                    .disabled(testing || pinsConflict)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("✓") ? .green : .secondary)
                }
            } header: {
                Text("Verify wiring")
            } footer: {
                Text("Sends a test pulse and reports the echo distance.")
            }

            Section {
                Button("Save Pin Config") { savePins() }
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if let cfg = cm.config {
                pinTrig = cfg.pinTrig
                pinEcho = cfg.pinEcho
            }
        }
        .onChange(of: cm.commandResult) { _, result in
            guard testing, let result = result else { return }
            testResult = "✓ Response: \(result)"
            testing = false
            testTask?.cancel()
        }
        // Only show alert and auto-dismiss when used standalone (not inside wizard)
        .onChange(of: cm.saveStatus) { _, status in
            guard !isEmbedded, let status else { return }
            showingSaveSuccess = status.contains("✓")
            if showingSaveSuccess {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    dismiss()
                }
            }
        }
        .alert(cm.saveStatus ?? "", isPresented: $showingSaveSuccess) {
            Button("OK") { dismiss() }
        }
        .onDisappear { testTask?.cancel() }
    }

    private func testSensor() {
        testing = true
        testResult = nil
        print("[PinConfig] Sending test command, transport: \(cm.transport)")
        cm.sendCommand(["cmd": "test_pin", "peripheral": "sensor"])
        testTask = Task {
            // Firmware tries 3 times with 500ms delays = ~2s max
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if testing {
                    testResult = "✗ No response (timeout)"
                    testing = false
                }
            }
        }
    }

    private func savePins() {
        guard !pinsConflict else { return }
        Task {
            await cm.writeConfig(["pin_trig": pinTrig, "pin_echo": pinEcho])
        }
    }
}
