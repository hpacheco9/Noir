import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, name, budget, notifications

        var primaryActionTitle: LocalizedStringResource {
            switch self {
            case .welcome:
                L10n.Onboarding.getStarted
            case .budget:
                L10n.Onboarding.setBudget
            case .name:
                L10n.Onboarding.continue
            case .notifications:
                L10n.Onboarding.enableNotifications
            }
        }
    }

    /// What the notifications step should offer, from the system's current permission.
    enum NotificationPermission {
        /// Not read yet, or not asked yet: the primary button shows the system prompt.
        case undetermined
        /// Denied in Settings: the primary button opens the app's notification settings.
        case denied
        /// Already allowed: the primary button just continues.
        case allowed
    }

    var step: Step = .welcome
    private(set) var notificationPermission: NotificationPermission = .undetermined
    var name = ""
    var budget: Double = 1000

    private let notificationService: NotificationService

    /// Pass a `NotificationService(center:)` backed by a fake `NotificationCenterClient` in tests; `nil` uses `.shared`.
    /// (A `.shared` default argument would be evaluated off the main actor.)
    init(notificationService: NotificationService? = nil) {
        self.notificationService = notificationService ?? .shared
    }

    var canAdvance: Bool {
        switch step {
        case .name:
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            true
        }
    }

    /// The primary button's title; the notifications step follows the permission state.
    var primaryActionTitle: LocalizedStringResource {
        guard step == .notifications else { return step.primaryActionTitle }
        switch notificationPermission {
        case .undetermined: return L10n.Onboarding.enableNotifications
        case .denied: return L10n.Onboarding.openSettings
        case .allowed: return L10n.Onboarding.continue
        }
    }

    /// Reads the permission (never prompts). Call when the step appears and whenever the app becomes active again,
    /// since the user may have changed it in Settings.
    func refreshNotificationPermission() async {
        switch await notificationService.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: notificationPermission = .allowed
        case .denied: notificationPermission = .denied
        case .notDetermined: notificationPermission = .undetermined
        @unknown default: notificationPermission = .undetermined
        }
    }

    var isLastStep: Bool { step == .notifications }

    func advance() {
        guard canAdvance, !isLastStep else { return }
        step = Step(rawValue: step.rawValue + 1) ?? step
    }

    func persist() {
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "profile.name")
        UserDefaults.standard.set(budget, forKey: "profile.monthlyBudget")
    }

    /// Asks for notification permission. Never throws: a denial or failure must not block onboarding.
    @discardableResult
    func requestNotificationAuthorization() async -> Bool {
        do {
            return try await notificationService.requestAuthorization()
        } catch {
            return false
        }
    }

    /// Finishes onboarding (saves the profile), optionally asking for notification permission first.
    /// The permission outcome doesn't affect completion.
    func complete(requestingNotifications: Bool) async {
        if requestingNotifications {
            await requestNotificationAuthorization()
        }
        persist()
    }
}
