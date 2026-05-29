import SwiftUI

struct MainAppView: View {
    @State private var showAddDevice = false

    var body: some View {
        TabView {
            DevicesHubView(showAddDevice: $showAddDevice)
                .tabItem { Label("Devices", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb.fill") }

            AppSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView()
        }
        .onAppear {
            NotificationService.shared.requestPermission()
        }
    }
}
