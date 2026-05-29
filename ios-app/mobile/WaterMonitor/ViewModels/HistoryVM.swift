import Foundation
import SwiftData

enum HistoryRange: String, CaseIterable {
    case day = "24h"
    case week = "7d"

    var lookback: TimeInterval {
        switch self {
        case .day:  return 24 * 3600
        case .week: return 7 * 24 * 3600
        }
    }
}

@Observable
final class HistoryVM {
    var range: HistoryRange = .day
    var readings: [DeviceReading] = []

    private let cache: DataCache

    init(cache: DataCache) {
        self.cache = cache
        fetch()
    }

    func fetch() {
        let since = Date().addingTimeInterval(-range.lookback)
        readings = cache.readings(since: since)
    }

    var averagePct: Int {
        guard !readings.isEmpty else { return 0 }
        return readings.reduce(0) { $0 + $1.levelPct } / readings.count
    }

    var minPct: Int { readings.map(\.levelPct).min() ?? 0 }
    var maxPct: Int { readings.map(\.levelPct).max() ?? 0 }
}
