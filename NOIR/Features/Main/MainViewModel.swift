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

    enum State {
        case loading
        case empty
        case loaded(OverviewSnapshot)
        case failed
    }

    typealias Loader = @Sendable (SpendingPeriod, Date) async throws -> OverviewSnapshot

    static let latestLimit = 5

    private(set) var period: SpendingPeriod = .week
    private var requestID = 0
    private var loadTask: Task<Void, Never>?
    private let loader: Loader

    init(model: ModelContainer, loader: Loader? = nil) {
        let repository = ExpenseRepositoryProvider(container: model)
        let sideRepository = ExpenseRepositoryProvider(container: model)
        let latestLimit = Self.latestLimit
        self.repository = repository
        self.loader = loader ?? { period, now in
            async let chartLoad = repository.perform { try await $0.overviewChart(period: period, now: now) }
            async let sideLoad = sideRepository.perform {
                try await $0.overviewSide(now: now, latestLimit: latestLimit)
            }

            let chart = try await chartLoad
            let side = try await sideLoad
            return OverviewSnapshot(
                period: period,
                points: chart.points,
                total: chart.total,
                latest: side.latest,
                hasAnyExpenses: side.hasAnyExpenses
            )
        }
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
        if case .failed = state { state = .loading }

        do {
            let snapshot = try await loader(period, .now)
            guard id == requestID, !Task.isCancelled else { return }

            withAnimation(.snappy) {
                state = snapshot.hasAnyExpenses ? .loaded(snapshot) : .empty
            }
        } catch {
            print("Failed to fetch expenses: \(error)")
            guard id == requestID, !Task.isCancelled else { return }
            switch state {
            case .loading:
                state = .failed
            case .loaded(let last) where last.period != period:
                state = .loaded(last.retagged(for: period))
            default:
                break
            }
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
    let card: String

    nonisolated init(_ expense: Expense, categories: [String: CategoryInfo]) {
        self.id = expense.persistentModelID
        self.name = expense.name
        self.categoryInfo = categories[expense.categoryRawValue] ?? categories[ExpenseCategory.other.rawValue] ?? CategoryInfo.other
        self.date = expense.date
        self.amount = expense.amount
        self.description = expense.expenseDescription
        self.card = expense.card
    }
}

extension ExpenseDTO: Equatable {}
