// /Users/yugeshmluv/Work/Projects/code/Water-Monitor/os-app/WaterMonitor/WaterMonitor/Views/DevicesHubView.swift
import SwiftUI
import SwiftData
import CoreBluetooth

struct DevicesHubView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext
    @Query private var savedDevices: [SavedDevice]

    @Binding var showAddDevice: Bool
    @State private var searchTimeout = false
    @State private var retryTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if savedDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: "drop",
                        description: Text("Tap + to add your first sensor.")
                    )
                } else {
                    List(savedDevices) { device in
                        NavigationLink(destination: DeviceDetailView(device: device)) {
                            DeviceCardView(device: device, searchTimeout: searchTimeout)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Devices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddDevice = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear { startSearch() }
        .onDisappear { retryTask?.cancel() }
        .onChange(of: cm.ble.deviceConfig) { _, config in
            guard let nodeID = config?.nodeID, !nodeID.isEmpty else { return }
            guard cm.transport == .ble else { return }
            if let device = savedDevices.first(where: { $0.nodeID == nodeID }) {
                cm.upgradeToWiFi(preferredIP: device.lastIP)
            }
        }
    }

    private func startSearch() {
        searchTimeout = false
        for device in savedDevices where device.type == .sensor {
            let host = (device.lastIP?.isEmpty == false) ? device.lastIP! : device.lastHost
            cm.tryWiFi(host: host)
        }
        cm.startBLEScan()
        startBLEAutoConnect()
        Task {
            try? await Task.sleep(for: .seconds(15))
            if !cm.isOnline { searchTimeout = true }
            // After timeout, retry WiFi every 30s for devices that may have just booted
            startPeriodicRetry()
        }
    }

    private func startPeriodicRetry() {
        retryTask = Task {
            while !cm.isOnline {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                for device in savedDevices where device.type == .sensor {
                    let host = (device.lastIP?.isEmpty == false) ? device.lastIP! : device.lastHost
                    cm.tryWiFi(host: host)
                }
            }
        }
    }

    private func startBLEAutoConnect() {
        Task {
            while !cm.isOnline {
                try? await Task.sleep(for: .seconds(1))
                guard cm.transport != .wifi else { return }
                guard cm.ble.bleState != .connected, cm.ble.bleState != .connecting else { continue }
                for peripheral in cm.ble.discovered {
                    if let name = peripheral.name,
                       savedDevices.contains(where: { $0.nodeID == name }) {
                        cm.ble.connect(to: peripheral)
                        return
                    }
                }
            }
        }
    }
}
