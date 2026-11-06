//
//  RootScreen.swift
//  NOIR
//

import Foundation

nonisolated enum RootScreen: Equatable, Sendable {
    case onboarding
    case loading
    case paywall
    case app

    // How long to wait for the first purchase answer before showing the paywall, which can restore anyway.
    static let accessTimeout: Duration = .seconds(5)

    // A control tap while the paywall is up must not open Add Expense long after the purchase.
    var discardsAddExpenseRequest: Bool { self == .paywall }

    // `isAppLatched`: the app was already showing this session, so a failed renewal doesn't tear it down mid-use.
    static func resolve(
        hasCompletedOnboarding: Bool,
        isAccessKnown: Bool,
        hasAccess: Bool,
        accessTimedOut: Bool,
        isAppLatched: Bool,
        isPaywallEnabled: Bool = ProAccess.isPaywallEnabled
    ) -> RootScreen {
        guard hasCompletedOnboarding else { return .onboarding }
        guard isPaywallEnabled else { return .app }
        if hasAccess || isAppLatched { return .app }
        return isAccessKnown || accessTimedOut ? .paywall : .loading
    }
}
