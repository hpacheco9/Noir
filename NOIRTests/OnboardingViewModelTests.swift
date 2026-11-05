//
//  OnboardingViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import UserNotifications
@testable import NOIR

final class OnboardingViewModelTests {
    private struct RequestFailure: Error {}

    private final class FakeCenter: NotificationCenterClient, @unchecked Sendable {
        private(set) var requests = 0
        private let fails: Bool

        init(fails: Bool = false) { self.fails = fails }

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requests += 1
            if fails { throw RequestFailure() }
            return true
        }
        func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
        func add(_ request: UNNotificationRequest) async throws {}
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
    }

    private let suiteName = "OnboardingViewModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeViewModel(center: NotificationCenterClient = FakeCenter()) -> OnboardingViewModel {
        OnboardingViewModel(notificationService: NotificationService(center: center), defaults: defaults)
    }

    private func makeViewModelAtNotifications(center: NotificationCenterClient = FakeCenter()) -> OnboardingViewModel {
        let viewModel = makeViewModel(center: center)
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        return viewModel
    }

    @Test func advanceWalksThroughEveryStep() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        var visited = [viewModel.step]
        while !viewModel.isLastStep {
            viewModel.advance()
            visited.append(viewModel.step)
        }
        #expect(visited == [.welcome, .name, .currency, .budget, .notifications, .paywall])
    }

    @Test(arguments: ["", " ", " \n\t "])
    func blankNameBlocksTheNameStep(name: String) {
        let viewModel = makeViewModel()
        viewModel.advance()
        #expect(viewModel.step == .name)

        viewModel.name = name
        #expect(viewModel.canAdvance == false)
        viewModel.advance()
        #expect(viewModel.step == .name)
    }

    @Test func nameLetsTheNameStepAdvance() {
        let viewModel = makeViewModel()
        viewModel.advance()
        viewModel.name = " Maria "
        #expect(viewModel.canAdvance)
        viewModel.advance()
        #expect(viewModel.step == .currency)
    }

    @Test func preselectedCurrencyIsOneOfTheOffered() {
        #expect(CurrencyPreference.availableCodes.contains(makeViewModel().currencyCode))
    }

    @Test func currencyIsStoredWhenItsStepIsConfirmed() throws {
        let other = try #require(CurrencyPreference.availableCodes.first { $0 != CurrencyPreference.defaultCode })
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .currency)
        viewModel.currencyCode = other
        #expect(defaults.string(forKey: CurrencyPreference.storageKey) == nil)

        viewModel.advance()
        #expect(viewModel.step == .budget)
        #expect(defaults.string(forKey: CurrencyPreference.storageKey) == other)
    }

    @Test func theBudgetStepOffersTheDefaultAndNeverBlocks() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .budget)
        #expect(viewModel.budget == OnboardingStorage.defaultMonthlyBudget * Double(CurrencyPreference.budgetScale(for: viewModel.currencyCode)))
        #expect(viewModel.canAdvance)
        #expect(viewModel.primaryActionTitle.key == L10n.Onboarding.setBudget.key)

        viewModel.setBudget(0)
        #expect(viewModel.canAdvance)
        viewModel.advance()
        #expect(viewModel.step == .notifications)
    }

    @Test(arguments: [("EUR", 1000.0), ("USD", 1000), ("SEK", 10_000), ("NOK", 10_000), ("DKK", 10_000), ("JPY", 100_000)])
    func theDefaultBudgetFollowsTheChosenCurrency(code: String, expected: Double) {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        viewModel.currencyCode = code
        viewModel.advance()

        #expect(viewModel.step == .budget)
        #expect(viewModel.budget == expected)
    }

    @Test func theChosenBudgetIsStoredOnlyWhenPersisting() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        viewModel.setBudget(1500)
        viewModel.advance()
        #expect(viewModel.step == .notifications)
        #expect(defaults.object(forKey: OnboardingStorage.monthlyBudgetKey) == nil)

        viewModel.persist()
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == 1500)
    }

    // The ruler reports a scroll position while its step slides out; that must not reach the saved budget.
    @Test func theRulerCanOnlyChangeTheBudgetWhileItsStepIsShowing() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.setBudget(2222)
        #expect(viewModel.budget == OnboardingStorage.defaultMonthlyBudget)

        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .budget)
        viewModel.setBudget(105)
        #expect(viewModel.budget == 105)

        viewModel.advance()
        #expect(viewModel.step == .notifications)
        viewModel.setBudget(120)
        #expect(viewModel.budget == 105)

        viewModel.persist()
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == 105)
    }

    @Test func persistStoresTrimmedNameAndTheDefaultBudget() {
        let viewModel = makeViewModel()
        viewModel.name = "  Maria  "
        viewModel.persist()

        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == OnboardingStorage.defaultMonthlyBudget)
    }

    @Test(arguments: [true, false])
    func theNotificationsStepLeadsToThePaywallWithoutFinishing(requesting: Bool) async {
        let viewModel = makeViewModelAtNotifications()
        #expect(viewModel.step == .notifications)

        await viewModel.finishNotificationsStep(requesting: requesting)

        #expect(viewModel.step == .paywall)
        #expect(defaults.string(forKey: ProfileStorage.nameKey) == nil)

        viewModel.persist()
        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
    }

    @Test func permissionIsRequestedOnlyWhenAsked() async {
        let asked = FakeCenter()
        await makeViewModelAtNotifications(center: asked).finishNotificationsStep(requesting: true)
        #expect(asked.requests == 1)

        let skipped = FakeCenter()
        await makeViewModelAtNotifications(center: skipped).finishNotificationsStep(requesting: false)
        #expect(skipped.requests == 0)
    }

    @Test func aFailedPermissionRequestStillReachesThePaywall() async {
        let center = FakeCenter(fails: true)
        let viewModel = makeViewModelAtNotifications(center: center)

        await viewModel.finishNotificationsStep(requesting: true)

        #expect(center.requests == 1)
        #expect(viewModel.step == .paywall)
    }

    @Test func finishingTheNotificationsStepFromAnotherStepDoesNothing() async {
        let center = FakeCenter()
        let viewModel = makeViewModel(center: center)

        await viewModel.finishNotificationsStep(requesting: true)
        #expect(viewModel.step == .welcome)
        #expect(center.requests == 0)

        let atPaywall = makeViewModelAtNotifications(center: center)
        atPaywall.advance()
        #expect(atPaywall.step == .paywall)

        await atPaywall.finishNotificationsStep(requesting: true)
        #expect(atPaywall.step == .paywall)
        #expect(center.requests == 0)
    }
}
