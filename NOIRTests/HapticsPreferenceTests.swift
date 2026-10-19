//
//  HapticsPreferenceTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

/// A class so each test gets a throwaway suite (never the app's real defaults) that is removed in `deinit`.
final class HapticsPreferenceTests {
    private let suiteName = "HapticsPreferenceTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func storageKeyIsStable() {
        #expect(HapticsPreference.storageKey == "settings.haptics_enabled")
    }

    @Test func missingKeyCountsAsEnabled() {
        #expect(HapticsPreference.defaultValue == true)
        #expect(HapticsPreference.isEnabled(in: defaults) == true)
    }

    @Test func falseDisables() {
        defaults.set(false, forKey: HapticsPreference.storageKey)
        #expect(HapticsPreference.isEnabled(in: defaults) == false)
    }

    @Test func trueEnables() {
        defaults.set(true, forKey: HapticsPreference.storageKey)
        #expect(HapticsPreference.isEnabled(in: defaults) == true)
    }

    @Test func removingKeyRestoresDefault() {
        defaults.set(false, forKey: HapticsPreference.storageKey)
        defaults.removeObject(forKey: HapticsPreference.storageKey)
        #expect(HapticsPreference.isEnabled(in: defaults) == true)
    }
}
