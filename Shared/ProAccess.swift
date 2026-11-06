//
//  ProAccess.swift
//  NOIR
//

import Foundation

// Pro access cached in the App Group defaults, for the widget and intents (no RevenueCat there, and offline).
nonisolated enum ProAccess {
    static let storageKey = "purchase.has_access.v1"

    // Off = no paywall anywhere (app, onboarding, widget, intents) and RevenueCat isn't configured.
    static let isPaywallEnabled = false

    // nil until the app has stored an answer once.
    static func cached(in defaults: UserDefaults) -> Bool? {
        defaults.object(forKey: storageKey) as? Bool
    }

    // Missing counts as no access: the widget and intents never run on a guess.
    static func isGranted(in defaults: UserDefaults?, paywallEnabled: Bool = isPaywallEnabled) -> Bool {
        guard paywallEnabled else { return true }
        return defaults.flatMap(cached(in:)) ?? false
    }

    // Returns whether the stored value changed, so the app only reloads widgets when it did.
    @discardableResult
    static func cache(_ hasAccess: Bool, in defaults: UserDefaults) -> Bool {
        let changed = cached(in: defaults) != hasAccess
        defaults.set(hasAccess, forKey: storageKey)
        return changed
    }
}
