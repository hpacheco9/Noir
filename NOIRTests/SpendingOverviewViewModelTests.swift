//
//  SpendingOverviewViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct SpendingOverviewViewModelTests {
    private func snapshot(_ period: SpendingPeriod, total: Decimal) -> OverviewSnapshot {
        OverviewSnapshot(period: period, points: [], total: total, latest: [], hasAnyExpenses: true)
    }

    @Test func applyingASnapshotSetsTheTotalAndPeriod() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.markLoading(for: .week)
        #expect(viewModel.isComputing)

        viewModel.apply(snapshot(.week, total: 120))

        #expect(viewModel.totalSpent == 120)
        #expect(viewModel.appliedPeriod == .week)
        #expect(!viewModel.isComputing)
    }

    @Test func freshDataForTheSamePeriodReplacesTheTotal() {
        let viewModel = SpendingOverviewViewModel()
        viewModel.apply(snapshot(.week, total: 120))
        viewModel.apply(snapshot(.week, total: 90))
        #expect(viewModel.totalSpent == 90)
    }

    @Test func waitingResumesOnceThePeriodIsApplied() async {
        let viewModel = SpendingOverviewViewModel()
        let waiting = Task { await viewModel.waitUntilApplied(for: .month) }
        await Task.yield()

        viewModel.apply(snapshot(.week, total: 1))
        viewModel.apply(snapshot(.month, total: 2))
        await waiting.value

        #expect(viewModel.appliedPeriod == .month)
    }

    @Test func retaggingKeepsTheDataUnderANewPeriodAndId() {
        let original = snapshot(.week, total: 120)
        let retagged = original.retagged(for: .allTime)

        #expect(retagged.period == .allTime)
        #expect(retagged.total == 120)
        #expect(retagged.id != original.id)
    }
}
