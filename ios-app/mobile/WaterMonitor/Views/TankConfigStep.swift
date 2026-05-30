import SwiftUI

/**
 * TankConfigStep — Tank dimensions and polling configuration
 *
 * Sections:
 * - Tank dimensions (empty/full points, range, calibration)
 * - Tank volume (litres)
 * - Alert thresholds (low/high percentages)
 * - Polling configuration (interval sliders, test mode)
 *
 * Isolated tank setup UI. Used in ConfigWizardView.
 */
struct TankConfigStep: View {
    @Binding var config: DeviceConfig
    @State private var showCalibration = false

    var body: some View {
        Form {
            Section("Tank Dimensions") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Empty point")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f cm", config.tankEmptyCM))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Full point")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f cm", config.tankFullCM))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    let range = config.tankEmptyCM - config.tankFullCM
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
                    TextField("L", value: $config.tankVolumeL, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }

            Section("Alert Thresholds") {
                LabeledContent("Low level alert (%)") {
                    TextField("%", value: $config.alertLowPct, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                LabeledContent("High level alert (%)") {
                    TextField("%", value: $config.alertHighPct, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }

            Section("Polling") {
                LabeledContent("Normal polling interval") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(config.pollIntervalS) },
                            set: { config.pollIntervalS = Int($0) }
                        ), in: 15...900, step: 15)
                        Text("\(config.pollIntervalS)s")
                            .font(.caption.monospacedDigit())
                            .frame(width: 45, alignment: .trailing)
                    }
                }
                .help("Range: 15 seconds to 15 minutes")

                Toggle("Test Mode", isOn: $config.testingMode)

                if config.testingMode {
                    LabeledContent("Test polling interval") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(config.testPollIntervalS) },
                                set: { config.testPollIntervalS = Int($0) }
                            ), in: 1...10, step: 1)
                            Text("\(config.testPollIntervalS)s")
                                .font(.caption.monospacedDigit())
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    .help("Range: 1 second to 10 seconds")
                }
            }
        }
        .sheet(isPresented: $showCalibration) {
            TankCalibrationView()
                .onDisappear {
                    // Config auto-syncs from device after calibration
                }
        }
    }
}

#Preview {
    @State var config = DeviceConfig()
    return TankConfigStep(config: $config)
}
