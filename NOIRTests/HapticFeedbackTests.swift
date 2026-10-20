//
//  HapticFeedbackTests.swift
//  NOIRTests
//

import Testing
import SwiftUI
@testable import NOIR

struct HapticFeedbackTests {
    @Test(arguments: HapticFeedback.allCases)
    func disabledPlaysNothing(kind: HapticFeedback) {
        #expect(HapticFeedback.resolve(kind, isEnabled: false, conditionPassed: true) == nil)
    }

    @Test(arguments: HapticFeedback.allCases)
    func failedConditionPlaysNothing(kind: HapticFeedback) {
        #expect(HapticFeedback.resolve(kind, isEnabled: true, conditionPassed: false) == nil)
    }

    @Test(arguments: HapticFeedback.allCases)
    func disabledAndFailedConditionPlaysNothing(kind: HapticFeedback) {
        #expect(HapticFeedback.resolve(kind, isEnabled: false, conditionPassed: false) == nil)
    }

    @Test func conditionDefaultsToPassed() {
        #expect(HapticFeedback.resolve(.tap, isEnabled: true) == .impact(weight: .light))
    }

    @Test func eachKindMapsToItsFeedback() {
        #expect(HapticFeedback.resolve(.tap, isEnabled: true, conditionPassed: true) == .impact(weight: .light))
        #expect(HapticFeedback.resolve(.selection, isEnabled: true, conditionPassed: true) == .selection)
        #expect(HapticFeedback.resolve(.success, isEnabled: true, conditionPassed: true) == .success)
        #expect(HapticFeedback.resolve(.error, isEnabled: true, conditionPassed: true) == .error)
    }

    @Test func kindsAreDistinguishable() {
        let all = HapticFeedback.allCases.map(\.sensoryFeedback)
        for (i, a) in all.enumerated() {
            for b in all[(i + 1)...] { #expect(a != b) }
        }
    }
}
