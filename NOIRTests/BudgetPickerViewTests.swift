//
//  BudgetPickerViewTests.swift
//  NOIRTests
//

import Testing
import SwiftUI
@testable import NOIR

struct BudgetPickerViewTests {
    @Test func incrementAndDecrementMoveOneRulerStep() {
        #expect(BudgetPickerView.adjusted(1000, .increment) == 1010)
        #expect(BudgetPickerView.adjusted(1000, .decrement) == 990)
    }

    @Test func theRulerStopsAtItsEnds() {
        #expect(BudgetPickerView.adjusted(0, .decrement) == 0)
        #expect(BudgetPickerView.adjusted(5000, .increment) == 5000)
        #expect(BudgetPickerView.adjusted(4990, .increment) == 5000)
        #expect(BudgetPickerView.adjusted(10, .decrement) == 0)
    }

    @Test func steppingUpThenDownComesBack() {
        let up = BudgetPickerView.adjusted(1500, .increment)
        #expect(BudgetPickerView.adjusted(up, .decrement) == 1500)
    }

    @Test func steppingFromZeroReachesTheTopAndStaysThere() {
        var value = 0.0
        for _ in 0..<500 { value = BudgetPickerView.adjusted(value, .increment) }
        #expect(value == 5000)
        #expect(BudgetPickerView.adjusted(value, .increment) == 5000)
    }

    @Test func aValueOffTheRulerLandsOnATick() {
        let value = BudgetPickerView.adjusted(1234, .increment)
        #expect(value.truncatingRemainder(dividingBy: 10) == 0)
        #expect(value > 1234)
    }
}
