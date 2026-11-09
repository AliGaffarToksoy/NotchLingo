import Foundation
import UserNotifications

@MainActor enum NotificationService {
    static func request(model: AppModel) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                if let error { model.error = error.localizedDescription }
                else if !granted { model.notice = model.t("Notifications are disabled in System Settings. Direct notch pings remain optional.", "Sistem Ayarları'nda bildirim izni kapalı. Doğrudan çentik soruları isteğe bağlıdır.") }
            }
        }
    }
    static func send(model: AppModel) {
        let content = UNMutableNotificationContent()
        content.title = "NotchLingo"
        content.body = model.t("A minute of English? Tap to study your next cards.", "Bir dakikalık İngilizce? Sıradaki kartlarını çalışmak için dokun.")
        content.sound = nil
        let request = UNNotificationRequest(identifier: "notchlingo-study", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
