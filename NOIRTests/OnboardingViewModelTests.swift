//
//  OnboardingViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import UserNotifications
@testable import NOIR

final class OnboardingViewModelTests {
    private struct SilentCenter: NotificationCenterClient {
        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
        func authorizationStatus() async -> UNAuthorizationStatus { .notDetermined }
        func add(_ request: UNNotificationRequest) async throws {}
    }

    private struct RequestFailure: Error {}

    /// Counts the permission requests; `fails` makes each one throw.
    private final class RecordingCenter: NotificationCenterClient, @unchecked Sendable {
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

    private func makeViewModel(center: NotificationCenterClient = SilentCenter()) -> OnboardingViewModel {
        OnboardingViewModel(notificationService: NotificationService(center: center), defaults: defaults)
    }

    private func makeViewModelAtNotifications(center: NotificationCenterClient = SilentCenter()) -> OnboardingViewModel {
        let viewModel = makeViewModel(center: center)
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        return viewModel
    }

    @Test func currencyComesBetweenNameAndNotificationsAndThePaywallIsLast() {
        #expect(OnboardingViewModel.Step.allCases == [.welcome, .name, .currency, .notifications, .paywall])

        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        for step in OnboardingViewModel.Step.allCases {
            #expect(viewModel.step == step)
            #expect(viewModel.isLastStep == (step == .paywall))
            viewModel.advance()
        }
        #expect(viewModel.step == .paywall)
    }

    @Test func advanceWalksThroughEveryStep() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        var visited = [viewModel.step]
        while !viewModel.isLastStep {
            viewModel.advance()
            visited.append(viewModel.step)
        }
        #expect(visited == OnboardingViewModel.Step.allCases)
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
        let asked = RecordingCenter()
        await makeViewModelAtNotifications(center: asked).finishNotificationsStep(requesting: true)
        #expect(asked.requests == 1)

        let skipped = RecordingCenter()
        await makeViewModelAtNotifications(center: skipped).finishNotificationsStep(requesting: false)
        #expect(skipped.requests == 0)
    }

    @Test func aFailedPermissionRequestStillReachesThePaywall() async {
        let center = RecordingCenter(fails: true)
        let viewModel = makeViewModelAtNotifications(center: center)

        await viewModel.finishNotificationsStep(requesting: true)

        #expect(center.requests == 1)
        #expect(viewModel.step == .paywall)
    }

    @Test func finishingTheNotificationsStepFromAnotherStepDoesNothing() async {
        let center = RecordingCenter()
        let viewModel = makeViewModel(center: center)

        await viewModel.finishNotificationsStep(requesting: true)

        #expect(viewModel.step == .welcome)
        #expect(center.requests == 0)
    }
}
