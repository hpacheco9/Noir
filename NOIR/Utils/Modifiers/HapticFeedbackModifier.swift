//
//  HapticFeedbackModifier.swift
//  NOIR
//

import SwiftUI

private struct HapticFeedbackModifier<T: Equatable>: ViewModifier {
    let kind: HapticFeedback
    let trigger: T
    let condition: ((T, T) -> Bool)?

    @AppStorage(HapticsPreference.storageKey) private var isEnabled = HapticsPreference.defaultValue

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            HapticFeedback.resolve(kind, isEnabled: isEnabled, conditionPassed: condition?(old, new) ?? true)
        }
    }
}

extension View {
    /// Plays `kind` when `trigger` changes, unless haptics are turned off in Settings or `condition(old, new)` is false.
    func hapticFeedback<T: Equatable>(_ kind: HapticFeedback, trigger: T, condition: ((T, T) -> Bool)? = nil) -> some View {
        modifier(HapticFeedbackModifier(kind: kind, trigger: trigger, condition: condition))
    }
}
