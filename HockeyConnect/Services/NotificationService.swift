import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func updateFCMToken(_ token: String) async {
        guard let uid = AuthService.shared.currentUID else { return }
        try? await FirestoreService.shared.updateFCMToken(uid: uid, token: token)
    }
}
