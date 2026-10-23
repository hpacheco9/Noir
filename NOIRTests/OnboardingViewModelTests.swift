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
        #expect(visited == [.welcome, .name, .currency, .notifications, .paywall])
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
        #expect(viewModel.step == .notifications)
        #expect(defaults.string(forKey: CurrencyPreference.storageKey) == other)
    }

    @Test func persistStoresTrimmedName() {
        let viewModel = makeViewModel()
        viewModel.name = "  Maria  "
        viewModel.persist()

        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
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
