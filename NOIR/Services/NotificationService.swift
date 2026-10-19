import Foundation
import UserNotifications

protocol NotificationCenterClient: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    /// Current permission state. Reading it never shows the system prompt.
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
}

// `nonisolated`: under default MainActor isolation the completion handlers below would be inferred
// MainActor, but UserNotifications calls them on a background queue.
extension UNUserNotificationCenter: NotificationCenterClient {
    nonisolated func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            requestAuthorization(options: options) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    nonisolated func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    nonisolated func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}

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
