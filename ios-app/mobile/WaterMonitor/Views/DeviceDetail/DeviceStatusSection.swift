import SwiftUI

/// Extracted status section from DeviceDetailView
struct DeviceStatusSection: View {
    let device: SavedDevice
    @ObservedObject var viewModel: DashboardVM
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Status")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Connection")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Battery")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(viewModel.batteryLevel))%")
                        .font(.body)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DeviceStatusSection(device: SavedDevice.sample, viewModel: DashboardVM())
}
