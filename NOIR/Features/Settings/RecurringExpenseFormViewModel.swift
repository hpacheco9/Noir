//
//  RecurringExpenseFormViewModel.swift
//  NOIR
//

import Foundation
import Observation

@MainActor
@Observable
final class RecurringExpenseFormViewModel {
    // `form.date` is the next due date and `form.repeats` the frequency (never nil here).
    var form: ExpenseForm
    private(set) var categories: [CategoryInfo] = CategoryInfo.builtIns
    private(set) var cards: [String] = []
    private(set) var isSaving = false

    var canSave: Bool { form.canSave }
    var isEditing: Bool { recurringID != nil }

    private let recurringID: UUID?
    private let repository: ExpenseRepositoryProvider

    init(editing recurring: RecurringExpenseDTO? = nil, repository: ExpenseRepositoryProvider? = nil) {
        self.repository = repository ?? .init(container: NOIRApp.sharedModelContainer)
        recurringID = recurring?.id
        guard let recurring else {
            form = ExpenseForm(repeats: .monthly)
            return
        }
        form = ExpenseForm(
            amount: Decimal(string: String(recurring.amount)) ?? Decimal(recurring.amount),
            name: recurring.name,
            date: recurring.nextDueDate,
            category: recurring.categoryInfo.key,
            description: recurring.note,
            card: recurring.card,
            repeats: recurring.frequency
        )
        if !recurring.card.isEmpty { cards = [recurring.card] }
        if let index = categories.firstIndex(where: { $0.key == recurring.categoryInfo.key }) {
            categories[index] = recurring.categoryInfo
        } else {
            categories.append(recurring.categoryInfo)
        }
    }

    @discardableResult
    func save() async throws -> Bool {
        guard canSave, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await repository.saveRecurring(form.trimmed, frequency: form.repeats ?? .monthly, id: recurringID)
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
        return true
    }

    @discardableResult
    func stopRepeating() async throws -> Bool {
        guard let recurringID, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        try await repository.deleteRecurring(id: recurringID)
        NotificationCenter.default.post(name: .recurringDidChange, object: nil)
        return true
    }

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
            form.category = ExpenseCategory.food.rawValue
        }
    }

    func loadCards() async {
        do {
            cards = try await repository.perform { try await $0.fetchCards() }
            if !isEditing, form.card.isEmpty, let mostUsed = cards.first { form.card = mostUsed }
        } catch {
            print("Failed to load cards: \(error)")
        }
    }
}
