//
//  IntentAccessTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

// Runs `body` as if the app had cached Pro access, in an isolated suite instead of the App Group.
func withIntentAccess<T>(_ granted: Bool = true, _ body: () async throws -> T) async rethrows -> T {
    let suite = "NOIRTests.intentAccess.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    ProAccess.cache(granted, in: defaults)
    return try await ExpenseIntentSaver.$accessSuiteName.withValue(suite) { try await body() }
}

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
            try ExpenseIntentSaver.requireAccess(defaults: defaults, paywallEnabled: true)
        }
    }

    @Test func intentsStopWithoutCachedAccess() {
        withIsolatedDefaults(cached: false) { defaults in
            #expect(throws: AddExpenseIntentError.subscriptionRequired) {
                try ExpenseIntentSaver.requireAccess(defaults: defaults, paywallEnabled: true)
            }
        }
    }

    @Test func intentsStopWhenNothingWasCachedYet() {
        withIsolatedDefaults { defaults in
            #expect(throws: AddExpenseIntentError.subscriptionRequired) {
                try ExpenseIntentSaver.requireAccess(defaults: defaults, paywallEnabled: true)
            }
        }
        #expect(throws: AddExpenseIntentError.subscriptionRequired) {
            try ExpenseIntentSaver.requireAccess(defaults: nil, paywallEnabled: true)
        }
    }

    @Test func theMessageIsTranslatedNotTheRawKey() {
        let message = AddExpenseIntentError.subscriptionRequired.errorDescription
        #expect(message?.isEmpty == false)
        #expect(message != "app_intent.subscription_required")
        // Control: a key that isn't in the table falls back to itself, so the check above can fail.
        #expect(String(localized: LocalizedStringResource("app_intent.not_a_real_key", table: "AppIntents")) == "app_intent.not_a_real_key")
    }

    @Test func theDefaultCheckReadsTheOverriddenSuite() async throws {
        try await withIntentAccess(true) { try ExpenseIntentSaver.requireAccess(paywallEnabled: true) }
        await withIntentAccess(false) {
            #expect(throws: AddExpenseIntentError.subscriptionRequired) { try ExpenseIntentSaver.requireAccess(paywallEnabled: true) }
        }
    }

    @Test func withThePaywallOffIntentsRunWithoutCachedAccess() async throws {
        try await withIntentAccess(false) { try ExpenseIntentSaver.requireAccess(paywallEnabled: false) }
        try ExpenseIntentSaver.requireAccess(defaults: nil, paywallEnabled: false)
    }
}
