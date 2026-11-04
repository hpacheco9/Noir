//
//  RecurringExpenseFormViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

// Settings form against an in-memory store; saves and deletes never touch the overview memos.
struct RecurringExpenseFormViewModelTests {
    private struct Fixture {
        let container: ModelContainer
        let provider: ExpenseRepositoryProvider
        let repository: ExpenseRepository
    }

    private func withFixture(_ body: (Fixture) async throws -> Void) async throws {
        let suite = "NOIRTests.recurringForm.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self, RecurringExpense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let provider = ExpenseRepositoryProvider(
            container: container,
            notifications: NotificationService(center: RecordingNotificationCenter(), defaults: defaults)
        )
        try await SavedCards.$suiteName.withValue(suite) {
            try await body(Fixture(container: container, provider: provider, repository: ExpenseRepository(modelContainer: container)))
        }
    }

    private var calendar: Calendar { .current }

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func dto(
        category: CategoryInfo = CategoryInfo(builtIn: .transport),
        card: String = "Visa",
        frequency: RecurrenceFrequency = .weekly
    ) -> RecurringExpenseDTO {
        let template = RecurringExpense(
            name: "Bus pass", amount: 12.5, categoryRawValue: category.key, card: card, note: "monthly",
            frequency: frequency, startDate: noon(2026, 1, 31), nextDueDate: noon(2026, 2, 28)
        )
        return RecurringExpenseDTO(template, categories: [category.key: category])
    }

    private func storedNextDueDate(in container: ModelContainer) throws -> Date? {
        try ModelContext(container).fetch(FetchDescriptor<RecurringExpense>()).first?.nextDueDate
    }

    // MARK: Mapping

    @Test func editingMapsTheRecurringExpenseIntoTheForm() async throws {
        try await withFixture { fixture in
            let item = dto()
            let viewModel = RecurringExpenseFormViewModel(editing: item, repository: fixture.provider)

            #expect(viewModel.isEditing)
            #expect(viewModel.form.amount == Decimal(string: "12.5"))
            #expect(viewModel.form.name == "Bus pass")
            #expect(viewModel.form.date == noon(2026, 2, 28))
            #expect(viewModel.form.category == "transport")
            #expect(viewModel.form.description == "monthly")
            #expect(viewModel.form.card == "Visa")
            #expect(viewModel.form.repeats == .weekly)
            #expect(viewModel.cards == ["Visa"])
            #expect(viewModel.categories.contains(item.categoryInfo))
            #expect(viewModel.canSave)
        }
    }

    @Test func creatingStartsMonthlyAndNeedsAnAmountAndName() async throws {
        try await withFixture { fixture in
            let viewModel = RecurringExpenseFormViewModel(repository: fixture.provider)
            #expect(viewModel.isEditing == false)
            #expect(viewModel.form.repeats == .monthly)
            #expect(viewModel.canSave == false)
        }
    }

    @Test func aDeletedCategoryFallsBackToFood() async throws {
        try await withFixture { fixture in
            let gone = CategoryInfo(custom: CustomCategory(name: "Pets", symbol: AssetName.CategorySymbols.all[0], colorRawValue: "teal"))
            let viewModel = RecurringExpenseFormViewModel(editing: dto(category: gone), repository: fixture.provider)
            #expect(viewModel.form.category == gone.key)

            await viewModel.loadCategories()

            #expect(viewModel.form.category == ExpenseCategory.food.rawValue)
            #expect(viewModel.categories.contains { $0.key == gone.key } == false)
        }
    }

    @Test func theMostUsedCardIsPreselectedOnlyWhenCreating() async throws {
        try await withFixture { fixture in
            let context = ModelContext(fixture.container)
            for _ in 0..<2 {
                context.insert(Expense(amount: 1, name: "x", date: .now, category: .food, card: "Amex"))
            }
            try context.save()

            let creating = RecurringExpenseFormViewModel(repository: fixture.provider)
            await creating.loadCards()
            #expect(creating.form.card == "Amex")

            let editing = RecurringExpenseFormViewModel(editing: dto(card: ""), repository: fixture.provider)
            await editing.loadCards()
            #expect(editing.form.card == "")
            #expect(editing.cards == ["Amex"])
        }
    }

    // MARK: The date it was loaded with

    @Test func anUntouchedDateDoesNotMoveBackAScheduleAdvancedMeanwhile() async throws {
        try await withFixture { fixture in
            let saved = try await fixture.repository.saveRecurring(
                id: nil, amount: 12.5, name: "Rent", categoryKey: "food", card: "", note: "",
                frequency: .monthly, nextDueDate: noon(2026, 1, 31)
            )
            let viewModel = RecurringExpenseFormViewModel(editing: saved, repository: fixture.provider)
            // Skipped from Home while the form is open.
            let skipped = try await fixture.repository.skipDueOccurrence(id: saved.id)
            #expect(skipped.nextDueDate == noon(2026, 2, 28))

            viewModel.form.name = "Flat"
            try await viewModel.save()

            #expect(try storedNextDueDate(in: fixture.container) == noon(2026, 2, 28))
            let stored = try #require(try await fixture.repository.fetchRecurring().first)
            #expect(stored.name == "Flat")
        }
    }

    @Test func aChangedDayIsSentAndRestartsTheSchedule() async throws {
        try await withFixture { fixture in
            let saved = try await fixture.repository.saveRecurring(
                id: nil, amount: 12.5, name: "Rent", categoryKey: "food", card: "", note: "",
                frequency: .monthly, nextDueDate: noon(2026, 1, 31)
            )
            let viewModel = RecurringExpenseFormViewModel(editing: saved, repository: fixture.provider)

            viewModel.form.date = noon(2026, 3, 15)
            try await viewModel.save()

            #expect(try storedNextDueDate(in: fixture.container) == noon(2026, 3, 15))
        }
    }

    @Test func creatingSavesTheChosenDate() async throws {
        try await withFixture { fixture in
            let viewModel = RecurringExpenseFormViewModel(repository: fixture.provider)
            viewModel.form.amount = 20
            viewModel.form.name = "Gym"
            viewModel.form.date = noon(2026, 6, 1)
            viewModel.form.repeats = .yearly

            try await viewModel.save()

            let stored = try #require(try await fixture.repository.fetchRecurring().first)
            #expect(stored.nextDueDate == noon(2026, 6, 1))
            #expect(stored.frequency == .yearly)
        }
    }

    // MARK: Stop Repeating

    @Test func stopRepeatingDeletesAndCountsAnAlreadyDeletedOneAsDone() async throws {
        try await withFixture { fixture in
            let saved = try await fixture.repository.saveRecurring(
                id: nil, amount: 5, name: "Rent", categoryKey: "food", card: "", note: "",
                frequency: .monthly, nextDueDate: noon(2026, 1, 31)
            )
            let viewModel = RecurringExpenseFormViewModel(editing: saved, repository: fixture.provider)
            #expect(try await viewModel.stopRepeating())
            #expect(try await fixture.repository.fetchRecurring().isEmpty)

            // Deleted from the list in the meantime.
            let again = RecurringExpenseFormViewModel(editing: saved, repository: fixture.provider)
            #expect(try await again.stopRepeating())
        }
    }
}
