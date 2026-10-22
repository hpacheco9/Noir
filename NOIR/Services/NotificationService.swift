import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private let center: NotificationCenterClient

    init(center: NotificationCenterClient = UNUserNotificationCenter.current()) {
        self.center = center
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// The raw permission state. Never prompts.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// Whether the user has allowed notifications. Never prompts.
    func canPostNotifications() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }

    /// Posts only when already authorized; permission is asked for in onboarding, never here
    /// (a user who chose "Not now" must not get the system prompt from a Shortcut).
    func notifyExpenseAdded(name: String, amount: Double, currencyCode: String? = nil) async throws {
        guard await canPostNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: L10n.Notification.expenseAddedTitle)
        let code = currencyCode
            ?? UserDefaults.standard.string(forKey: CurrencyPreference.storageKey)
            ?? CurrencyPreference.defaultCode
        let formattedAmount = CurrencyPreference.string(for: amount, code: code)
        content.body = "\(name) — \(formattedAmount)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "expense-added-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }
}
