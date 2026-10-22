//
//  HapticFeedback.swift
//  NOIR
//

import SwiftUI

/// App-level haptic meanings. Every haptic in the app goes through this file, so the Settings toggle
/// (`HapticsPreference`) gates all of them. Add cases only when a call site needs them.
enum HapticFeedback: CaseIterable {
    /// Primary action or row tap.
    case tap
    /// Value changed while scrubbing or scrolling.
    case selection
    /// A save or similar task completed.
    case success
    /// A save or similar task failed.
    case error

    /// SwiftUI's mapping (declarative modifier).
    nonisolated var sensoryFeedback: SensoryFeedback {
        switch self {
        case .tap: .impact(weight: .light)
        case .selection: .selection
        case .success: .success
        case .error: .error
        }
    }

    /// The single gating decision: nil means "play nothing".
    nonisolated static func resolve(_ kind: HapticFeedback, isEnabled: Bool, conditionPassed: Bool = true) -> SensoryFeedback? {
        guard isEnabled, conditionPassed else { return nil }
        return kind.sensoryFeedback
    }
}
