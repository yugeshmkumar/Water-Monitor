import Foundation
import SwiftData

@Model
final class Tank {
    var id: UUID
    var displayName: String     // "Rooftop Tank", "Underground Cistern"
    var location: String        // optional free-text location note
    var sensorNodeID: String?   // nodeID of the Node A serving this tank
    var tankEmptyMM: Double     // distance from sensor when tank is empty (millimeters)
    var tankFullMM: Double      // distance from sensor when tank is full (millimeters)
    var tankVolumeL: Int        // total capacity in litres
    var alertLowPct: Int        // notify below this fill %
    var alertHighPct: Int       // notify above this fill %
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var readings: [DeviceReading] = []

    init(displayName: String,
         sensorNodeID: String? = nil,
         tankEmptyMM: Double = 1500,
         tankFullMM: Double = 200,
         tankVolumeL: Int = 1000,
         alertLowPct: Int = 15,
         alertHighPct: Int = 95) {
        self.id            = UUID()
        self.displayName   = displayName
        self.location      = ""
        self.sensorNodeID  = sensorNodeID
        self.tankEmptyMM   = tankEmptyMM
        self.tankFullMM    = tankFullMM
        self.tankVolumeL   = tankVolumeL
        self.alertLowPct   = alertLowPct
        self.alertHighPct  = alertHighPct
        self.createdAt     = Date()
    }
}
