//
//  BudgetAlertTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct BudgetAlertTests {
    private func next(_ total: Decimal, budget: Double = 500, lastSent: BudgetAlert? = nil) -> BudgetAlert? {
        BudgetAlert.next(total: total, budget: budget, lastSent: lastSent)
    }

    @Test(arguments: [Decimal(0), 1, 399, Decimal(string: "399.99")!])
    func belowEightyPercentIsQuiet(total: Decimal) {
        #expect(next(total) == nil)
    }

    @Test(arguments: [Decimal(400), Decimal(string: "400.01")!, 450, 499, 500])
    func fromEightyPercentThroughTheBudgetIsNearLimit(total: Decimal) {
        #expect(next(total) == .nearLimit)
    }

    @Test func jumpingStraightPastTheBudgetSendsOnlyTheOverAlert() {
        #expect(next(900) == .over)
    }

    @Test func eachLevelFiresOnce() {
        #expect(next(410, lastSent: nil) == .nearLimit)
        #expect(next(450, lastSent: .nearLimit) == nil)
        #expect(next(520, lastSent: .nearLimit) == .over)
        #expect(next(520, lastSent: .over) == nil)
        #expect(next(900, lastSent: .over) == nil)
    }

    @Test(arguments: [BudgetAlert.nearLimit, .over])
    func spendingThatFallsBackNeverReArms(lastSent: BudgetAlert) {
        #expect(next(100, lastSent: lastSent) == nil)
        #expect(next(450, lastSent: lastSent) == nil)
    }

    // Decimal(Double) sums carry ~1e-17 of noise.
    @Test func summedDoublesDoNotTipEitherThreshold() {
        let atTheBudget = Decimal(0.07) + Decimal(9.93)
        #expect(atTheBudget > 10)
        #expect(BudgetAlert.next(total: atTheBudget, budget: 10, lastSent: nil) == .nearLimit)

        let belowEighty = Decimal(0.1) + Decimal(7.89)
        #expect(BudgetAlert.next(total: belowEighty, budget: 10, lastSent: nil) == nil)

        let atEighty = Decimal(0.01) + Decimal(7.99)
        #expect(BudgetAlert.next(total: atEighty, budget: 10, lastSent: nil) == .nearLimit)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func theStateHoldsTheMonthAndTheLevel() {
        #expect(BudgetAlert.state(for: .nearLimit, now: date(2026, 10, 3), calendar: calendar) == "2026-10.1")
        #expect(BudgetAlert.state(for: .over, now: date(2026, 1, 31), calendar: calendar) == "2026-1.2")
    }

    @Test func aStateOnlyCountsInItsOwnMonth() {
        let state = "2026-10.2"
        #expect(BudgetAlert.lastSent(state: state, now: date(2026, 10, 1), calendar: calendar) == .over)
        #expect(BudgetAlert.lastSent(state: state, now: date(2026, 10, 31), calendar: calendar) == .over)
        #expect(BudgetAlert.lastSent(state: state, now: date(2026, 11, 1), calendar: calendar) == nil)
        #expect(BudgetAlert.lastSent(state: state, now: date(2025, 10, 15), calendar: calendar) == nil)
        #expect(BudgetAlert.lastSent(state: "2026-1.2", now: date(2026, 10, 15), calendar: calendar) == nil)
    }

    @Test(arguments: [nil, "", "2026-10.0", "2026-10.x"] as [String?])
    func anUnreadableStateMeansNothingWasSent(state: String?) {
        #expect(BudgetAlert.lastSent(state: state, now: date(2026, 10, 15), calendar: calendar) == nil)
    }
}
