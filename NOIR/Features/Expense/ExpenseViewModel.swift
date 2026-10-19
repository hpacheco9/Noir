//
//  ExpenseViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

struct ExpenseLocation: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var name: String
}

@MainActor
@Observable
final class ExpenseViewModel {

    var amount = Decimal.zero
    var name = ""
    var date = Date.now
    /// `CategoryInfo.key` of the selected category (built-in raw value or `custom:<uuid>`).
    var category: String = ExpenseCategory.other.rawValue
    /// Choices for the picker. Starts with the plain built-ins until the first `loadCategories()` (kicked off in `init`).
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    var description = ""
    
    var isEditing: Bool = false
    /// A save is in flight; the Save button is disabled and a second `save()` is ignored.
    private(set) var isSaving = false
    
    let repository: ExpenseRepositoryProvider
    
    private var editingExpense: ExpenseDTO?
    
    var title: String { isEditing ? String(localized: L10n.AddExpenseView.editTitle) : String(localized: L10n.AddExpenseView.createTitle) }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }
    
    init(model: ModelContainer) {
        self.repository = .init(container: model)
        // The shared instance keeps the last loaded list, so the picker already has overrides when a sheet opens.
        Task { await loadCategories() }
    }

    /// Returns whether it actually saved (false when there was nothing to save or a save was already running).
    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        let id = editingExpense?.id
        let amountValue = NSDecimalNumber(decimal: amount).doubleValue
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = date
        let categoryKey = category
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        try await repository.perform {
            try await $0.save(
                id: id,
                amount: amountValue,
                name: trimmedName,
                date: date,
                categoryKey: categoryKey,
                description: trimmedDescription
            )
        }
        reset()
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        return true
    }

    func delete() async throws {
        guard let id = editingExpense?.id else { return }

        try await repository.perform { try await $0.delete(id: id) }
        reset()
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
        if !loaded.contains(where: { $0.key == category }) {
            category = ExpenseCategory.other.rawValue
        }
    }

    func configure(with expense: ExpenseDTO?) {
        guard let expense else {
            reset()
            return
        }

        editingExpense = expense
        amount = Decimal(expense.amount)
        name = expense.name
        date = expense.date
        category = expense.categoryInfo.key
        if !categories.contains(where: { $0.key == category }) {
            categories.append(expense.categoryInfo)
        }
        description = expense.description
        isEditing = true
    }
    
    func reset() {
        amount = 0
        name = ""
        category = ExpenseCategory.other.rawValue
        description = ""
        date = .now
        
        isEditing = false
        
       editingExpense = nil
    }
}
