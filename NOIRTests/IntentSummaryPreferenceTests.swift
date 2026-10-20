//
//  IntentSummaryPreferenceTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

/// A class so each test gets a throwaway suite (never the app's real defaults) that is removed in `deinit`.
final class IntentSummaryPreferenceTests {
    private let suiteName = "IntentSummaryPreferenceTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func storageKeyIsStable() {
        #expect(IntentSummaryPreference.storageKey == "settings.intent_summary_enabled")
    }

    @Test func missingKeyCountsAsEnabled() {
        #expect(IntentSummaryPreference.defaultValue == true)
        #expect(IntentSummaryPreference.isEnabled(in: defaults) == true)
    }

    /// Positive control: a reader that ignored the stored value (always the default) fails here.
    @Test func falseDisables() {
        defaults.set(false, forKey: IntentSummaryPreference.storageKey)
        #expect(IntentSummaryPreference.isEnabled(in: defaults) == false)
    }
}
