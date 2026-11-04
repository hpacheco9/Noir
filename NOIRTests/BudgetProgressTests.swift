//
//  BudgetProgressTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct BudgetProgressTests {
    @Test func budgetFractionAndLeft() throws {
        let progress = try #require(BudgetProgress(total: 125, budget: 500))
        #expect(progress.fraction == 0.25)
        #expect(progress.left == 375)
        #expect(progress.over == 0)
        #expect(!progress.isOver)
    }

    @Test func overBudgetClampsAtFull() throws {
        let progress = try #require(BudgetProgress(total: 650, budget: 500))
        #expect(progress.fraction == 1)
        #expect(progress.left == 0)
        #expect(progress.over == 150)
        #expect(progress.isOver)
    }

    @Test func spendingExactlyTheBudgetIsNotOver() throws {
        let progress = try #require(BudgetProgress(total: 500, budget: 500))
        #expect(progress.fraction == 1)
        #expect(progress.left == 0)
        #expect(progress.over == 0)
        #expect(!progress.isOver)
    }

    @Test func zeroSpentIsEmpty() throws {
        let progress = try #require(BudgetProgress(total: 0, budget: 500))
        #expect(progress.fraction == 0)
        #expect(progress.left == 500)
        #expect(!progress.isOver)
    }

    // What the Home summary prints: "679 left of 1,000", "1 over budget".
    @Test func wholeAmountsNeverFlatter() throws {
        let under = try #require(BudgetProgress(total: Decimal(string: "320.4")!, budget: 1000))
        #expect(under.wholeLeft == 679)    // 679.6 left rounds down

        let over = try #require(BudgetProgress(total: Decimal(string: "1000.2")!, budget: 1000))
        #expect(over.isOver)
        #expect(over.wholeOver == 1)       // 0.2 over rounds up: never "0 over budget"

        let exact = try #require(BudgetProgress(total: 400, budget: 1000))
        #expect(exact.wholeLeft == 600)
        #expect(exact.wholeOver == 0)
    }

    // Decimal(Double) sums carry ~1e-17 of noise: 0.07 + 9.93 is a hair over 10, 0.03 + 319.97 a hair over 320.
    @Test func summedDoublesDoNotTipTheWholeUnitRounding() throws {
        let total = Decimal(0.07) + Decimal(9.93)
        try #require(total > 10)

        let exact = try #require(BudgetProgress(total: total, budget: 10))
        #expect(!exact.isOver)
        #expect(exact.over == 0)
        #expect(exact.wholeOver == 0)
        #expect(exact.wholeLeft == 0)

        let noisy = Decimal(0.03) + Decimal(319.97)
        try #require(1000 - noisy < 680)
        let remaining = try #require(BudgetProgress(total: noisy, budget: 1000))
        #expect(remaining.left == 680)
        #expect(remaining.wholeLeft == 680)
    }

    @Test func aBudgetThatRoundsToZeroCentsIsNoBudget() {
        #expect(BudgetProgress(total: 5, budget: 0.004) == nil)
    }

    @Test(arguments: [0.0, -10, .nan, .infinity])
    func noBudgetMeansNoProgress(budget: Double) {
        #expect(BudgetProgress(total: 100, budget: budget) == nil)
    }

    @Test func keepsTheCentRoundedSpentAndBudget() throws {
        let progress = try #require(BudgetProgress(total: Decimal(string: "12.345")!, budget: 20.004))
        #expect(progress.spent == Decimal(string: "12.35")!)
        #expect(progress.budget == 20)
    }
}
