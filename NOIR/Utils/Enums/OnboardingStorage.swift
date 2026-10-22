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
}
