//
//  HapticsPreference.swift
//  NOIR
//

import Foundation
import CoreHaptics

enum HapticsPreference {
    static let storageKey = "settings.haptics_enabled"
    static let defaultValue = true

    /// A missing key counts as enabled, so haptics are on until the user turns them off.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }

    /// False on devices without a Taptic Engine (iPad), where the Settings toggle is hidden. The Simulator reports
    /// no haptics, so it counts as supported to keep the toggle reachable there. The system Haptics setting already
    /// silences playback; no public API reads it.
    static let isSupportedByHardware: Bool = {
#if targetEnvironment(simulator)
        true
#else
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
#endif
    }()
}
