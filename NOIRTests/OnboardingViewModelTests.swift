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

    private let suiteName = "OnboardingViewModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeViewModel() -> OnboardingViewModel {
        OnboardingViewModel(notificationService: NotificationService(center: SilentCenter()), defaults: defaults)
    }

    @Test func currencyComesBetweenNameAndNotifications() {
        #expect(OnboardingViewModel.Step.allCases == [.welcome, .name, .currency, .notifications])
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

    @Test func completeStoresTheProfile() async {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        await viewModel.complete(requestingNotifications: false)

        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
    }
}
