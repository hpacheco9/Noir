//
//  PeriodComparisonTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PeriodComparisonTests {
    private let english = Locale(identifier: "en_US")

    @Test func moreThanBeforeIsPositive() {
        let comparison = PeriodComparison.make(current: 150, previous: 100)
        #expect(comparison == PeriodComparison(percent: 50))
        #expect(comparison?.trend == .higher)
    }

    @Test func lessThanBeforeIsNegative() {
        let comparison = PeriodComparison.make(current: 80, previous: 100)
        #expect(comparison == PeriodComparison(percent: -20))
        #expect(comparison?.trend == .lower)
    }

    @Test func equalTotalsAreTheSame() {
        let comparison = PeriodComparison.make(current: 42.5, previous: 42.5)
        #expect(comparison == PeriodComparison(percent: 0))
        #expect(comparison?.trend == .same)
    }

    @Test func spendingNothingIsAHundredPercentLess() {
        #expect(PeriodComparison.make(current: 0, previous: 40) == PeriodComparison(percent: -100))
    }

    @Test(arguments: [nil, 0, -5] as [Decimal?])
    func withoutAPositivePreviousTotalThereIsNothingToCompare(previous: Decimal?) {
        #expect(PeriodComparison.make(current: 100, previous: previous) == nil)
    }

    @Test(arguments: [
        (current: "100.4", previous: "100", percent: 0),
        (current: "100.5", previous: "100", percent: 1),
        (current: "99.5", previous: "100", percent: -1),
        (current: "99.6", previous: "100", percent: 0),
        (current: "4", previous: "3", percent: 33),
        (current: "5", previous: "3", percent: 67),
        (current: "1", previous: "3", percent: -67),
        (current: "112.5", previous: "100", percent: 13),
        (current: "87.5", previous: "100", percent: -13),
    ])
    func roundsToWholePercent(current: String, previous: String, percent: Int) {
        let comparison = PeriodComparison.make(current: Decimal(string: current)!, previous: Decimal(string: previous)!)
        #expect(comparison?.percent == percent)
    }

    @Test func aChangeThatRoundsToZeroCountsAsTheSame() {
        #expect(PeriodComparison.make(current: Decimal(string: "100.3")!, previous: 100)?.trend == .same)
        #expect(PeriodComparison.make(current: Decimal(string: "99.7")!, previous: 100)?.trend == .same)
    }

    // MARK: Display cap

    @Test func showsTheMagnitudeWithoutASign() {
        #expect(PeriodComparison(percent: 12).formattedPercent(locale: english) == "12%")
        #expect(PeriodComparison(percent: -12).formattedPercent(locale: english) == "12%")
        #expect(PeriodComparison(percent: 12).magnitude == 12)
        #expect(PeriodComparison(percent: -12).magnitude == 12)
    }

    @Test func theCapItselfIsShownAsIs() {
        let comparison = PeriodComparison(percent: 999)
        #expect(!comparison.exceedsCap)
        #expect(comparison.formattedPercent(locale: english) == "999%")
    }

    @Test func aboveTheCapShowsGreaterThanTheCap() {
        let comparison = PeriodComparison(percent: 1000)
        #expect(comparison.exceedsCap)
        #expect(comparison.magnitude == 999)
        #expect(comparison.formattedPercent(locale: english) == ">999%")
        #expect(comparison.trend == .higher)
    }

    @Test func hugeRatiosAreClampedInsteadOfOverflowing() {
        // 1e12 against a cent: about 1e16 percent, past what an Int conversion of the raw value could hold safely.
        let comparison = PeriodComparison.make(current: 1_000_000_000_000, previous: Decimal(string: "0.01")!)
        #expect(comparison?.trend == .higher)
        #expect(comparison?.exceedsCap == true)
        #expect(comparison?.formattedPercent(locale: english) == ">999%")
        #expect(comparison.map { $0.percent <= 1_000_000 } == true)
    }

    @Test func justPastTheCapThroughMake() {
        // 1000% more: current is 11 times previous.
        let comparison = PeriodComparison.make(current: 11, previous: 1)
        #expect(comparison == PeriodComparison(percent: 1000))
        #expect(comparison?.formattedPercent(locale: english) == ">999%")
    }
}
