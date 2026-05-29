// /Users/yugeshmluv/Work/Projects/code/Water-Monitor/os-app/WaterMonitor/WaterMonitor/Views/AppSettingsView.swift
import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectionManager.self) private var cm
    @Query private var savedDevices: [SavedDevice]

    @State private var showAddDevice = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "--"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "--"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("My Devices") {
                    if savedDevices.isEmpty {
                        Text("No devices added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedDevices) { device in
                            HStack {
                                NavigationLink(destination: DeviceConfigView(device: device)) {
                                    deviceRow(device)
                                }
                                Spacer()
                                Button(action: { deleteDevice(device) }) {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        showAddDevice = true
                    } label: {
                        Label("Add Device", systemImage: "plus.circle.fill")
                    }
                }

                Section("App") {
                    LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView()
        }
    }

    private func deviceRow(_ device: SavedDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.type == .sensor ? "drop.fill" : "bolt.fill")
                .foregroundStyle(device.type == .sensor ? .blue : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)

                // Check if this device is currently connected
                let isCurrentDevice = cm.config?.nodeID == device.nodeID
                let isOnline = isCurrentDevice && cm.isOnline

                if isOnline {
                    // Show connection type if currently online
                    HStack(spacing: 4) {
                        Image(systemName: cm.transport == .wifi ? "wifi" : "antenna.radiowaves.left.and.right")
                            .font(.caption)
                        Text(cm.transport == .wifi ? "Connected via WiFi" : "Connected via Bluetooth")
                            .font(.caption)
                    }
                    .foregroundStyle(.green)
                } else if let lastSeen = device.lastSeenAt {
                    Text("Last seen \(lastSeen.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteDevice(_ device: SavedDevice) {
        modelContext.delete(device)
        try? modelContext.save()
    }

    private func deleteDevices(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedDevices[index])
        }
        try? modelContext.save()
    }
}
