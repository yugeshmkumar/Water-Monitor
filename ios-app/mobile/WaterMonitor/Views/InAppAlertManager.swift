import SwiftUI

/// Manages in-app alert dialogs shown when app is active
/// Complements system notifications with immediate visual feedback
@Observable
final class InAppAlertManager {
    static let shared = InAppAlertManager()
    
    // Current alert to display
    private(set) var currentAlert: TankAlert?
    
    // Track last alert per device to prevent spam
    private var lastAlertTime: [String: Date] = [:]
    private var lastAlertState: [String: AlertState] = [:]
    
    // Minimum time between same alerts (shorter than notifications since user is actively viewing)
    private let minAlertInterval: TimeInterval = 60 // 1 minute
    
    enum AlertState: Equatable {
        case critical  // ≤5%
        case low       // ≤ low threshold
        case full      // 100%
        case nearlyFull // ≥ high threshold
    }
    
    struct TankAlert: Identifiable {
        let id = UUID()
        let nodeID: String
        let levelPct: Int
        let state: AlertState
        let hasMotorControl: Bool
        let motorName: String?
        
        var title: String {
            switch state {
            case .critical:
                return "🚨 CRITICAL - Tank Nearly Empty"
            case .low:
                return "⚠️ Tank Low"
            case .full:
                return "💧 Tank Full"
            case .nearlyFull:
                return "✅ Tank Nearly Full"
            }
        }
        
        var message: String {
            let baseMessage: String
            switch state {
            case .critical:
                baseMessage = "\(nodeID) is at \(levelPct)%! Refill IMMEDIATELY to prevent damage."
            case .low:
                baseMessage = "\(nodeID) is at \(levelPct)%. Tank needs refilling soon."
            case .full:
                baseMessage = "\(nodeID) has reached \(levelPct)%. Stop filling to prevent overflow."
            case .nearlyFull:
                baseMessage = "\(nodeID) is at \(levelPct)%. Tank is nearly full."
            }
            
            // Add motor control suggestion if no motor attached
            if !hasMotorControl {
                switch state {
                case .critical, .low:
                    return baseMessage + "\n\n💡 Tip: Connect a motor controller to automate filling."
                case .full, .nearlyFull:
                    return baseMessage + "\n\n💡 Tip: Connect a motor controller to prevent overflow."
                }
            }
            
            return baseMessage
        }
        
        var severity: Int {
            switch state {
            case .critical: return 3
            case .low: return 2
            case .full: return 2
            case .nearlyFull: return 1
            }
        }
    }
    
    /// Check if in-app alert should be shown (only when app is active)
    func checkTankLevel(
        nodeID: String,
        levelPct: Int,
        alertLowPct: Int,
        alertHighPct: Int,
        hasMotorControl: Bool,
        motorName: String?
    ) {
        // Determine current state
        let currentState = determineState(
            levelPct: levelPct,
            alertLowPct: alertLowPct,
            alertHighPct: alertHighPct
        )
        
        guard let state = currentState else {
            // Normal level - clear any existing alert for this device
            if currentAlert?.nodeID == nodeID {
                currentAlert = nil
            }
            return
        }
        
        // Check if we should show alert
        guard shouldShowAlert(nodeID: nodeID, state: state) else {
            return
        }
        
        // Create and show alert
        let alert = TankAlert(
            nodeID: nodeID,
            levelPct: levelPct,
            state: state,
            hasMotorControl: hasMotorControl,
            motorName: motorName
        )
        
        currentAlert = alert
        lastAlertTime[nodeID] = Date()
        lastAlertState[nodeID] = state
        
        print("[InAppAlert] 📱 Showing alert: \(alert.title) - \(nodeID) at \(levelPct)%")
    }
    
    /// Dismiss the current alert
    func dismissAlert() {
        currentAlert = nil
    }
    
    private func determineState(levelPct: Int, alertLowPct: Int, alertHighPct: Int) -> AlertState? {
        if levelPct <= 5 {
            return .critical
        } else if levelPct <= alertLowPct {
            return .low
        } else if levelPct == 100 {
            return .full
        } else if levelPct >= alertHighPct {
            return .nearlyFull
        } else {
            return nil // Normal range
        }
    }
    
    private func shouldShowAlert(nodeID: String, state: AlertState) -> Bool {
        // Always show on state change
        if let lastState = lastAlertState[nodeID], lastState != state {
            print("[InAppAlert] ✅ State changed: \(lastState) → \(state)")
            return true
        }
        
        // Check time-based cooldown for same state
        guard let lastTime = lastAlertTime[nodeID] else {
            // First alert ever for this device
            return true
        }
        
        let timeSinceLast = Date().timeIntervalSince(lastTime)
        
        // Critical alerts repeat more frequently
        let interval: TimeInterval = state == .critical ? 30 : minAlertInterval
        
        if timeSinceLast >= interval {
            print("[InAppAlert] ⏰ Cooldown elapsed (\(Int(timeSinceLast))s), showing repeat alert")
            return true
        }
        
        return false
    }
}

// MARK: - SwiftUI View Modifier

extension View {
    /// Attach in-app tank alerts to this view
    func tankAlertDialog() -> some View {
        modifier(TankAlertModifier())
    }
}

private struct TankAlertModifier: ViewModifier {
    @State private var alertManager = InAppAlertManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                alertManager.currentAlert?.title ?? "Alert",
                isPresented: Binding(
                    get: { alertManager.currentAlert != nil },
                    set: { if !$0 { alertManager.dismissAlert() } }
                ),
                presenting: alertManager.currentAlert
            ) { alert in
                Button("OK", role: .cancel) {
                    alertManager.dismissAlert()
                }
                
                // Add action buttons based on state
                if alert.state == .full || alert.state == .nearlyFull {
                    Button("View Tank") {
                        alertManager.dismissAlert()
                        // User can navigate to tank detail from here if needed
                    }
                }
            } message: { alert in
                Text(alert.message)
            }
    }
}
