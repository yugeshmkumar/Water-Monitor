import SwiftUI

/**
 * HistoryDevicePicker — Select device for history view
 *
 * Displays:
 * - "All" devices option (empty nodeID filter)
 * - Individual device chips per saved device
 * - Current selection highlighted in blue
 * - Callback when selection changes
 *
 * Isolated device selection. Used in HistoryView.
 */
struct HistoryDevicePicker: View {
    let savedDevices: [SavedDevice]
    @Binding var selectedNodeID: String
    let onSelectionChanged: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                deviceChip("All", id: "")
                ForEach(savedDevices) { device in
                    deviceChip(device.displayName, id: device.nodeID)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func deviceChip(_ label: String, id: String) -> some View {
        let isSelected = selectedNodeID == id
        let strokeWidth: CGFloat = isSelected ? 0 : 1

        return Button {
            selectedNodeID = id
            onSelectionChanged()
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.blue : Color.clear,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay(
                    Capsule().stroke(.secondary.opacity(0.3), lineWidth: strokeWidth)
                )
        }
    }
}

#Preview {
    @State var selected = ""

    return HistoryDevicePicker(
        savedDevices: [],
        selectedNodeID: $selected,
        onSelectionChanged: {}
    )
}
