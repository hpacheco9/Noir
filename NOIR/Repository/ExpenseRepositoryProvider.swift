//
//  ExpenseRepositoryProvider.swift
//  NOIR
//

import Foundation
import SwiftData

final class ExpenseRepositoryProvider: Sendable {
    private let creation: Task<ExpenseRepository, Never>
    private let notifications: NotificationService

    init(container: ModelContainer, notifications: NotificationService = .shared) {
        creation = Task.detached(priority: .userInitiated) {
            ExpenseRepository(modelContainer: container)
        }
        self.notifications = notifications
    }
    @concurrent
    func perform<T: Sendable>(_ body: @Sendable (ExpenseRepository) async throws -> T) async rethrows -> T {
        let repository = await creation.value
        return try await body(repository)
    }
}

extension ExpenseRepositoryProvider {
    static let otherRetiredKey = "migration.other_category_retired"

    // The flag is set only after success, so a failure retries next launch.
    func retireOtherCategoryOnce(defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: Self.otherRetiredKey) else { return }
        guard (try? await perform { try await $0.retireOtherCategory() }) != nil else { return }
        defaults.set(true, forKey: Self.otherRetiredKey)
    }

    /// Inserts (`id == nil`) or updates an expense with the form's values. A new expense with `form.repeats` set
    /// also becomes a recurring expense.
    func save(_ form: ExpenseForm, id: PersistentIdentifier?) async throws {
        let recurring = try await perform {
            try await $0.save(
                id: id,
                amount: form.amountValue,
                name: form.name,
                date: form.date,
                categoryKey: form.category,
                description: form.description,
                card: form.card,
                repeating: form.repeats
            )
        }
        if let recurring { await notifications.scheduleRecurringReminder(recurring) }
    }

    /// Inserts (`id == nil`) or updates a recurring expense; the form's date is its next due date.
    func saveRecurring(_ form: ExpenseForm, frequency: RecurrenceFrequency, id: UUID?) async throws {
        let recurring = try await perform {
            try await $0.saveRecurring(
                id: id,
                amount: form.amountValue,
                name: form.name,
                categoryKey: form.category,
                card: form.card,
                note: form.description,
                frequency: frequency,
                nextDueDate: form.date
            )
        }
        await notifications.scheduleRecurringReminder(recurring)
    }

    func deleteRecurring(id: UUID) async throws {
        try await perform { try await $0.deleteRecurring(id: id) }
        notifications.cancelRecurringReminder(id: id)
    }

    /// Adds the due expense and moves the recurring one to its next date, which is returned.
    @discardableResult
    func addDueOccurrence(id: UUID) async throws -> RecurringExpenseDTO {
        let recurring = try await perform { try await $0.addDueOccurrence(id: id) }
        await notifications.scheduleRecurringReminder(recurring)
        return recurring
    }

    @discardableResult
    func skipDueOccurrence(id: UUID) async throws -> RecurringExpenseDTO {
        let recurring = try await perform { try await $0.skipDueOccurrence(id: id) }
        await notifications.scheduleRecurringReminder(recurring)
        return recurring
    }
}
