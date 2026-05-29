import Foundation
import SwiftData

@Model
final class DeviceReading {
    var timestamp: Date
    var nodeID: String?      // which device produced this reading (nil = legacy row)
    var readingType: String? // "level" | "motor" — future motor readings share this model
    var levelPct: Int
    var distanceCM: Double
    var sensorOk: Bool
    var isTest: Bool         // true if from device in testing_mode (calibration, etc)

    init(timestamp: Date,
         nodeID: String? = nil,
         readingType: String? = "level",
         levelPct: Int,
         distanceCM: Double,
         sensorOk: Bool,
         isTest: Bool = false) {
        self.timestamp   = timestamp
        self.nodeID      = nodeID
        self.readingType = readingType
        self.levelPct    = levelPct
        self.distanceCM  = distanceCM
        self.sensorOk    = sensorOk
        self.isTest      = isTest
    }
}
