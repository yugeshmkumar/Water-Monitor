import UserNotifications
import Foundation
import UIKit

@Observable
final class NotificationManager {
    private(set) var notificationsEnabled = false
    private var lastNotificationTime: [String: Date] = [:]
    private let minIntervalSeconds = 300  // 5 min cooldown between same alert type

    init() {
        Task {
            await requestPermission()
        }
    }

    private func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.notificationsEnabled = granted
            }
        } catch {
            print("[Notifications] Permission request failed: \(error)")
        }
    }

    /// Check water level and send notification if needed
    /// - Parameters:
    ///   - deviceName: User-friendly display name (e.g., "Rooftop Tank Sensor")
    ///   - nodeID: Unique device identifier for cooldown tracking (e.g., "sensor-a")
    ///   - levelPct: Current water level percentage
    ///   - alertLowPct: Low water alert threshold
    ///   - alertHighPct: High water alert threshold
    func checkAndNotify(deviceName: String, nodeID: String, levelPct: Int, alertLowPct: Int, alertHighPct: Int) {
        guard notificationsEnabled else { return }

        let cooldownKey = "\(nodeID)_last_alert"
        let lastTime = lastNotificationTime[cooldownKey]
        let timeSinceLastAlert = Date().timeIntervalSince(lastTime ?? .distantPast)

        // Don't spam notifications (5 min cooldown)
        guard timeSinceLastAlert > Double(minIntervalSeconds) else { return }

        var notification: (title: String, body: String)?

        if levelPct <= alertLowPct {
            notification = (
                title: "Tank Low",
                body: "\(deviceName): \(levelPct)% — refill needed"
            )
        } else if levelPct >= alertHighPct {
            notification = (
                title: "Tank Full",
                body: "\(deviceName): \(levelPct)% — tank is full"
            )
        }

        if let notification = notification {
            sendNotification(title: notification.title, body: notification.body)
            lastNotificationTime[cooldownKey] = Date()
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Badge handling - simply set to 1 for each notification
        // (Alternative: track count internally if needed)
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Failed to send: \(error)")
            }
        }
    }
}
