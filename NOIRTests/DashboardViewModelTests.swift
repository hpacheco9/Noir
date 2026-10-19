//
//  DashboardViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import os
@testable import NOIR

/// Drives the view model with injected loaders, so timing and failures are under the test's control and nothing
/// touches a store or `UserDefaults`.
struct DashboardViewModelTests {
    private struct LoadFailure: Error {}

    private static func breakdown(total: Decimal) -> CategoryBreakdown {
        CategoryBreakdown(
            total: total,
            categories: [CategorySpending(info: CategoryInfo(builtIn: .food), amount: total, count: 1)]
        )
    }

    private func loadedTotal(_ viewModel: DashboardViewModel) -> Decimal? {
        if case .loaded(let breakdown) = viewModel.state { breakdown.total } else { nil }
    }

    private func isEmpty(_ viewModel: DashboardViewModel) -> Bool {
        if case .empty = viewModel.state { true } else { false }
    }

    private func isFailed(_ viewModel: DashboardViewModel) -> Bool {
        if case .failed = viewModel.state { true } else { false }
    }

    /// A sleep that ignores cancellation, so a "stale" load really does finish late and has to be dropped by the
    /// request id, not by cancellation alone.
    private static func uncancellableSleep(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    @Test func firstAppearLoadsTheDefaultPeriod() async {
        let periods = OSAllocatedUnfairLock<[SpendingPeriod]>(initialState: [])
        let viewModel = DashboardViewModel { period, _ in
            periods.withLock { $0.append(period) }
            return Self.breakdown(total: 5)
        }
        #expect(viewModel.period == .month)
        #expect(viewModel.loadedPeriod == nil)

        viewModel.didAppear()
        await viewModel.waitUntilIdle()

        #expect(periods.withLock { $0 } == [.month])
        #expect(viewModel.loadedPeriod == .month)
        #expect(loadedTotal(viewModel) == 5)
    }

    @Test func emptyBreakdownMapsToEmptyState() async {
        let viewModel = DashboardViewModel { _, _ in .empty }
        await viewModel.reload()
        #expect(isEmpty(viewModel))
        #expect(viewModel.loadedPeriod == .month)
    }

    @Test func aStaleRequestIsDropped() async {
        let viewModel = DashboardViewModel { period, _ in
            if period == .month {
                await Self.uncancellableSleep(150)
                return Self.breakdown(total: 1)
            }
            return Self.breakdown(total: 2)
        }
        viewModel.didAppear()                 // month, slow
        viewModel.selectPeriod(.week)         // week, fast: supersedes it
        await viewModel.waitUntilIdle()
        await Self.uncancellableSleep(300)    // let the stale month result arrive

        #expect(viewModel.loadedPeriod == .week)
        #expect(loadedTotal(viewModel) == 2)
    }

    @Test func theLastOfTwoQuickSwitchesWins() async {
        let viewModel = DashboardViewModel { period, _ in
            switch period {
            case .week:
                await Self.uncancellableSleep(150)
                return Self.breakdown(total: 7)
            default:
                return Self.breakdown(total: 3)
            }
        }
        await viewModel.reload()
        viewModel.selectPeriod(.week)
        viewModel.selectPeriod(.day)
        await viewModel.waitUntilIdle()
        await Self.uncancellableSleep(300)

        #expect(viewModel.period == .day)
        #expect(viewModel.loadedPeriod == .day)
        #expect(loadedTotal(viewModel) == 3)
    }

    @Test func loadedPeriodChangesOnlyWhenDataLands() async {
        let viewModel = DashboardViewModel { period, _ in
            if period == .week { await Self.uncancellableSleep(100) }
            return Self.breakdown(total: 4)
        }
        await viewModel.reload()
        #expect(viewModel.loadedPeriod == .month)

        viewModel.selectPeriod(.week)
        #expect(viewModel.period == .week)
        #expect(viewModel.loadedPeriod == .month)   // still the old data

        await viewModel.waitUntilIdle()
        #expect(viewModel.loadedPeriod == .week)
    }

    @Test func aFailedSwitchRevertsThePickerAndKeepsTheData() async {
        let viewModel = DashboardViewModel { period, _ in
            if period == .week { throw LoadFailure() }
            return Self.breakdown(total: 9)
        }
        await viewModel.reload()

        viewModel.selectPeriod(.week)
        await viewModel.waitUntilIdle()

        #expect(viewModel.period == .month)
        #expect(viewModel.loadedPeriod == .month)
        #expect(loadedTotal(viewModel) == 9)
    }

    @Test func aFailedFirstLoadShowsTheErrorStateAndRetryRecovers() async {
        let shouldFail = OSAllocatedUnfairLock(initialState: true)
        let viewModel = DashboardViewModel { _, _ in
            if shouldFail.withLock({ $0 }) { throw LoadFailure() }
            return Self.breakdown(total: 6)
        }
        await viewModel.reload()
        #expect(isFailed(viewModel))
        #expect(!isEmpty(viewModel))
        #expect(viewModel.loadedPeriod == nil)

        shouldFail.withLock { $0 = false }
        viewModel.retry()
        await viewModel.waitUntilIdle()
        #expect(loadedTotal(viewModel) == 6)
    }

    // MARK: Dirty and coalesced reloads

    @Test func appearingAgainDoesNotReloadCleanData() async {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = DashboardViewModel { _, _ in
            calls.withLock { $0 += 1 }
            return Self.breakdown(total: 1)
        }
        viewModel.didAppear()
        await viewModel.waitUntilIdle()
        viewModel.didDisappear()
        viewModel.didAppear()
        await viewModel.waitUntilIdle()
        #expect(calls.withLock { $0 } == 1)
    }

    @Test func twoNotificationsInTheSameTurnShareOneReload() async {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = DashboardViewModel { _, _ in
            calls.withLock { $0 += 1 }
            return Self.breakdown(total: 1)
        }
        viewModel.didAppear()
        await viewModel.waitUntilIdle()
        #expect(calls.withLock { $0 } == 1)

        // A category update posts both notifications back to back.
        viewModel.markDirty()
        viewModel.markDirty()
        await viewModel.waitUntilIdle()
        #expect(calls.withLock { $0 } == 2)
    }

    @Test func changesWhileAwayReloadOnNextAppearance() async {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = DashboardViewModel { _, _ in
            calls.withLock { $0 += 1 }
            return Self.breakdown(total: Decimal(calls.withLock { $0 }))
        }
        viewModel.didAppear()
        await viewModel.waitUntilIdle()
        viewModel.didDisappear()

        viewModel.markDirty()
        viewModel.markDirty()
        await viewModel.waitUntilIdle()
        #expect(calls.withLock { $0 } == 1)   // nothing while the tab is hidden

        viewModel.didAppear()
        await viewModel.waitUntilIdle()
        #expect(calls.withLock { $0 } == 2)
        #expect(loadedTotal(viewModel) == 2)
    }
}
