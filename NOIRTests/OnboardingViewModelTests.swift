//
//  OnboardingViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import UserNotifications
@testable import NOIR

/// A class so each test gets a throwaway suite (never the app's real defaults) that is removed in `deinit`.
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

    @Test func currencyComesBetweenNameAndBudget() {
        #expect(OnboardingViewModel.Step.allCases == [.welcome, .name, .currency, .budget, .notifications])
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

    /// Positive control for the test above: a real name does let the step advance.
    @Test func nameLetsTheNameStepAdvance() {
        let viewModel = makeViewModel()
        viewModel.advance()
        viewModel.name = " Maria "
        #expect(viewModel.canAdvance)
        viewModel.advance()
        #expect(viewModel.step == .currency)
    }

    @Test func currencyIsPreselectedFromTheRegionAndOffered() {
        let viewModel = makeViewModel()
        #expect(viewModel.currencyCode == CurrencyPreference.defaultCode)
        #expect(CurrencyPreference.availableCodes.contains(viewModel.currencyCode))
    }

    @Test func currencyIsStoredWhenItsStepIsConfirmed() {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .currency)
        viewModel.currencyCode = "GBP"
        #expect(defaults.string(forKey: CurrencyPreference.storageKey) == nil)

        viewModel.advance()
        #expect(viewModel.step == .budget)
        #expect(defaults.string(forKey: CurrencyPreference.storageKey) == "GBP")
    }

    @Test func persistStoresTrimmedNameAndBudget() {
        let viewModel = makeViewModel()
        viewModel.name = "  Maria  "
        viewModel.budget = 1500
        viewModel.persist()

        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == 1500)
    }

    @Test func completeStoresTheProfile() async {
        let viewModel = makeViewModel()
        viewModel.name = "Maria"
        await viewModel.complete(requestingNotifications: false)

        #expect(defaults.string(forKey: ProfileStorage.nameKey) == "Maria")
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == OnboardingStorage.defaultMonthlyBudget)
    }
}
