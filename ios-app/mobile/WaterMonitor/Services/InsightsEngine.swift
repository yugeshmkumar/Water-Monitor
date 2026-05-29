import Foundation
import SwiftData

// MARK: - Value types

struct FillEvent: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let startPct: Int
    let peakPct: Int
    let volumeL: Double      // estimated from tank volume config
    let durationMinutes: Double
}

struct DrainEvent: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let startPct: Int
    let endPct: Int
    let volumeL: Double
    let durationMinutes: Double
    let isPotentialLeak: Bool   // true if drain rate is suspiciously slow/continuous
}

struct DailyUsage: Identifiable {
    let id = UUID()
    let date: Date
    let volumeL: Double
    let fillCount: Int
    let drainCount: Int
    let peakHour: Int?          // 0–23, hour of highest drain rate
}

struct InsightAlert: Identifiable {
    enum Severity { case info, warning, critical }
    let id = UUID()
    let severity: Severity
    let title: String
    let body: String
    let timestamp: Date
}

// MARK: - Engine

@Observable
final class InsightsEngine {
    var alerts:       [InsightAlert] = []
    var fillEvents:   [FillEvent]    = []
    var drainEvents:  [DrainEvent]   = []
    var dailyUsage:   [DailyUsage]   = []
    var hourlyDrain:  [Int: Double]  = [:]  // hour → avg L drained in that hour
    var weeklyTrend:  Double         = 0    // % change vs prior week (positive = up)
    var lastAnalyzed: Date?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func analyze(nodeID: String, config: DeviceConfig?) {
        let tankVolumeL = Double(config?.tankVolumeL ?? 1000)
        let readings = fetch(nodeID: nodeID, days: 14)
        guard readings.count >= 4 else { return }

        let (fills, drains) = detectEvents(readings: readings, tankVolumeL: tankVolumeL)
        fillEvents  = fills
        drainEvents = drains
        dailyUsage  = computeDailyUsage(drains: drains)
        hourlyDrain = computeHourlyPattern(drains: drains)
        weeklyTrend = computeWeeklyTrend(daily: dailyUsage)
        alerts      = generateAlerts(readings: readings, fills: fills, drains: drains,
                                     config: config, tankVolumeL: tankVolumeL)
        lastAnalyzed = Date()
    }

    // MARK: - Fetch

    private func fetch(nodeID: String, days: Int) -> [DeviceReading] {
        let since = Date().addingTimeInterval(-Double(days) * 86400)
        let pred = #Predicate<DeviceReading> { $0.timestamp >= since }
        var desc = FetchDescriptor<DeviceReading>(predicate: pred,
                                                   sortBy: [SortDescriptor(\.timestamp)])
        desc.fetchLimit = 5000
        let all = (try? context.fetch(desc)) ?? []

        return all.filter { r in
            // Match exact nodeID if specified, or if nodeID is empty fallback to any device
            let matchesNode = if nodeID.isEmpty {
                true  // fetch from all devices
            } else {
                r.nodeID == nodeID || r.nodeID == nil || r.nodeID == ""
            }
            return matchesNode && !r.isTest
        }
    }

    // MARK: - Event detection

    private func detectEvents(readings: [DeviceReading],
                              tankVolumeL: Double) -> ([FillEvent], [DrainEvent]) {
        var fills:  [FillEvent]  = []
        var drains: [DrainEvent] = []

        // State machine: scan for sustained rises (fills) or sustained drops (drains)
        // A "sustained" change requires at least 3 consecutive readings in the same direction
        // and a minimum total change of 4 % to filter sensor micro-noise.
        let minChangePct = 4
        var i = 0

        while i < readings.count - 2 {
            let r0 = readings[i]

            // ── Fill: consecutive rising readings ─────────────────────────
            if readings[i + 1].levelPct - r0.levelPct >= 2 {
                var peak = i
                var j = i + 1
                while j < readings.count && readings[j].levelPct >= readings[peak].levelPct - 2 {
                    if readings[j].levelPct > readings[peak].levelPct { peak = j }
                    j += 1
                }
                let totalRise = readings[peak].levelPct - r0.levelPct
                if totalRise >= minChangePct {
                    let vol = Double(totalRise) / 100.0 * tankVolumeL
                    let dur = readings[peak].timestamp.timeIntervalSince(r0.timestamp) / 60.0
                    fills.append(FillEvent(startTime: r0.timestamp,
                                           endTime: readings[peak].timestamp,
                                           startPct: r0.levelPct,
                                           peakPct: readings[peak].levelPct,
                                           volumeL: vol,
                                           durationMinutes: dur))
                    i = peak
                    continue
                }
            }

            // ── Drain: consecutive falling readings ───────────────────────
            if r0.levelPct - readings[i + 1].levelPct >= 2 {
                var trough = i
                var j = i + 1
                while j < readings.count && readings[j].levelPct <= readings[trough].levelPct + 2 {
                    if readings[j].levelPct < readings[trough].levelPct { trough = j }
                    j += 1
                }
                let totalDrop = r0.levelPct - readings[trough].levelPct
                if totalDrop >= minChangePct {
                    let vol = Double(totalDrop) / 100.0 * tankVolumeL
                    let dur = readings[trough].timestamp.timeIntervalSince(r0.timestamp) / 60.0
                    let rate = dur > 0 ? vol / dur : 0  // L/min

                    // Leak heuristic: very slow, continuous drain during night hours
                    let hour = Calendar.current.component(.hour, from: r0.timestamp)
                    let isNight = hour >= 23 || hour <= 5
                    let isLeak = isNight && rate < 0.15 && dur > 60   // < 0.15 L/min sustained > 1h

                    drains.append(DrainEvent(startTime: r0.timestamp,
                                             endTime: readings[trough].timestamp,
                                             startPct: r0.levelPct,
                                             endPct: readings[trough].levelPct,
                                             volumeL: vol,
                                             durationMinutes: dur,
                                             isPotentialLeak: isLeak))
                    i = trough
                    continue
                }
            }

            i += 1
        }

        return (fills, drains)
    }

    // MARK: - Aggregations

    private func computeDailyUsage(drains: [DrainEvent]) -> [DailyUsage] {
        let cal = Calendar.current
        var byDay: [Date: (vol: Double, fills: Int, drains: Int, hourVols: [Int: Double])] = [:]

        for d in drains {
            let day = cal.startOfDay(for: d.startTime)
            let hour = cal.component(.hour, from: d.startTime)
            byDay[day, default: (0, 0, 0, [:])].vol    += d.volumeL
            byDay[day, default: (0, 0, 0, [:])].drains += 1
            byDay[day, default: (0, 0, 0, [:])].hourVols[hour, default: 0] += d.volumeL
        }

        return byDay.map { (day, data) in
            let peakHour = data.hourVols.max(by: { $0.value < $1.value })?.key
            return DailyUsage(date: day, volumeL: data.vol,
                              fillCount: data.fills, drainCount: data.drains,
                              peakHour: peakHour)
        }.sorted { $0.date < $1.date }
    }

    private func computeHourlyPattern(drains: [DrainEvent]) -> [Int: Double] {
        var hourTotals: [Int: [Double]] = [:]
        let cal = Calendar.current
        for d in drains {
            let h = cal.component(.hour, from: d.startTime)
            hourTotals[h, default: []].append(d.volumeL)
        }
        return hourTotals.mapValues { vals in vals.reduce(0, +) / Double(vals.count) }
    }

    private func computeWeeklyTrend(daily: [DailyUsage]) -> Double {
        let cal = Calendar.current
        let now = Date()
        let thisWeek  = daily.filter { cal.dateComponents([.weekOfYear], from: $0.date, to: now).weekOfYear == 0 }
        let lastWeek  = daily.filter { cal.dateComponents([.weekOfYear], from: $0.date, to: now).weekOfYear == 1 }
        let thisTotal = thisWeek.reduce(0) { $0 + $1.volumeL }
        let lastTotal = lastWeek.reduce(0) { $0 + $1.volumeL }
        guard lastTotal > 0 else { return 0 }
        return (thisTotal - lastTotal) / lastTotal * 100
    }

    // MARK: - Alert generation

    private func generateAlerts(readings: [DeviceReading],
                                 fills: [FillEvent],
                                 drains: [DrainEvent],
                                 config: DeviceConfig?,
                                 tankVolumeL: Double) -> [InsightAlert] {
        var result: [InsightAlert] = []
        let now = Date()

        // ── 1. Potential water leak ────────────────────────────────────────
        let leaks = drains.filter { $0.isPotentialLeak }
        if !leaks.isEmpty {
            result.append(InsightAlert(
                severity: .critical,
                title: "Potential Water Leak Detected",
                body: "Slow continuous drain of \(String(format: "%.0f", leaks.map(\.volumeL).reduce(0, +))) L detected overnight. Check pipes and fixtures.",
                timestamp: leaks.first!.startTime
            ))
        }

        // ── 2. Abnormal daily consumption ────────────────────────────────
        let recent7 = dailyUsage.filter { now.timeIntervalSince($0.date) < 7 * 86400 }
        let prior7  = dailyUsage.filter {
            let t = now.timeIntervalSince($0.date)
            return t >= 7 * 86400 && t < 14 * 86400
        }
        if !prior7.isEmpty {
            let avgPrior = prior7.map(\.volumeL).reduce(0, +) / Double(prior7.count)
            let avgRecent = recent7.map(\.volumeL).reduce(0, +) / Double(max(recent7.count, 1))
            if avgRecent > avgPrior * 2 && avgPrior > 0 {
                result.append(InsightAlert(
                    severity: .warning,
                    title: "Water Consumption Spike",
                    body: String(format: "This week's usage (%.0f L/day) is %.0f%% above last week's average. Check for leaks or unusual activity.", avgRecent, ((avgRecent - avgPrior) / avgPrior) * 100),
                    timestamp: now
                ))
            }
        }

        // ── 3. Sensor offline / no recent readings ────────────────────────
        if let last = readings.last, now.timeIntervalSince(last.timestamp) > 3600 {
            let hours = Int(now.timeIntervalSince(last.timestamp) / 3600)
            result.append(InsightAlert(
                severity: .warning,
                title: "Sensor Not Reporting",
                body: "No readings received in the last \(hours) hour\(hours == 1 ? "" : "s"). Check device power and connectivity.",
                timestamp: last.timestamp
            ))
        }

        // ── 4. Tank critically low ────────────────────────────────────────
        if let last = readings.last,
           let low = config?.alertLowPct,
           last.levelPct <= low {
            result.append(InsightAlert(
                severity: .critical,
                title: "Water Level Critical",
                body: "Tank is at \(last.levelPct)%. Start the pump or arrange water delivery soon.",
                timestamp: last.timestamp
            ))
        }

        // ── 5. Tank has been low for an extended period ───────────────────
        let recentReadings = readings.filter { now.timeIntervalSince($0.timestamp) < 7200 }
        let alertLow = config?.alertLowPct ?? 15
        if recentReadings.count >= 4 && recentReadings.allSatisfy({ $0.levelPct <= alertLow }) {
            result.append(InsightAlert(
                severity: .warning,
                title: "Tank Low for Extended Period",
                body: "Water level has been below \(alertLow)% for over 2 hours. Check pump operation.",
                timestamp: now
            ))
        }

        // ── 6. Fill taking unusually long ─────────────────────────────────
        let recentFills = fills.filter { now.timeIntervalSince($0.startTime) < 86400 }
        let slowFills = recentFills.filter { $0.durationMinutes > 60 && $0.peakPct - $0.startPct < 30 }
        for fill in slowFills {
            result.append(InsightAlert(
                severity: .warning,
                title: "Slow Fill Detected",
                body: String(format: "Fill event took %.0f min but only raised level by %d%%. Pump may be under-performing.", fill.durationMinutes, fill.peakPct - fill.startPct),
                timestamp: fill.startTime
            ))
        }

        return result.sorted { $0.severity.rawOrder > $1.severity.rawOrder }
    }

        // MARK: - Predictions (app-side AI)

    // Current drain rate in L/hour derived from the most recent drain events.
    // Uses linear regression over the last 3 drain events to smooth out noise.
    var currentDrainRateLPerHour: Double {
        let recent = drainEvents.suffix(3)
        guard recent.count >= 2 else {
            // Fall back to single event
            return drainEvents.last.map { $0.volumeL / max($0.durationMinutes / 60.0, 0.01) } ?? 0
        }
        // Weighted average — more recent events count more
        var weightedSum = 0.0
        var totalWeight = 0.0
        for (i, event) in recent.enumerated() {
            let weight = Double(i + 1)  // index 0 = oldest, least weight
            let rate   = event.volumeL / max(event.durationMinutes / 60.0, 0.01)
            weightedSum += rate * weight
            totalWeight += weight
        }
        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    // Predict hours until tank is empty at the current drain rate.
    // Returns nil if we don't have enough data or no current level reading.
    func predictHoursToEmpty(currentPct: Int, config: DeviceConfig?) -> Double? {
        let rate = currentDrainRateLPerHour
        guard rate > 0, let cfg = config else { return nil }
        let remainingL = Double(currentPct) / 100.0 * Double(cfg.tankVolumeL)
        let emptyAtPct = Double(cfg.alertLowPct) / 100.0 * Double(cfg.tankVolumeL)
        let usableL    = max(remainingL - emptyAtPct, 0)
        return usableL / rate
    }

    // Predict when tank will reach the low-level alert threshold.
    func predictEmptyDate(currentPct: Int, config: DeviceConfig?) -> Date? {
        guard let hours = predictHoursToEmpty(currentPct: currentPct, config: config) else { return nil }
        return Date().addingTimeInterval(hours * 3600)
    }

    // 7-day usage forecast using linear regression on daily usage history.
    // Returns predicted daily volumes for the next 7 days.
    func forecastNextWeek() -> [Double] {
        guard dailyUsage.count >= 3 else {
            // Not enough data — return flat forecast from average
            let avg = averageDailyUsageL
            return Array(repeating: avg, count: 7)
        }

        // Simple linear regression: y = slope * x + intercept
        // x = day index (0, 1, 2...), y = volume
        let n   = Double(dailyUsage.count)
        let xs  = (0..<dailyUsage.count).map { Double($0) }
        let ys  = dailyUsage.map(\.volumeL)
        let xMean = xs.reduce(0, +) / n
        let yMean = ys.reduce(0, +) / n
        let sxy   = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let sxx   = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }
        let slope     = sxx > 0 ? sxy / sxx : 0
        let intercept = yMean - slope * xMean

        // Forecast next 7 days — clamp to non-negative
        return (0..<7).map { i in
            let predicted = slope * (n + Double(i)) + intercept
            return max(predicted, 0)
        }
    }

    // MARK: - Computed helpers

    var averageDailyUsageL: Double {
        guard !dailyUsage.isEmpty else { return 0 }
        return dailyUsage.map(\.volumeL).reduce(0, +) / Double(dailyUsage.count)
    }

    var peakUsageHour: Int? {
        hourlyDrain.max(by: { $0.value < $1.value })?.key
    }

    var estimatedFillsPerWeek: Double {
        let weekFills = fillEvents.filter { Date().timeIntervalSince($0.startTime) < 7 * 86400 }
        return Double(weekFills.count)
    }

    var avgFillDurationMinutes: Double {
        guard !fillEvents.isEmpty else { return 0 }
        return fillEvents.map(\.durationMinutes).reduce(0, +) / Double(fillEvents.count)
    }
}

extension InsightAlert.Severity {
    var rawOrder: Int {
        switch self {
        case .critical: return 2
        case .warning:  return 1
        case .info:     return 0
        }
    }

    var color: String {
        switch self {
        case .critical: return "red"
        case .warning:  return "orange"
        case .info:     return "blue"
        }
    }

    var systemImage: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        case .info:     return "info.circle.fill"
        }
    }
}
