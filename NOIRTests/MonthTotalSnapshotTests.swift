//
//  MonthTotalSnapshotTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

final class MonthTotalSnapshotTests {
    private let suiteName = "MonthTotalSnapshotTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private let total = Decimal(string: "123.45")!

    /// October 2026 as the app computes it on a device in Lisbon.
    private var month: DateInterval { calendar.dateInterval(of: .month, for: calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!)! }

    private var snapshot: MonthTotalSnapshot {
        MonthTotalSnapshot(month: month, total: total, budget: 500, currencyCode: "EUR")
    }

    @Test func roundTripsThroughDefaults() {
        snapshot.save(to: defaults)
        #expect(MonthTotalSnapshot.load(from: defaults) == snapshot)
    }

    /// 00:30 on 1 October in Lisbon is still 30 September in the Azores: a calendar-based check there showed 0.
    @Test func instantInsideTheMonthKeepsTotal() {
        #expect(snapshot.total(asOf: month.start) == total)
        #expect(snapshot.total(asOf: month.start.addingTimeInterval(30 * 60)) == total)
        #expect(snapshot.total(asOf: month.end.addingTimeInterval(-1)) == total)
    }

    @Test func monthEndAndLaterShowZero() {
        #expect(snapshot.total(asOf: month.end) == 0)
        #expect(snapshot.total(asOf: month.end.addingTimeInterval(86_400 * 40)) == 0)
    }

    @Test func beforeTheMonthShowsZero() {
        #expect(snapshot.total(asOf: month.start.addingTimeInterval(-1)) == 0)
    }

    private func day(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func cumulativeDaysRunThroughTheWholeMonth() {
        let rows: [(date: Date, amount: Double)] = [
            (day(1, hour: 0), 10), (day(3), 5), (day(3, hour: 23), 2.5), (day(31), 1),
            (day(1).addingTimeInterval(-86_400 * 2), 100), (month.end, 100),
        ]
        let days = MonthTotalSnapshot.cumulativeDays(rows, in: month, calendar: calendar)
        #expect(days.count == 31)
        #expect(Array(days.prefix(4)) == [10, 10, 17.5, 17.5])
        #expect(days.last == 18.5)
    }

    @Test func visibleDaysStopAtTodayUnlessLaterDaysHaveSpending() {
        var snapshot = snapshot
        snapshot.days = MonthTotalSnapshot.cumulativeDays([(day(2), 4)], in: month, calendar: calendar)
        #expect(snapshot.visibleDays(asOf: day(5), calendar: calendar) == [0, 4, 4, 4, 4])

        snapshot.days = MonthTotalSnapshot.cumulativeDays([(day(2), 4), (day(9), 6)], in: month, calendar: calendar)
        #expect(snapshot.visibleDays(asOf: day(5), calendar: calendar).count == 9)
        #expect(snapshot.visibleDays(asOf: month.end, calendar: calendar).isEmpty)
    }

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

    @Test(arguments: [0.0, -10, .nan, .infinity])
    func noBudgetMeansNoProgress(budget: Double) {
        #expect(BudgetProgress(total: 100, budget: budget) == nil)
    }
}
