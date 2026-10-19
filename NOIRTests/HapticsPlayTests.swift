//
//  HapticsPlayTests.swift
//  NOIRTests
//

import Testing
import UIKit
@testable import NOIR

/// `init(view:)` on a feedback generator installs a `UIInteraction` on the view, so building a generator per call
/// leaks one interaction per haptic. These tests pin that down.
final class HapticsPlayTests {
    private let suiteName = "HapticsPlayTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func repeatedPlaysDoNotAccumulateInteractions() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        for _ in 0..<5 {
            for kind in HapticFeedback.allCases { Haptics.play(kind, in: view, defaults: defaults) }
        }
        #expect(view.interactions.count <= 3)
        #expect(view.interactions.count > 0)
    }

    @Test func disabledAddsNoInteraction() {
        defaults.set(false, forKey: HapticsPreference.storageKey)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        for kind in HapticFeedback.allCases { Haptics.play(kind, in: view, defaults: defaults) }
        #expect(view.interactions.isEmpty)
    }

    @Test func switchingViewMovesInteractions() {
        let first = UIView(frame: .zero)
        let second = UIView(frame: .zero)
        for kind in HapticFeedback.allCases { Haptics.play(kind, in: first, defaults: defaults) }
        for kind in HapticFeedback.allCases { Haptics.play(kind, in: second, defaults: defaults) }
        #expect(first.interactions.isEmpty)
        #expect(second.interactions.count <= 3)
    }
}
