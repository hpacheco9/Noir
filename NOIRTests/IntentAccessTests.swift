//
//  IntentAccessTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct IntentAccessTests {
    @discardableResult
    private func withIsolatedDefaults<T>(cached: Bool? = nil, _ body: (UserDefaults) throws -> T) rethrows -> T {
        let suite = "NOIRTests.intentAccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        if let cached { ProAccess.cache(cached, in: defaults) }
        return try body(defaults)
    }

    @Test func intentsRunWithCachedAccess() throws {
        try withIsolatedDefaults(cached: true) { defaults in
            try ExpenseIntentSaver.requireAccess(defaults: defaults)
        }
    }

    @Test func intentsStopWithoutCachedAccess() {
        withIsolatedDefaults(cached: false) { defaults in
            #expect(throws: AddExpenseIntentError.subscriptionRequired) {
                try ExpenseIntentSaver.requireAccess(defaults: defaults)
            }
        }
    }

    @Test func intentsStopWhenNothingWasCachedYet() {
        withIsolatedDefaults { defaults in
            #expect(throws: AddExpenseIntentError.subscriptionRequired) {
                try ExpenseIntentSaver.requireAccess(defaults: defaults)
            }
        }
        #expect(throws: AddExpenseIntentError.subscriptionRequired) {
            try ExpenseIntentSaver.requireAccess(defaults: nil)
        }
    }

    @Test func theMessageIsTranslatedNotTheRawKey() {
        let message = AddExpenseIntentError.subscriptionRequired.errorDescription
        #expect(message?.isEmpty == false)
        #expect(message != "app_intent.subscription_required")
        // Control: a key that isn't in the table falls back to itself, so the check above can fail.
        #expect(String(localized: LocalizedStringResource("app_intent.not_a_real_key", table: "AppIntents")) == "app_intent.not_a_real_key")
    }
}
