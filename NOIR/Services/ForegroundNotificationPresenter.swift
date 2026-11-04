//
//  ForegroundNotificationPresenter.swift
//  NOIR
//

import Foundation
import UserNotifications

// Without a delegate the system drops notifications that arrive while the app is open, which is when most
// budget alerts happen (saving an expense).
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
