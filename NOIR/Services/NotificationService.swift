import Foundation
import UserNotifications

protocol NotificationCenterClient: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationCenterClient {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            requestAuthorization(options: options) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
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

    func notifyExpenseAdded(name: String, amount: Double, currencyCode: String? = nil) async throws {
        guard try await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: L10n.Notification.expenseAddedTitle)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
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
