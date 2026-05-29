import Foundation

@Observable
final class DashboardVM {
    private let cm: ConnectionManager

    var status: DeviceStatus? { cm.displayStatus }  // Use last valid reading
    var currentStatus: DeviceStatus? { cm.status }  // Raw current status for sensor check
    var config: DeviceConfig? { cm.config }
    var transport: Transport { cm.transport }

    var isLow: Bool {
        guard let s = status, let c = config else { return false }
        return s.levelPct <= c.alertLowPct
    }

    var isHigh: Bool {
        guard let s = status, let c = config else { return false }
        return s.levelPct >= c.alertHighPct
    }

    init(cm: ConnectionManager) {
        self.cm = cm
    }
}
