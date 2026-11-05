import Foundation
import UserNotifications

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()

    private let center: NotificationCenterClient
    private let defaults: UserDefaults

    init(center: NotificationCenterClient = UNUserNotificationCenter.current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
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

    var monthlyBudget: Double { defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) }

    // Reading and claiming the level happen with no await between them, so two checks never send the same one.
    func notifyBudgetIfNeeded(spent: Decimal, now: Date = .now, calendar: Calendar = .current) async {
        guard await canPostNotifications() else { return }
        let budget = monthlyBudget
        let lastSent = BudgetAlert.lastSent(
            state: defaults.string(forKey: BudgetAlert.storageKey), now: now, calendar: calendar
        )
        guard let alert = BudgetAlert.next(total: spent, budget: budget, lastSent: lastSent) else { return }
        let state = BudgetAlert.state(for: alert, now: now, calendar: calendar)
        defaults.set(state, forKey: BudgetAlert.storageKey)

        let content = UNMutableNotificationContent()
        content.title = String(localized: alert == .over ? L10n.Notification.budgetOverTitle : L10n.Notification.budgetNearTitle)
        content.body = String(localized: L10n.Notification.budgetBody(
            spent: CurrencyPreference.string(for: spent, code: currencyCode),
            budget: CurrencyPreference.wholeString(for: budget, code: currencyCode)
        ))
        content.sound = .default

        let request = UNNotificationRequest(identifier: "\(BudgetAlert.storageKey).\(state)", content: content, trigger: nil)
        try? await center.add(request)
    }

    static func recurringIdentifier(_ id: UUID) -> String { "recurring.\(id.uuidString)" }

    // Nothing is scheduled (and a pending or delivered one is dropped) without permission or for a past moment.
    func scheduleRecurringReminder(_ recurring: RecurringExpenseDTO, now: Date = .now, calendar: Calendar = .current) async {
        var day = calendar.dateComponents([.year, .month, .day], from: recurring.nextDueDate)
        day.hour = 9
        guard await canPostNotifications(), let fireDate = calendar.date(from: day), fireDate > now else {
            cancelRecurringReminder(id: recurring.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: L10n.Notification.recurringDueTitle(name: recurring.name))
        content.body = CurrencyPreference.string(for: recurring.amount, code: currencyCode)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.recurringIdentifier(recurring.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: day, repeats: false)
        )
        try? await center.add(request)
    }

    func cancelRecurringReminder(id: UUID) {
        let identifiers = [Self.recurringIdentifier(id)]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private var currencyCode: String {
        defaults.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
    }
}
