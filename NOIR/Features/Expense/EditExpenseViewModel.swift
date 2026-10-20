//
//  EditExpenseViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class EditExpenseViewModel {

    var form: ExpenseForm
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    private(set) var cards: [String] = []
    private(set) var isSaving = false

    var canSave: Bool { form.canSave }

    let repository: ExpenseRepositoryProvider
    private let expenseID: PersistentIdentifier

    init(expense: ExpenseDTO, model: ModelContainer = NOIRApp.sharedModelContainer) {
        self.repository = ExpenseRepositoryProvider(container: model)
        self.expenseID = expense.id
        form = ExpenseForm(
            amount: Decimal(string: String(expense.amount)) ?? Decimal(expense.amount),
            name: expense.name,
            date: expense.date,
            category: expense.categoryInfo.key,
            description: expense.description,
            card: expense.card
        )
        if !expense.card.isEmpty { cards = [expense.card] }
        // The expense's own category as it is shown (custom, or a built-in with an override).
        if let index = categories.firstIndex(where: { $0.key == expense.categoryInfo.key }) {
            categories[index] = expense.categoryInfo
        } else {
            categories.append(expense.categoryInfo)
        }
    }

    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await repository.save(form.trimmed, id: expenseID)
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        return true
    }

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

    func loadCards() async {
        do {
            cards = try await repository.perform { try await $0.fetchCards() }
        } catch {
            print("Failed to load cards: \(error)")
        }
    }
}
