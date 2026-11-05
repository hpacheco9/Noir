//
//  BudgetPickerViewTests.swift
//  NOIRTests
//

import Testing
import SwiftUI
@testable import NOIR

struct BudgetPickerViewTests {
    @Test func voiceOverMovesAHundredAndLandsOnTheHundredGrid() {
        #expect(BudgetPickerView.adjusted(1000, .increment, scale: 1) == 1100)
        #expect(BudgetPickerView.adjusted(1000, .decrement, scale: 1) == 900)

        // Off the grid, the first step goes to the nearest hundred in its direction.
        #expect(BudgetPickerView.adjusted(1230, .increment, scale: 1) == 1300)
        #expect(BudgetPickerView.adjusted(1230, .decrement, scale: 1) == 1200)
        #expect(BudgetPickerView.adjusted(1270, .increment, scale: 1) == 1300)
        #expect(BudgetPickerView.adjusted(1270, .decrement, scale: 1) == 1200)

        // A hundred of the ruler's own units: SEK, NOK and DKK run ten times larger, JPY a hundred.
        #expect(BudgetPickerView.adjusted(10_000, .increment, scale: 10) == 11_000)
        #expect(BudgetPickerView.adjusted(100_000, .decrement, scale: 100) == 90_000)
    }

    @Test func theRulerStopsAtItsEnds() {
        #expect(BudgetPickerView.adjusted(0, .decrement, scale: 1) == 0)
        #expect(BudgetPickerView.adjusted(50, .decrement, scale: 1) == 0)
        #expect(BudgetPickerView.adjusted(5000, .increment, scale: 1) == 5000)
        #expect(BudgetPickerView.adjusted(4990, .increment, scale: 1) == 5000)
        #expect(BudgetPickerView.adjusted(50_000, .increment, scale: 10) == 50_000)
        #expect(BudgetPickerView.adjusted(500_000, .increment, scale: 100) == 500_000)
    }
}
