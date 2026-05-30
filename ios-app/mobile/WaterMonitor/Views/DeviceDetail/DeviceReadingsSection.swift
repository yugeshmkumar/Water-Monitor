import SwiftUI

/// Extracted readings section from DeviceDetailView
struct DeviceReadingsSection: View {
    let device: SavedDevice
    @ObservedObject var viewModel: DashboardVM
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Reading")
                .font(.headline)
            
            if let reading = viewModel.currentReading {
                VStack(spacing: 8) {
                    ReadingRow(label: "Water Level", value: "\(reading.levelPct)%")
                    ReadingRow(label: "Distance", value: String(format: "%.1f cm", reading.distanceCM))
                    ReadingRow(label: "Last Update", value: formatDate(reading.timestamp))
                }
            } else {
                Text("No reading available")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

struct ReadingRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    DeviceReadingsSection(device: SavedDevice.sample, viewModel: DashboardVM())
}
