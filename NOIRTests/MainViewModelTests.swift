//
//  MainViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
import os
@testable import NOIR

// Drives the view model with injected loaders, so timing and failures are under the test's control and nothing
// touches the store or `UserDefaults`.
struct MainViewModelTests {
    private struct LoadFailure: Error {}

    private func makeViewModel(_ loader: @escaping MainViewModel.Loader) throws -> MainViewModel {
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return MainViewModel(model: container, loader: loader)
    }

    private static func snapshot(_ period: SpendingPeriod, total: Decimal, hasAnyExpenses: Bool = true) -> OverviewSnapshot {
        OverviewSnapshot(
            period: period, points: [], total: total, latest: [], hasAnyExpenses: hasAnyExpenses,
            previousTotal: nil, monthTotal: 0
        )
    }

    private func loaded(_ viewModel: MainViewModel) -> OverviewSnapshot? {
        if case .loaded(let snapshot) = viewModel.state { snapshot } else { nil }
    }

    private func isLoading(_ viewModel: MainViewModel) -> Bool {
        if case .loading = viewModel.state { true } else { false }
    }

    private func isEmpty(_ viewModel: MainViewModel) -> Bool {
        if case .empty = viewModel.state { true } else { false }
    }

    private func isFailed(_ viewModel: MainViewModel) -> Bool {
        if case .failed = viewModel.state { true } else { false }
    }

    // Runs on a detached task, so a cancelled load really does finish late and has to be dropped by the request id
    // or the cancellation check, not by waking up early.
    private static func uncancellableSleep(_ milliseconds: Int) async {
        await Task.detached { try? await Task.sleep(for: .milliseconds(milliseconds)) }.value
    }

    private func waitUntil(_ condition: () -> Bool) async {
        var attempts = 0
        while !condition(), attempts < 500 {
            try? await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        if !condition() { Issue.record("Timed out waiting for the loader to be called") }
    }

    // MARK: Failures

    @Test func aFailedFirstLoadShowsTheFailedState() async throws {
        let viewModel = try makeViewModel { _, _ in throw LoadFailure() }
        #expect(isLoading(viewModel))

        await viewModel.fetchData()

        #expect(isFailed(viewModel))
    }

    @Test func aFailedRetryStaysFailed() async throws {
        let viewModel = try makeViewModel { _, _ in throw LoadFailure() }
        await viewModel.fetchData()
        await viewModel.fetchData()
        #expect(isFailed(viewModel))
    }

    @Test func retryShowsLoadingWhileItRunsThenTheData() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = try makeViewModel { period, _ in
            let call = calls.withLock { count -> Int in count += 1; return count }
            if call == 1 { throw LoadFailure() }
            await Self.uncancellableSleep(100)
            return Self.snapshot(period, total: 6)
        }
        await viewModel.fetchData()
        #expect(isFailed(viewModel))

        let retry = Task { await viewModel.fetchData() }
        await waitUntil { calls.withLock { $0 } == 2 }
        #expect(isLoading(viewModel))

        await retry.value
        #expect(loaded(viewModel)?.total == 6)
    }

    @Test func aReloadFailureAfterSuccessKeepsTheData() async throws {
        let shouldFail = OSAllocatedUnfairLock(initialState: false)
        let viewModel = try makeViewModel { period, _ in
            if shouldFail.withLock({ $0 }) { throw LoadFailure() }
            return Self.snapshot(period, total: 5)
        }
        await viewModel.fetchData()
        let before = try #require(loaded(viewModel))

        shouldFail.withLock { $0 = true }
        await viewModel.fetchData()

        #expect(loaded(viewModel)?.id == before.id)
        #expect(!isFailed(viewModel))
    }

    @Test func aReloadFailureAfterAnEmptyResultStaysEmpty() async throws {
        let shouldFail = OSAllocatedUnfairLock(initialState: false)
        let viewModel = try makeViewModel { period, _ in
            if shouldFail.withLock({ $0 }) { throw LoadFailure() }
            return Self.snapshot(period, total: 0, hasAnyExpenses: false)
        }
        await viewModel.fetchData()
        #expect(isEmpty(viewModel))

        shouldFail.withLock { $0 = true }
        await viewModel.fetchData()

        #expect(isEmpty(viewModel))
    }

    @Test func aFailedPeriodSwitchKeepsTheDataUnderTheNewPeriod() async throws {
        let viewModel = try makeViewModel { period, _ in
            if period == .month { throw LoadFailure() }
            return Self.snapshot(period, total: 8)
        }
        viewModel.adoptPeriod(.week)
        await viewModel.fetchData()

        viewModel.adoptPeriod(.month)
        await viewModel.fetchData()

        #expect(loaded(viewModel)?.period == .month)
        #expect(loaded(viewModel)?.total == 8)
    }

    // MARK: Stale requests

    @Test func aStaleFailureDoesNotOverwriteANewerSuccess() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = try makeViewModel { period, _ in
            calls.withLock { $0 += 1 }
            if period == .week {
                await Self.uncancellableSleep(100)
                throw LoadFailure()
            }
            return Self.snapshot(period, total: 2)
        }
        viewModel.adoptPeriod(.week)
        let stale = Task { await viewModel.fetchData() }    // week: slow failure
        await waitUntil { calls.withLock { $0 } == 1 }
        viewModel.adoptPeriod(.month)
        await viewModel.fetchData()                         // month: fast success
        #expect(loaded(viewModel)?.period == .month)

        await stale.value                                   // the stale failure has landed
        #expect(loaded(viewModel)?.period == .month)
        #expect(loaded(viewModel)?.total == 2)
    }

    @Test func aStaleFailureDoesNotFailAPendingLoad() async throws {
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let viewModel = try makeViewModel { period, _ in
            calls.withLock { $0 += 1 }
            if period == .week {
                await Self.uncancellableSleep(50)
                throw LoadFailure()
            }
            await Self.uncancellableSleep(400)
            return Self.snapshot(period, total: 3)
        }
        viewModel.adoptPeriod(.week)
        let stale = Task { await viewModel.fetchData() }    // week: failure after 50 ms
        await waitUntil { calls.withLock { $0 } == 1 }
        viewModel.adoptPeriod(.month)
        let newer = Task { await viewModel.fetchData() }    // month: success after 400 ms
        await waitUntil { calls.withLock { $0 } == 2 }

        await stale.value
        #expect(isLoading(viewModel))                       // still waiting for the newer request

        await newer.value
        #expect(loaded(viewModel)?.total == 3)
    }
}
