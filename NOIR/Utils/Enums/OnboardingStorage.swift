//
//  OnboardingStorage.swift
//  NOIR
//

import Foundation

/// UserDefaults keys owned by the onboarding flow.
enum OnboardingStorage {
    /// Gate read by `NOIRApp` to choose between onboarding and `RootView`.
    /// The raw value must stay `"hasCompletedOnboarding"` so existing installs keep their state.
    static let hasCompletedKey = "hasCompletedOnboarding"
    static let monthlyBudgetKey = "profile.monthlyBudget"
    static let defaultMonthlyBudget: Double = 1000

    static func clampBudget(forCurrency code: String, in defaults: UserDefaults = .standard) {
        let stored = defaults.double(forKey: monthlyBudgetKey)
        let clamped = CurrencyPreference.clampedBudget(stored, for: code)
        if clamped != stored { defaults.set(clamped, forKey: monthlyBudgetKey) }
    }
}
