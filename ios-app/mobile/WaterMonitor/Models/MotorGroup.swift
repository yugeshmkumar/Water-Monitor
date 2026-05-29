import Foundation
import SwiftData

// A MotorGroup links one or more tanks to one or more motor controllers.
// One group = one pump system. Multiple groups = independent pump systems.
//
// Examples:
//   Single tank + single pump → 1 group, 1 tank, 1 motor
//   Two tanks + one shared pump → 1 group, 2 tanks, 1 motor
//   Two tanks + two independent pumps → 2 groups, 1 tank each, 1 motor each
//   One tank + two parallel pumps → 1 group, 1 tank, 2 motors

@Model
final class MotorGroup {
    var displayName: String         // "Main Pump", "Building B Pumps"
    var tankIDs: [UUID]             // which tanks this group monitors
    var motorNodeIDs: [String]      // nodeIDs of Node B motor controllers in this group
    var autoStartPct: Int           // trigger motor ON when level drops below this %
    var autoStopPct: Int            // trigger motor OFF when level rises above this %
    var maxRunMinutes: Int          // safety cut-off to prevent pump running dry
    var isAutoModeEnabled: Bool     // whether automation is active (Phase 2)
    var createdAt: Date

    init(displayName: String,
         tankIDs: [UUID] = [],
         motorNodeIDs: [String] = [],
         autoStartPct: Int = 20,
         autoStopPct: Int = 90,
         maxRunMinutes: Int = 45) {
        self.displayName      = displayName
        self.tankIDs          = tankIDs
        self.motorNodeIDs     = motorNodeIDs
        self.autoStartPct     = autoStartPct
        self.autoStopPct      = autoStopPct
        self.maxRunMinutes    = maxRunMinutes
        self.isAutoModeEnabled = false
        self.createdAt        = Date()
    }
}
