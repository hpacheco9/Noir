//
//  DashboardViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    enum State {
        case loading
        /// The period has no spending.
        case empty
        case loaded(CategoryBreakdown)
        /// The first load failed, so there is nothing to show yet.
        case failed
    }

    /// Computes the breakdown off the main actor. Injectable so tests can control timing and failures.
    typealias Loader = @Sendable (SpendingPeriod, Date) async throws -> CategoryBreakdown

    private(set) var state: State = .loading
    /// The period the picker shows.
    private(set) var period: SpendingPeriod = .month
    /// The period `state` was computed for. Differs from `period` while a switch is loading, and changes only when
    /// the new data is applied (the view announces that to VoiceOver).
    private(set) var loadedPeriod: SpendingPeriod?

    private let loader: Loader
    private var requestID = 0
    private var loadTask: Task<Void, Never>?
    private var pendingReload: Task<Void, Never>?
    /// The data on screen may be out of date (never loaded, a write happened, or the last load failed).
    private var isDirty = true
    private var isVisible = false

    init(model: ModelContainer) {
        let repository = ExpenseRepositoryProvider(container: model)
        self.loader = { period, now in
            try await repository.perform { try await $0.categoryBreakdown(period: period, now: now) }
        }
    }

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    // MARK: - Period

    /// Switches the period and reloads. A quick second switch cancels the first; only the newest result is applied.
    func selectPeriod(_ newPeriod: SpendingPeriod) {
        guard newPeriod != period else { return }
        period = newPeriod
        startLoad()
    }

    // MARK: - Visibility and invalidation

    /// The tab appeared: load if nothing is loaded yet or something changed while it was away.
    func didAppear() {
        isVisible = true
        if isDirty { startLoad() }
    }

    func didDisappear() {
        isVisible = false
    }

    /// Expenses or categories changed. Reloads at once when the tab is visible, otherwise on the next appearance.
    /// Calls in the same turn (a category update posts two notifications) share one reload.
    func markDirty() {
        isDirty = true
        guard isVisible, pendingReload == nil else { return }
        pendingReload = Task {
            await Task.yield()
            pendingReload = nil
            if isDirty { startLoad() }
        }
    }

    func retry() {
        startLoad()
    }

    /// Starts a load and waits for it (tests and pull-to-refresh style callers).
    func reload() async {
        startLoad()
        await loadTask?.value
    }

    /// Waits for scheduled and running work (tests).
    func waitUntilIdle() async {
        await pendingReload?.value
        await loadTask?.value
    }

    // MARK: - Loading

    /// The request id is taken here, synchronously, so a later call always invalidates an earlier one.
    private func startLoad() {
        requestID += 1
        let id = requestID
        let period = period
        isDirty = false
        loadTask?.cancel()
        loadTask = Task { await load(id: id, period: period) }
    }

    private func load(id: Int, period: SpendingPeriod) async {
        do {
            let breakdown = try await loader(period, .now)
            guard id == requestID, !Task.isCancelled else { return }
            state = breakdown.categories.isEmpty ? .empty : .loaded(breakdown)
            loadedPeriod = period
        } catch {
            guard id == requestID, !Task.isCancelled else { return }
            print("Failed to load the category breakdown: \(error)")
            isDirty = true
            if let loadedPeriod {
                // Keep the data on screen and make the picker agree with it again.
                self.period = loadedPeriod
            } else {
                state = .failed
            }
        }
    }
}
