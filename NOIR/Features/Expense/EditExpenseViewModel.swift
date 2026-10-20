//
//  EditExpenseViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

/// Edit Expense: updates or deletes an existing expense.
@MainActor
@Observable
final class EditExpenseViewModel {

    var form: ExpenseForm
    /// Choices for the picker: the built-ins plus the expense's own category until the first `loadCategories()`.
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    /// A save or delete is in flight; Save is disabled and a second call is ignored.
    private(set) var isSaving = false

    var canSave: Bool { form.canSave }

    let repository: ExpenseRepositoryProvider
    private let expenseID: PersistentIdentifier

    /// Writes to the store. Injectable because the repository's save and delete also adjust Home's overview memos
    /// in `UserDefaults.standard`, which tests must not touch.
    typealias Updater = @Sendable (PersistentIdentifier, ExpenseForm) async throws -> Void
    typealias Deleter = @Sendable (PersistentIdentifier) async throws -> Void
    private let updateExpense: Updater
    private let deleteExpense: Deleter

    init(
        expense: ExpenseDTO,
        model: ModelContainer = NOIRApp.sharedModelContainer,
        updater: Updater? = nil,
        deleter: Deleter? = nil
    ) {
        let repository = ExpenseRepositoryProvider(container: model)
        self.repository = repository
        self.expenseID = expense.id
        self.updateExpense = updater ?? { try await repository.save($1, id: $0) }
        self.deleteExpense = deleter ?? { id in try await repository.perform { try await $0.delete(id: id) } }
        form = ExpenseForm(
            amount: Decimal(expense.amount),
            name: expense.name,
            date: expense.date,
            category: expense.categoryInfo.key,
            description: expense.description
        )
        if !categories.contains(where: { $0.key == expense.categoryInfo.key }) {
            categories.append(expense.categoryInfo)
        }
    }

    /// Returns whether it actually saved (false when there was nothing to save or a write was already running).
    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await updateExpense(expenseID, form.trimmed)
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        return true
    }

    func delete() async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        try await deleteExpense(expenseID)
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
    }

    /// Refreshes the picker's choices. A selection whose category no longer exists falls back to Other.
    func loadCategories() async {
        let loaded: [CategoryInfo]
        do {
            loaded = try await repository.perform { try await $0.fetchCategories() }
        } catch {
            print("Failed to load categories: \(error)")
            return
        }
        categories = loaded
        if !loaded.contains(where: { $0.key == form.category }) {
            form.category = ExpenseCategory.other.rawValue
        }
    }
}
