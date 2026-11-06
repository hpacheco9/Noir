//
//  BudgetRangeTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

final class BudgetRangeTests {
    private let suiteName = "BudgetRangeTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [
        (140_000.0, "USD", 5000.0), (140_000, "EUR", 5000), (140_000, "SEK", 50_000), (140_000, "JPY", 140_000),
        (600_000, "JPY", 500_000), (5000, "USD", 5000), (1234.5, "EUR", 1234.5), (0, "EUR", 0), (-20, "EUR", 0),
    ])
    func aBudgetIsClampedIntoTheCurrenciesRuler(budget: Double, code: String, expected: Double) {
        #expect(CurrencyPreference.clampedBudget(budget, for: code) == expected)
    }

    @Test func switchingCurrencyClampsTheStoredBudget() {
        defaults.set(140_000.0, forKey: OnboardingStorage.monthlyBudgetKey)

        OnboardingStorage.clampBudget(forCurrency: "JPY", in: defaults)
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == 140_000)

        OnboardingStorage.clampBudget(forCurrency: "USD", in: defaults)
        #expect(defaults.double(forKey: OnboardingStorage.monthlyBudgetKey) == 5000)
    }

    @Test func switchingCurrencyDoesNotInventABudget() {
        OnboardingStorage.clampBudget(forCurrency: "USD", in: defaults)
        #expect(defaults.object(forKey: OnboardingStorage.monthlyBudgetKey) == nil)
    }
}
