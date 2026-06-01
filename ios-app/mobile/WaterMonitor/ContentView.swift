import SwiftUI
import SwiftData

enum AppScreen {
    case launching, welcome, home
}

struct ContentView: View {
    @Environment(ConnectionManager.self) private var cm
    @Environment(\.modelContext) private var modelContext

    @Query private var savedDevices: [SavedDevice]
    @State private var screen: AppScreen = .launching

    var body: some View {
        currentScreen
            .onAppear {
                resolveInitialScreen()
                setupConnectionCallbacks()
            }
            .onChange(of: cm.ble.deviceConfig) { _, config in
                handleBLEDeviceConfigChange(config)
            }
            .onChange(of: cm.isOnline) { _, online in
                if online, cm.transport == .wifi {
                    screen = .home
                }
            }
            .onChange(of: cm.status?.localIP) { _, newIP in
                handleIPAddressChange(newIP)
            }
            .onChange(of: cm.wifi.liveStatus?.ts) { _, _ in
                // WiFi reading arrived - update device activity
                if let nodeID = cm.config?.nodeID, !nodeID.isEmpty {
                    updateDeviceActivity(nodeID)
                }
            }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screen {
        case .launching:
            splashView
        case .welcome:
            WelcomeView(onAddDevice: { screen = .home })
        case .home:
            MainAppView()
        }
    }

    private var splashView: some View {
        VStack(spacing: 20) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300)
            Text("Water Monitor")
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State machine

    private func resolveInitialScreen() {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            screen = savedDevices.isEmpty ? .welcome : .home
        }
    }

    private func handleBLEDeviceConfigChange(_ config: DeviceConfig?) {
        guard config != nil, cm.transport == .ble else { return }
        guard let nodeID = config?.nodeID, !nodeID.isEmpty else { return }

        if let knownDevice = savedDevices.first(where: { $0.nodeID == nodeID }) {
            cm.upgradeToWiFi(preferredIP: knownDevice.lastIP)
            screen = .home
        }
        // Unknown device is handled by AddDeviceView
    }

    private func handleIPAddressChange(_ newIP: String?) {
        guard let ip = newIP, !ip.isEmpty else { return }
        guard let nodeID = cm.config?.nodeID else { return }
        let isIP = ip.range(of: #"^\d+\.\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
        guard isIP else { return }
        guard let device = savedDevices.first(where: { $0.nodeID == nodeID }) else { return }
        guard device.lastIP != ip else { return }
        device.lastIP = ip
        device.lastSeenAt = Date()
        try? modelContext.save()
    }

    private func setupConnectionCallbacks() {
        cm.onDeviceActivity = { nodeID in
            self.updateDeviceActivity(nodeID)
        }
        cm.onUpdateDevice = { nodeID in
            self.updateDeviceActivity(nodeID)
        }
        cm.onDeviceIPUpdated = { nodeID, ip in
            self.updateDeviceIP(nodeID, ip)
        }
    }

    private func updateDeviceActivity(_ nodeID: String) {
        guard let device = savedDevices.first(where: { $0.nodeID == nodeID }) else { return }
        device.lastSeenAt = Date()
        try? modelContext.save()
    }

    private func updateDeviceIP(_ nodeID: String, _ ip: String) {
        guard let device = savedDevices.first(where: { $0.nodeID == nodeID }) else { return }
        if device.lastIP != ip {
            device.lastIP = ip
            try? modelContext.save()
        }
    }
}
