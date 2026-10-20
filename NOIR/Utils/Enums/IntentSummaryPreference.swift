//
//  IntentSummaryPreference.swift
//  NOIR
//

import Foundation

/// Whether the "Add expense" shortcut shows a summary to confirm before saving.
enum IntentSummaryPreference {
    static let storageKey = "settings.intent_summary_enabled"
    static let defaultValue = true

    /// A missing key counts as enabled, so the summary shows until the user turns it off.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }
}
