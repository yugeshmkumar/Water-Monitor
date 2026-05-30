// /Users/yugeshmluv/Work/Projects/code/Water-Monitor/os-app/WaterMonitor/WaterMonitor/Views/DeviceCardView.swift
import SwiftUI

struct DeviceCardView: View {
    @Environment(ConnectionManager.self) private var cm

    let device: SavedDevice
    let searchTimeout: Bool

    // ✅ Check if THIS specific device is connected
    private var isConnected: Bool {
        cm.isConnected(nodeID: device.nodeID)
    }
    
    // ✅ Get THIS device's status
    private var deviceStatus: DeviceStatus? {
        cm.getStatus(for: device.nodeID)
    }

    private var connectionState: ConnectionState {
        if isConnected {
            return .wifi  // All multi-connections are WiFi
        }
        return searchTimeout ? .offline : .searching
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                miniGauge
                deviceInfo
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)

            // Show "Fix Connection" only after the initial search timeout — never during active use
            if searchTimeout && connectionState == .offline {
                Divider()
                NavigationLink(destination: DeviceHealthCheckView(device: device)) {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Fix Connection")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var miniGauge: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 5)
            Circle()
                .trim(from: 0, to: isConnected ? Double(deviceStatus?.levelPct ?? 0) / 100.0 : 0)
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: deviceStatus?.levelPct)
            Text(isConnected && deviceStatus != nil ? "\(deviceStatus!.levelPct)%" : "--")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .frame(width: 60, height: 60)
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(device.displayName)
                .font(.headline)
                .lineLimit(1)

            connectionBadge

            if isConnected, let status = deviceStatus, status.distanceCM > 0 {
                Text(String(format: "%.1f cm from sensor", status.distanceCM))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if connectionState == .offline, let lastSeen = device.lastSeenAt {
                Text("Last seen \(lastSeen.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var connectionBadge: some View {
        switch connectionState {
        case .searching:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Searching…")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        case .wifi:
            Label("WiFi", systemImage: "wifi")
                .font(.caption)
                .foregroundStyle(.green)
        case .ble:
            Label("Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.blue)
        case .offline:
            Label("Offline", systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gaugeColor: Color {
        guard isConnected, 
              let config = cm.getConfig(for: device.nodeID),
              let status = deviceStatus else { return .blue }
        if status.levelPct <= config.alertLowPct { return .red }
        if status.levelPct >= config.alertHighPct { return .orange }
        return .blue
    }

    private enum ConnectionState {
        case searching, wifi, ble, offline
    }
}
