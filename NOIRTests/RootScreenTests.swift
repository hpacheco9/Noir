//
//  RootScreenTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct RootScreenTests {
    private func resolve(
        onboarded: Bool = true,
        known: Bool = true,
        access: Bool = false,
        timedOut: Bool = false,
        latched: Bool = false,
        paywall: Bool = true
    ) -> RootScreen {
        RootScreen.resolve(
            hasCompletedOnboarding: onboarded,
            isAccessKnown: known,
            hasAccess: access,
            accessTimedOut: timedOut,
            isAppLatched: latched,
            isPaywallEnabled: paywall
        )
    }

    @Test func withThePaywallOffOnboardingLeadsStraightToTheApp() {
        #expect(resolve(known: true, access: false, paywall: false) == .app)
        #expect(resolve(known: false, timedOut: false, paywall: false) == .app)
        #expect(resolve(onboarded: false, paywall: false) == .onboarding)
    }

    @Test func onboardingComesFirst() {
        #expect(resolve(onboarded: false, access: true) == .onboarding)
        #expect(resolve(onboarded: false, known: false, latched: true) == .onboarding)
        #expect(resolve(onboarded: true, access: true) == .app)
    }

    @Test func noAccessShowsTheHardPaywall() {
        #expect(resolve(known: true, access: false) == .paywall)
        #expect(resolve(known: true, access: true) == .app)
    }

    @Test func unknownAccessWaitsUntilTheTimeout() {
        #expect(resolve(known: false, timedOut: false) == .loading)
        #expect(resolve(known: false, timedOut: true) == .paywall)
        #expect(resolve(known: false, access: true) == .app)
    }

    @Test func aLatchedAppSurvivesALostAccess() {
        #expect(resolve(known: true, access: false, latched: true) == .app)
        #expect(resolve(known: true, access: false, latched: false) == .paywall)
    }

    @Test func onlyThePaywallDiscardsAPendingAddExpense() {
        #expect(RootScreen.paywall.discardsAddExpenseRequest)
        #expect(!RootScreen.app.discardsAddExpenseRequest)
        #expect(!RootScreen.loading.discardsAddExpenseRequest)
        #expect(!RootScreen.onboarding.discardsAddExpenseRequest)
    }
}
