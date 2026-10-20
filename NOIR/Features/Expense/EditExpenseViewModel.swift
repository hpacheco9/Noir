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

    init(expense: ExpenseDTO, model: ModelContainer = NOIRApp.sharedModelContainer) {
        self.repository = ExpenseRepositoryProvider(container: model)
        self.expenseID = expense.id
        form = ExpenseForm(
            // From the shortest description, so 19.99 stays 19.99 (`Decimal(Double)` gives 19.98999…).
            amount: Decimal(string: String(expense.amount)) ?? Decimal(expense.amount),
            name: expense.name,
            date: expense.date,
            category: expense.categoryInfo.key,
            description: expense.description
        )
        // The expense's own category as it is shown (custom, or a built-in with an override).
        if let index = categories.firstIndex(where: { $0.key == expense.categoryInfo.key }) {
            categories[index] = expense.categoryInfo
        } else {
            categories.append(expense.categoryInfo)
        }
    }

    /// Returns whether it actually saved (false when there was nothing to save or a write was already running).
    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await repository.save(form.trimmed, id: expenseID)
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        return true
    }

    /// Returns whether it actually deleted (false when a write was already running).
    @discardableResult
    func delete() async throws -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        let id = expenseID
        try await repository.perform { try await $0.delete(id: id) }
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        return true
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
