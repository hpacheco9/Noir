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

    @Test func spendingExactlyTheBudgetIsNotOver() {
        #expect(next(500) == .nearLimit)
        #expect(next(Decimal(string: "500.01")!) == .over)
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
        #expect(next(450, lastSent: .over) == nil)
    }

    @Test(arguments: [0.0, -10, .nan, .infinity])
    func noBudgetMeansNoAlerts(budget: Double) {
        #expect(BudgetAlert.next(total: 1000, budget: budget, lastSent: nil) == nil)
    }

    @Test func aBudgetThatRoundsToZeroCentsIsNoBudget() {
        #expect(BudgetAlert.next(total: 5, budget: 0.004, lastSent: nil) == nil)
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

    @Test func rawValuesAreWhatIsStored() {
        #expect(BudgetAlert(rawValue: 0) == nil)
        #expect(BudgetAlert(rawValue: BudgetAlert.nearLimit.rawValue) == .nearLimit)
        #expect(BudgetAlert(rawValue: BudgetAlert.over.rawValue) == .over)
        #expect(BudgetAlert.nearLimit.rawValue < BudgetAlert.over.rawValue)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func key(_ year: Int, _ month: Int, _ day: Int) -> String {
        BudgetAlert.storageKey(for: calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!, calendar: calendar)
    }

    @Test func theStorageKeyIsPerCalendarMonth() {
        #expect(key(2026, 10, 1) == key(2026, 10, 31))
        #expect(key(2026, 10, 15) != key(2026, 11, 15))
        #expect(key(2026, 1, 15) != key(2026, 11, 15))
        #expect(key(2026, 10, 15) != key(2027, 10, 15))
    }
}
