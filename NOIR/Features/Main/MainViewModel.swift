//
//  MainViewModel.swift
//  NOIR
//
//  Created by Henrique Pacheco on 26/07/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class MainViewModel {
    var state: State = .loading
    let repository: ExpenseRepositoryProvider
    let sideRepository: ExpenseRepositoryProvider

    enum State {
        case loading
        case empty
        case loaded(OverviewSnapshot)
    }

    static let latestLimit = 5

    private(set) var period: SpendingPeriod = .week
    private var requestID = 0
    private var loadTask: Task<Void, Never>?

    init(model: ModelContainer) {
        self.repository = .init(container: model)
        self.sideRepository = .init(container: model)
    }

    /// Switches the period and reloads. Call from the same animation transaction that changes the selection.
    /// Quick successive calls cancel the stale load; only the newest request is applied.
    func selectPeriod(_ newPeriod: SpendingPeriod) {
        guard newPeriod != period else { return }
        period = newPeriod
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    /// Adopts the view's period without loading (used before `fetchData()` when a view is recreated).
    func adoptPeriod(_ newPeriod: SpendingPeriod) {
        period = newPeriod
    }

    /// Reloads the overview for the current period (also triggered by `.expensesDidChange`).
    @MainActor
    func fetchData() async {
        loadTask?.cancel()
        let task = Task { await load() }
        loadTask = task
        await task.value
    }

    @MainActor
    private func load() async {
        requestID += 1
        let id = requestID
        let period = period

        do {
            let now = Date.now
            let latestLimit = Self.latestLimit

            async let chartLoad = repository.perform { try await $0.overviewChart(period: period, now: now) }
            async let sideLoad = sideRepository.perform {
                try await $0.overviewSide(now: now, latestLimit: latestLimit)
            }
            
            let chart = try await chartLoad
            let side = try await sideLoad
            guard id == requestID, !Task.isCancelled else { return }

            let snapshot = OverviewSnapshot(
                period: period,
                points: chart.points,
                total: chart.total,
                latest: side.latest,
                hasAnyExpenses: side.hasAnyExpenses
            )

            withAnimation(.snappy) {
                state = snapshot.hasAnyExpenses ? .loaded(snapshot) : .empty
            }
        } catch {
            print("Failed to fetch expenses: \(error)")
            guard id == requestID, !Task.isCancelled, case .loaded(let last) = state, last.period != period else { return }
            state = .loaded(last.retagged(for: period))
        }
    }

    @MainActor
    func delete(id: PersistentIdentifier) async {
        do {
            try await repository.perform { try await $0.delete(id: id) }
            // Home reloads from its own listener; Search and Dashboard need the notification too.
            NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        } catch {
            print(error)
        }
    }
}

struct ExpenseDTO: Sendable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let categoryInfo: CategoryInfo
    let amount: Double
    let date: Date
    let description: String

    nonisolated init(_ expense: Expense, categories: [String: CategoryInfo]) {
        self.id = expense.persistentModelID
        self.name = expense.name
        self.categoryInfo = categories[expense.categoryRawValue] ?? categories[ExpenseCategory.other.rawValue] ?? CategoryInfo.other
        self.date = expense.date
        self.amount = expense.amount
        self.description = expense.expenseDescription
    }
}

extension ExpenseDTO: Equatable {}
