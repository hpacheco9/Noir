//
//  SpendingOverviewViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct SpendingOverviewViewModelTests {
    private func snapshot(
        _ period: SpendingPeriod, total: Decimal, previous: Decimal?, month: Decimal = 0
    ) -> OverviewSnapshot {
        OverviewSnapshot(
            period: period, points: [], total: total, latest: [], hasAnyExpenses: true,
            previousTotal: previous, monthTotal: month
        )
    }

    @Test func applyingASnapshotSetsTheComparison() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.week, total: 120, previous: 100))

        #expect(viewModel.comparison == PeriodComparison(percent: 20))
        #expect(viewModel.appliedPeriod == .week)
    }

    @Test func aLowerTotalComparesNegative() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.month, total: 40, previous: 160))
        #expect(viewModel.comparison == PeriodComparison(percent: -75))
        #expect(viewModel.comparison?.trend == .lower)
    }

    @Test func allTimeClearsTheComparison() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.week, total: 120, previous: 100))
        #expect(viewModel.comparison != nil)

        viewModel.apply(snapshot(.allTime, total: 900, previous: nil))
        #expect(viewModel.comparison == nil)
        #expect(viewModel.appliedPeriod == .allTime)
    }

    @Test func aPreviousPeriodWithoutSpendingShowsTheNewSpending() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.day, total: 25, previous: 0))
        #expect(viewModel.comparison == PeriodComparison(amount: 25))
    }

    @Test func nothingSpentNowOrBeforeIsTheSame() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.month, total: 0, previous: 0))
        #expect(viewModel.comparison == PeriodComparison(percent: 0))
    }

    @Test func freshDataForTheSamePeriodUpdatesTheComparison() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.week, total: 120, previous: 100))
        viewModel.apply(snapshot(.week, total: 90, previous: 100))
        #expect(viewModel.comparison == PeriodComparison(percent: -10))
    }

    @Test func retaggingDropsTheComparisonAndKeepsTheMonthTotal() {
        let original = snapshot(.week, total: 120, previous: 100, month: 480)
        let retagged = original.retagged(for: .allTime)

        #expect(retagged.period == .allTime)
        #expect(retagged.previousTotal == nil)
        #expect(retagged.monthTotal == 480)
        #expect(retagged.total == 120)
        #expect(retagged.id != original.id)
    }
}
