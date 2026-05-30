import SwiftUI
import SwiftData
import CoreBluetooth

/// Example of how DevicesHubView would look with multi-connection support
struct DevicesHubViewMulti: View {
    @Environment(MultiConnectionManager.self) private var mcm
    @Environment(\.modelContext) private var modelContext
    @Query private var savedDevices: [SavedDevice]

    @Binding var showAddDevice: Bool
    @State private var searchTimeout = false

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
                        NavigationLink(destination: DeviceDetailViewMulti(device: device)) {
                            DeviceCardViewMulti(device: device)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Devices (\(mcm.connectedDevices.count)/\(savedDevices.count))")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddDevice = true } label: {
                        Image(systemName: "plus")
                    }
                }
                
                // Optional: Add refresh button
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        connectAllDevices()
                    } label: {
                        Label("Reconnect All", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            // Connect to ALL devices concurrently when view appears
            connectAllDevices()
        }
    }

    private func connectAllDevices() {
        print("[DevicesHub] Connecting to \(savedDevices.count) devices concurrently...")
        
        // This will connect to ALL devices at once!
        for device in savedDevices {
            let host = device.lastIP ?? device.lastHost
            mcm.connectDevice(nodeID: device.nodeID, host: host)
        }
    }
}

// MARK: - Multi-Connection Device Card

struct DeviceCardViewMulti: View {
    @Environment(MultiConnectionManager.self) private var mcm
    let device: SavedDevice
    
    var body: some View {
        HStack(spacing: 12) {
            // Connection status indicator
            Circle()
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                
                if let status = mcm.getStatus(for: device.nodeID) {
                    Text("\(status.levelPct)% • \(String(format: "%.1f", status.distanceCM)) cm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Level indicator
            if let status = mcm.getStatus(for: device.nodeID) {
                CircularProgressView(percentage: status.levelPct)
                    .frame(width: 50, height: 50)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var isConnected: Bool {
        mcm.isConnected(nodeID: device.nodeID)
    }
}

struct CircularProgressView: View {
    let percentage: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                .stroke(color, lineWidth: 4)
                .rotationEffect(.degrees(-90))
            
            Text("\(percentage)%")
                .font(.caption2)
                .bold()
        }
    }
    
    private var color: Color {
        switch percentage {
        case 0...20: return .red
        case 21...40: return .orange
        case 41...60: return .yellow
        default: return .green
        }
    }
}

// MARK: - Multi-Connection Device Detail

struct DeviceDetailViewMulti: View {
    @Environment(MultiConnectionManager.self) private var mcm
    let device: SavedDevice
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let status = mcm.getStatus(for: device.nodeID) {
                    // Show device data
                    Text("\(status.levelPct)%")
                        .font(.system(size: 72, weight: .bold))
                    
                    Text("Water Level")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView(
                        "Device Offline",
                        systemImage: "wifi.slash",
                        description: Text("Waiting for connection...")
                    )
                }
            }
            .padding()
        }
        .navigationTitle(device.displayName)
    }
}
