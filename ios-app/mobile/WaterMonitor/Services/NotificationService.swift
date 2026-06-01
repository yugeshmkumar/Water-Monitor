import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    // Track last notification state per device (not just time)
    private var lastNotificationState: [String: TankState] = [:]
    private var lastNotificationTime: [String: Date] = [:]
    private var notificationCount: [String: Int] = [:]  // Track how many times we've notified for current state
    
    // INDUSTRY STANDARD: Adaptive cooldown based on severity and escalation
    // Critical alerts use progressive escalation, not fixed cooldowns
    private let criticalAlertIntervals: [TimeInterval] = [
        0,      // Immediate first alert
        30,     // 30 seconds for second alert
        60,     // 1 minute
        120,    // 2 minutes
        300     // 5 minutes (max - then repeat at 5min intervals)
    ]
    
    private let importantAlertIntervals: [TimeInterval] = [
        0,      // Immediate first alert
        300,    // 5 minutes
        900,    // 15 minutes
        1800    // 30 minutes (max - then repeat at 30min intervals)
    ]
    
    // Low-priority warnings: Only on state change
    private let normalAlertIntervals: [TimeInterval] = [0]  // Once only
    
    enum TankState: Equatable {
        case normal
        case low           // ≤ low threshold
        case nearlyFull    // ≥ high threshold but < 100%
        case full          // 100%
        case critical      // ≤ 5% (emergency)
        
        var severity: Int {
            switch self {
            case .critical: return 3
            case .full: return 2
            case .low: return 2
            case .nearlyFull: return 1
            case .normal: return 0
            }
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("[Notifications] Permission granted")
                } else if let error = error {
                    print("[Notifications] Permission denied: \(error)")
                }
            }
    }
    
    // MARK: - Tank Level Alerts (Smart State-Based)
    
    func checkTankLevel(nodeID: String, levelPct: Int, alertLowPct: Int, alertHighPct: Int, motorName: String? = nil) {
        // Determine current state
        let currentState = determineState(levelPct: levelPct, alertLowPct: alertLowPct, alertHighPct: alertHighPct)
        let previousState = lastNotificationState[nodeID] ?? .normal
        
        // ✅ ALWAYS trigger in-app alerts (they have their own cooldown logic)
        // This ensures immediate visual feedback when app is open
        InAppAlertManager.shared.checkTankLevel(
            nodeID: nodeID,
            levelPct: levelPct,
            alertLowPct: alertLowPct,
            alertHighPct: alertHighPct,
            hasMotorControl: motorName != nil,
            motorName: motorName
        )
        
        // Check if we should send system notification
        let shouldNotify = shouldSendNotification(
            nodeID: nodeID,
            currentState: currentState,
            previousState: previousState
        )
        
        guard shouldNotify else {
            // Optionally log why we're skipping
            if currentState != .normal && currentState == previousState {
                print("[Notifications] ⏸️ Skipping \(nodeID): Same state (\(currentState)), waiting for cooldown")
            }
            return
        }
        
        // Send appropriate notification
        print("[Notifications] 🔔 State change for \(nodeID): \(previousState) → \(currentState) at \(levelPct)%")
        
        switch currentState {
        case .critical:
            sendCriticalLowAlert(nodeID: nodeID, levelPct: levelPct, motorName: motorName)
        case .low:
            sendTankLowAlert(nodeID: nodeID, levelPct: levelPct, motorName: motorName)
        case .full:
            sendTankFullAlert(nodeID: nodeID, levelPct: levelPct, motorName: motorName)
        case .nearlyFull:
            sendTankHighAlert(nodeID: nodeID, levelPct: levelPct, motorName: motorName)
        case .normal:
            // Returned to normal - could send "Tank level normalized" if desired
            break
        }
        
        // Update tracking
        lastNotificationState[nodeID] = currentState
        lastNotificationTime[nodeID] = Date()
        
        // Increment count for escalating notifications
        let count = notificationCount[nodeID] ?? 0
        notificationCount[nodeID] = count + 1
    }
    
    private func determineState(levelPct: Int, alertLowPct: Int, alertHighPct: Int) -> TankState {
        if levelPct <= 5 {
            return .critical  // Emergency: ≤5%
        } else if levelPct <= alertLowPct {
            return .low
        } else if levelPct == 100 {
            return .full
        } else if levelPct >= alertHighPct {
            return .nearlyFull
        } else {
            return .normal
        }
    }
    
    private func shouldSendNotification(nodeID: String, currentState: TankState, previousState: TankState) -> Bool {
        // ALWAYS notify on state changes (industry standard)
        if currentState != previousState {
            print("[Notifications] ✅ State changed: \(previousState) → \(currentState)")
            // Reset count for new state
            notificationCount[nodeID] = 0
            return true
        }
        
        // If same state, use ESCALATING intervals (prevents missing critical alerts)
        guard let lastTime = lastNotificationTime[nodeID] else {
            // First notification ever
            notificationCount[nodeID] = 0
            return true
        }
        
        let timeSinceLast = Date().timeIntervalSince(lastTime)
        let count = notificationCount[nodeID] ?? 0
        
        switch currentState {
        case .critical:
            // CRITICAL: Progressive escalation (0s → 30s → 1min → 2min → 5min)
            // Industry standard: Don't let users miss life-safety alerts!
            let interval = getEscalatingInterval(count: count, intervals: criticalAlertIntervals)
            let shouldNotify = timeSinceLast >= interval
            if shouldNotify {
                print("[Notifications] 🚨 CRITICAL escalation #\(count + 1) after \(Int(timeSinceLast))s (threshold: \(Int(interval))s)")
            }
            return shouldNotify
            
        case .full, .low:
            // IMPORTANT: Progressive escalation (0s → 5min → 15min → 30min)
            // Prevents tank overflow or running dry
            let interval = getEscalatingInterval(count: count, intervals: importantAlertIntervals)
            let shouldNotify = timeSinceLast >= interval
            if shouldNotify {
                print("[Notifications] ⚠️ IMPORTANT reminder #\(count + 1) after \(Int(timeSinceLast))s (threshold: \(Int(interval))s)")
            }
            return shouldNotify
            
        case .nearlyFull:
            // WARNING: Progressive escalation (0s → 5min → 15min → 30min)
            let interval = getEscalatingInterval(count: count, intervals: importantAlertIntervals)
            let shouldNotify = timeSinceLast >= interval
            if shouldNotify {
                print("[Notifications] 💡 WARNING reminder #\(count + 1) after \(Int(timeSinceLast))s (threshold: \(Int(interval))s)")
            }
            return shouldNotify
            
        case .normal:
            // Normal state - no recurring notifications needed
            return false
        }
    }
    
    /// Gets the appropriate interval based on notification count (escalating pattern)
    /// Industry standard: Start aggressive, back off gradually
    private func getEscalatingInterval(count: Int, intervals: [TimeInterval]) -> TimeInterval {
        // Use array index, but cap at last interval for indefinite repeats
        let index = min(count, intervals.count - 1)
        return intervals[index]
    }
    
    private func sendCriticalLowAlert(nodeID: String, levelPct: Int, motorName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 CRITICAL - Tank Nearly Empty"
        
        if let motor = motorName {
            content.body = "⚠️ \(nodeID) at \(levelPct)%! Turn on \(motor) IMMEDIATELY to prevent shutdown."
        } else {
            content.body = "⚠️ \(nodeID) at \(levelPct)%! Refill IMMEDIATELY to prevent damage."
        }
        
        // Critical alert uses special sound and interruption level (iOS 15+)
        content.sound = .defaultCritical
        content.interruptionLevel = .critical  // Breaks through Focus/DND
        content.categoryIdentifier = "TANK_CRITICAL"
        
        let request = UNNotificationRequest(
            identifier: "tank-critical-\(nodeID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        print("[Notifications] 🚨 Sending CRITICAL alert for \(nodeID)")
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] ❌ Failed to send critical alert: \(error)")
            } else {
                print("[Notifications] ✅ CRITICAL alert sent successfully for \(nodeID)")
            }
        }
    }
    
    private func sendTankLowAlert(nodeID: String, levelPct: Int, motorName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Tank Low - \(nodeID)"
        
        if let motor = motorName {
            content.body = "Water level is \(levelPct)%. Turn on \(motor) to refill."
        } else {
            content.body = "Water level is \(levelPct)%. Tank needs refilling."
        }
        
        content.sound = .default
        content.categoryIdentifier = "TANK_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "tank-low-\(nodeID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        print("[Notifications] 📤 Sending LOW alert for \(nodeID)")
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] ❌ Failed to send low alert: \(error)")
            } else {
                print("[Notifications] ✅ LOW alert sent successfully for \(nodeID)")
            }
        }
    }
    
    private func sendTankFullAlert(nodeID: String, levelPct: Int, motorName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "💧 Tank Full - \(nodeID)"
        
        if let motor = motorName {
            content.body = "Tank at \(levelPct)%. Turn off \(motor) NOW to prevent overflow."
        } else {
            content.body = "Tank at \(levelPct)%. Stop filling to prevent overflow."
        }
        
        // Full tank is time-sensitive (prevent overflow/waste)
        content.sound = .default
        content.interruptionLevel = .timeSensitive  // Higher priority than normal
        content.categoryIdentifier = "TANK_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "tank-full-\(nodeID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        print("[Notifications] 📤 Sending FULL alert for \(nodeID)")
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] ❌ Failed to send full alert: \(error)")
            } else {
                print("[Notifications] ✅ FULL alert sent successfully for \(nodeID)")
            }
        }
    }

    private func sendTankHighAlert(nodeID: String, levelPct: Int, motorName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "✅ Tank Full - \(nodeID)"
        
        if let motor = motorName {
            content.body = "Water level is \(levelPct)%. Turn off \(motor) now."
        } else {
            content.body = "Water level is \(levelPct)%. Tank is full."
        }
        
        content.sound = .default
        content.categoryIdentifier = "TANK_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "tank-high-\(nodeID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )
        
        print("[Notifications] 📤 Sending HIGH alert for \(nodeID)")
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] ❌ Failed to send high alert: \(error)")
            } else {
                print("[Notifications] ✅ HIGH alert sent successfully for \(nodeID)")
            }
        }
    }

    // Called each time InsightsEngine produces fresh alerts (on app foreground / new reading)
    func scheduleAlerts(_ alerts: [InsightAlert]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for alert in alerts where alert.severity != .info {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body  = alert.body
            content.sound = alert.severity == .critical ? .defaultCritical : .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: alert.id.uuidString,
                                               content: content,
                                               trigger: trigger)
            center.add(request)
        }
    }

    // Immediate one-shot notification (e.g. sensor went offline mid-session)
    func sendImmediate(title: String, body: String, critical: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = critical ? .defaultCritical : .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                           content: content,
                                           trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
