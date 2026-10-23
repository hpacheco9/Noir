//
//  PeriodComparisonTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PeriodComparisonTests {
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

    @Test func moreThanDoubleKeepsGoingPastAHundred() {
        #expect(PeriodComparison.make(current: 350, previous: 100) == PeriodComparison(percent: 250))
    }

    @Test(arguments: [nil, 0, -5] as [Decimal?])
    func withoutAPositivePreviousTotalThereIsNothingToCompare(previous: Decimal?) {
        #expect(PeriodComparison.make(current: 100, previous: previous) == nil)
    }

    @Test(arguments: [
        (current: "100.4", previous: "100", percent: 0),      // 0.4% rounds to 0
        (current: "100.5", previous: "100", percent: 1),      // half rounds away from zero
        (current: "99.5", previous: "100", percent: -1),
        (current: "99.6", previous: "100", percent: 0),
        (current: "4", previous: "3", percent: 33),           // 33.33…
        (current: "5", previous: "3", percent: 67),           // 66.66…
        (current: "1", previous: "3", percent: -67),          // -66.66…
        (current: "112.5", previous: "100", percent: 13),     // 12.5
        (current: "87.5", previous: "100", percent: -13),     // -12.5
    ])
    func roundsToWholePercent(current: String, previous: String, percent: Int) {
        let comparison = PeriodComparison.make(current: Decimal(string: current)!, previous: Decimal(string: previous)!)
        #expect(comparison?.percent == percent)
    }

    @Test func aChangeThatRoundsToZeroCountsAsTheSame() {
        #expect(PeriodComparison.make(current: Decimal(string: "100.3")!, previous: 100)?.trend == .same)
        #expect(PeriodComparison.make(current: Decimal(string: "99.7")!, previous: 100)?.trend == .same)
    }

    @Test func formatsTheMagnitudeWithoutASign() {
        let more = PeriodComparison(percent: 12)
        let less = PeriodComparison(percent: -12)
        let english = Locale(identifier: "en_US")
        #expect(more.formattedPercent(locale: english) == "12%")
        #expect(less.formattedPercent(locale: english) == "12%")
        #expect(PeriodComparison(percent: 0).formattedPercent(locale: english) == "0%")
        #expect(PeriodComparison(percent: 1250).formattedPercent(locale: english) == "1,250%")
    }

    @Test func formatsWithTheLocalesConventions() {
        let german = PeriodComparison(percent: 12).formattedPercent(locale: Locale(identifier: "de_DE"))
        #expect(german.hasPrefix("12"))
        #expect(german != "12%")    // "12 %" with a no-break space
    }
}
