import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
