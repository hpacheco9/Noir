//
//  EditExpenseViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// Edit Expense on an in-memory store. The writes are injected and applied to that store directly, because the
/// repository's save and delete adjust Home's overview memos in `UserDefaults.standard`.
@MainActor
struct EditExpenseViewModelTests {
    private struct WriteFailed: Error {}

    private let container: ModelContainer
    private let expense: ExpenseDTO

    init() throws {
        container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let row = Expense(amount: 10, name: "Coffee", date: .now, category: .food, expenseDescription: "Morning")
        context.insert(row)
        try context.save()
        let categories = Dictionary(uniqueKeysWithValues: CategoryInfo.builtIns.map { ($0.key, $0) })
        expense = ExpenseDTO(row, categories: categories)
    }

    private func makeViewModel(
        updater: EditExpenseViewModel.Updater? = nil,
        deleter: EditExpenseViewModel.Deleter? = nil
    ) -> EditExpenseViewModel {
        let container = container
        return EditExpenseViewModel(
            expense: expense,
            model: container,
            updater: updater ?? { id, form in
                try await MainActor.run {
                    let context = ModelContext(container)
                    let row = try #require(context.model(for: id) as? Expense)
                    row.amount = NSDecimalNumber(decimal: form.amount).doubleValue
                    row.name = form.name
                    row.date = form.date
                    row.categoryRawValue = form.category
                    row.expenseDescription = form.description
                    try context.save()
                }
            },
            deleter: deleter ?? { id in
                try await MainActor.run {
                    let context = ModelContext(container)
                    context.delete(try #require(context.model(for: id) as? Expense))
                    try context.save()
                }
            }
        )
    }

    private func storedRows() throws -> [Expense] {
        try ModelContext(container).fetch(FetchDescriptor<Expense>())
    }

    @Test func formIsPrefilledFromTheExpense() {
        let viewModel = makeViewModel()
        #expect(viewModel.form.amount == 10)
        #expect(viewModel.form.name == "Coffee")
        #expect(viewModel.form.category == ExpenseCategory.food.rawValue)
        #expect(viewModel.form.description == "Morning")
        #expect(viewModel.canSave)
    }

    @Test func saveUpdatesTheStoredExpense() async throws {
        let viewModel = makeViewModel()
        viewModel.form.amount = Decimal(string: "24.9")!
        viewModel.form.name = "  Dinner "
        viewModel.form.category = ExpenseCategory.transport.rawValue
        viewModel.form.description = ""

        #expect(try await viewModel.save() == true)

        let row = try #require(try storedRows().first)
        #expect(try storedRows().count == 1)
        #expect(row.amount == 24.9)
        #expect(row.name == "Dinner")
        #expect(row.categoryRawValue == ExpenseCategory.transport.rawValue)
        #expect(row.expenseDescription == "")
        #expect(viewModel.isSaving == false)
    }

    @Test func invalidFormIsNotSaved() async throws {
        let viewModel = makeViewModel()
        viewModel.form.name = "  "

        #expect(try await viewModel.save() == false)
        #expect(try storedRows().first?.name == "Coffee")
    }

    @Test func failedSaveThrowsAndLeavesTheExpense() async throws {
        let viewModel = makeViewModel(updater: { _, _ in throw WriteFailed() })
        viewModel.form.name = "Dinner"

        await #expect(throws: WriteFailed.self) { try await viewModel.save() }
        #expect(viewModel.isSaving == false)
        #expect(try storedRows().first?.name == "Coffee")
    }

    @Test func deleteRemovesTheStoredExpense() async throws {
        let viewModel = makeViewModel()
        #expect(try storedRows().count == 1)

        try await viewModel.delete()

        #expect(try storedRows().isEmpty)
        #expect(viewModel.isSaving == false)
    }

    @Test func failedDeleteThrowsAndKeepsTheExpense() async throws {
        let viewModel = makeViewModel(deleter: { _ in throw WriteFailed() })

        await #expect(throws: WriteFailed.self) { try await viewModel.delete() }
        #expect(try storedRows().count == 1)
    }
}
