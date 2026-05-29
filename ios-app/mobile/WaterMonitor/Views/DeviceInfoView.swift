import SwiftUI

struct DeviceInfoView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.openURL) private var openURL
    @State private var showOTAAlert = false
    @State private var otaURL = ""
    @State private var showRebootConfirm = false

    private var status: DeviceStatus? { cm.status }
    private var config: DeviceConfig? { cm.config }

    var body: some View {
        List {
            Section("Device") {
                row("Node ID",   config?.nodeID ?? "--")
                row("Firmware",  status?.firmwareVersion ?? "--")
                row("Transport", transportLabel)
            }
            Section("Live Status") {
                row("RSSI",        status.map { "\($0.rssi) dBm" } ?? "--")
                row("Sensor",      status?.sensorOk == true ? "OK" : "No signal")
                row("WiFi on node", status?.wifiOk == true ? "Connected" : "Offline")
                row("Queue depth", status.map { "\($0.queueDepth) entries" } ?? "--")
                
                if cm.isDrainingQueue {
                    HStack {
                        ProgressView()
                        Text("Syncing queued readings…")
                            .foregroundStyle(.secondary)
                    }
                } else if let depth = status?.queueDepth, depth > 0 {
                    Button("Sync Now") {
                        cm.flushQueueViaREST()
                    }
                    .foregroundStyle(depth > 10 ? .orange : .blue)
                }
            }
            Section("OTA Update") {
                Button("Update from URL…") { showOTAAlert = true }
                if let host = cm.wifi.host {
                    Button("Open ElegantOTA in Browser") {
                        if let url = URL(string: "http://\(host)/update") {
                            openURL(url)
                        }
                    }
                }
            }
            Section {
                Button("Reboot Device", role: .destructive) {
                    showRebootConfirm = true
                }
            }
        }
        .navigationTitle("Device Info")
        .navigationBarTitleDisplayMode(.inline)
        .alert("OTA Update URL", isPresented: $showOTAAlert) {
            TextField("http://…/firmware.bin", text: $otaURL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Start Update") { cm.wifi.startOTA(url: otaURL) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The device will download and flash the binary, then reboot.")
        }
        .confirmationDialog("Reboot sensor-a?", isPresented: $showRebootConfirm,
                            titleVisibility: .visible) {
            Button("Reboot", role: .destructive) { cm.sendCommand(["cmd": "reboot"]) }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).foregroundStyle(.secondary) }
    }

    private var transportLabel: String {
        switch cm.transport {
        case .wifi: return "WiFi"
        case .ble:  return "Bluetooth"
        case .none: return "Offline"
        }
    }
}
