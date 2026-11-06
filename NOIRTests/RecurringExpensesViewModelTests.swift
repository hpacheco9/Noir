//
//  RecurringExpensesViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

struct RecurringExpensesViewModelTests {
    private func withFixture(
        _ body: (RecurringExpensesViewModel, ExpenseRepository, RecordingNotificationCenter) async throws -> Void
    ) async throws {
        let suite = "NOIRTests.recurringList.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self, RecurringExpense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let center = RecordingNotificationCenter()
        let provider = ExpenseRepositoryProvider(
            container: container, notifications: NotificationService(center: center, defaults: defaults)
        )
        try await body(RecurringExpensesViewModel(repository: provider), ExpenseRepository(modelContainer: container), center)
    }

    private func add(_ name: String, day: Int, to repository: ExpenseRepository) async throws -> RecurringExpenseDTO {
        try await repository.saveRecurring(
            id: nil, amount: 5, name: name, categoryKey: "food", card: "", note: "",
            frequency: .monthly, nextDueDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: day))!
        )
    }

    @Test func loadListsTheSoonestDueFirst() async throws {
        try await withFixture { viewModel, repository, _ in
            _ = try await add("later", day: 20, to: repository)
            _ = try await add("sooner", day: 10, to: repository)
            #expect(viewModel.isLoaded == false)

            await viewModel.load()

            #expect(viewModel.isLoaded)
            #expect(viewModel.items.map(\.name) == ["sooner", "later"])
            #expect(viewModel.errorMessage == nil)
        }
    }

    @Test func stopRepeatingDeletesTheRowAndItsReminder() async throws {
        try await withFixture { viewModel, repository, center in
            let first = try await add("first", day: 10, to: repository)
            _ = try await add("second", day: 20, to: repository)
            await viewModel.load()

            await viewModel.stopRepeating(first)

            #expect(viewModel.items.map(\.name) == ["second"])
            #expect(try await repository.fetchRecurring().map(\.name) == ["second"])
            #expect(center.removed == ["recurring.\(first.id.uuidString)"])
            #expect(viewModel.errorMessage == nil)
        }
    }

    @Test func aRowDeletedElsewhereCountsAsStopped() async throws {
        try await withFixture { viewModel, repository, _ in
            let gone = try await add("gone", day: 10, to: repository)
            _ = try await add("kept", day: 20, to: repository)
            await viewModel.load()
            try await repository.deleteRecurring(id: gone.id)

            await viewModel.stopRepeating(gone)

            #expect(viewModel.items.map(\.name) == ["kept"])
            #expect(viewModel.errorMessage == nil)
        }
    }
}
