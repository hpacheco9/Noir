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
    private(set) var dueRecurring: [RecurringExpenseDTO] = []
    private(set) var processingDue: Set<UUID> = []
    private var requestID = 0
    private var dueRequestID = 0
    private var loadTask: Task<Void, Never>?
    private let loader: Loader
    private let sideRepository: ExpenseRepositoryProvider
    private let reviewPrompt: ReviewPromptStore

    init(
        model: ModelContainer,
        loader: Loader? = nil,
        reviewPrompt: ReviewPromptStore = ReviewPromptStore(),
        notifications: NotificationService = .shared
    ) {
        let repository = ExpenseRepositoryProvider(container: model, notifications: notifications)
        let sideRepository = ExpenseRepositoryProvider(container: model, notifications: notifications)
        let latestLimit = Self.latestLimit
        self.repository = repository
        self.sideRepository = sideRepository
        self.reviewPrompt = reviewPrompt
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
                hasAnyExpenses: side.hasAnyExpenses,
                monthTotal: side.monthTotal
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

    func adoptPeriod(_ newPeriod: SpendingPeriod) {
        period = newPeriod
    }

    @MainActor
    func fetchData() async {
        loadTask?.cancel()
        let task = Task { await load() }
        loadTask = task
        async let due: Void = loadDue()
        await task.value
        await due
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
    func loadDue(now: Date = .now, calendar: Calendar = .current) async {
        dueRequestID += 1
        let id = dueRequestID
        do {
            let all = try await sideRepository.perform { try await $0.fetchRecurring() }
            guard id == dueRequestID else { return }
            withAnimation(.snappy) {
                dueRecurring = all.filter { RecurringExpense.isDue($0.nextDueDate, now: now, calendar: calendar) }
            }
        } catch {
            print("Failed to fetch recurring expenses: \(error)")
        }
    }

    @MainActor
    func addDue(_ id: UUID) async throws {
        try await advanceDue(id) {
            try await $0.addDueOccurrence(id: id)
            reviewPrompt.recordCreatedExpense()
            NotificationCenter.default.post(name: .expensesDidChange, object: self)
        }
    }

    @MainActor
    func skipDue(_ id: UUID) async throws {
        try await advanceDue(id) { try await $0.skipDueOccurrence(id: id) }
    }

    // The row stays disabled until the reload has replaced it.
    @MainActor
    private func advanceDue(_ id: UUID, _ action: (ExpenseRepositoryProvider) async throws -> Void) async throws {
        guard processingDue.insert(id).inserted else { return }
        defer { processingDue.remove(id) }
        do {
            try await action(sideRepository)
        } catch {
            await loadDue()
            throw error
        }
        await loadDue()
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
