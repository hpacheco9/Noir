//
//  ExpenseRepositoryProvider.swift
//  NOIR
//

import Foundation
import SwiftData

final class ExpenseRepositoryProvider: Sendable {
    private let creation: Task<ExpenseRepository, Never>

    init(container: ModelContainer) {
        creation = Task.detached(priority: .userInitiated) {
            ExpenseRepository(modelContainer: container)
        }
    }
    @concurrent
    func perform<T: Sendable>(_ body: @Sendable (ExpenseRepository) async throws -> T) async rethrows -> T {
        let repository = await creation.value
        return try await body(repository)
    }
}

extension ExpenseRepositoryProvider {
    /// Inserts (`id == nil`) or updates an expense with the form's values.
    func save(_ form: ExpenseForm, id: PersistentIdentifier?) async throws {
        try await perform {
            try await $0.save(
                id: id,
                amount: form.amountValue,
                name: form.name,
                date: form.date,
                categoryKey: form.category,
                description: form.description,
                card: form.card
            )
        }
    }
}
