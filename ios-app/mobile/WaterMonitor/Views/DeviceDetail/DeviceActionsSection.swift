import SwiftUI

/// Extracted actions section from DeviceDetailView
struct DeviceActionsSection: View {
    let device: SavedDevice
    @ObservedObject var viewModel: DashboardVM
    @State private var showSettings = false
    @State private var showCalibration = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { showSettings = true }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Device Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .sheet(isPresented: $showSettings) {
                DeviceConfigView(device: device)
            }
            
            Button(action: { showCalibration = true }) {
                HStack {
                    Image(systemName: "ruler")
                    Text("Calibrate")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .sheet(isPresented: $showCalibration) {
                TankCalibrationView(device: device)
            }
        }
    }
}

#Preview {
    DeviceActionsSection(device: SavedDevice.sample, viewModel: DashboardVM())
}
