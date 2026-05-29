import Foundation
import SwiftData

enum NodeType: String, Codable {
    case sensor   // Node A — JSN-SR04T ultrasonic sensor unit
    case motor    // Node B — relay motor controller (Phase 2)
}

@Model
final class SavedDevice {
    var nodeID: String          // firmware node_id, e.g. "sensor-a"
    var type: NodeType
    var displayName: String     // user-assigned label, e.g. "Rooftop Tank Sensor"
    var lastHost: String        // last known mDNS hostname or IP, e.g. "sensor-a.local"
    var lastIP: String?         // last known IP address, e.g. "192.168.1.100"
    var addedAt: Date
    var lastSeenAt: Date?
    var tankID: UUID?           // which Tank this node belongs to (nil until tank is created)

    init(nodeID: String,
         type: NodeType = .sensor,
         displayName: String = "",
         lastHost: String = "",
         lastIP: String? = nil) {
        self.nodeID      = nodeID
        self.type        = type
        self.displayName = displayName.isEmpty ? nodeID : displayName
        self.lastHost    = lastHost.isEmpty ? "\(nodeID).local" : lastHost
        self.lastIP      = lastIP
        self.addedAt     = Date()
    }
}
