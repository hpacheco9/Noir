//
//  ExpenseAmountTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

struct ExpenseAmountTests {
    nonisolated static let rejected: [Double] = [
        .infinity, -.infinity, .nan, 0, -1, 1e300, Expense.maxAmount.nextUp, 2 * Expense.maxAmount,
    ]
    nonisolated static let accepted: [Double] = [0.01, 19.99, 1234.56, Expense.maxAmount]

    @Test(arguments: rejected)
    func rejectsUnusableAmounts(amount: Double) {
        #expect(!Expense.isValidAmount(amount))
    }

    @Test(arguments: accepted)
    func acceptsNormalAmountsAndExactlyTheMax(amount: Double) {
        #expect(Expense.isValidAmount(amount))
    }

    @Test(arguments: [
        (Decimal(0), false), (Decimal(string: "19.99")!, true),
        (Decimal(Expense.maxAmount), true), (Decimal(Expense.maxAmount) + Decimal(string: "0.01")!, false),
    ])
    func formOnlyOffersSaveForAmountsTheStoreAccepts(amount: Decimal, canSave: Bool) {
        #expect(ExpenseForm(amount: amount, name: "Coffee").canSave == canSave)
    }

    @Test(arguments: rejected)
    @MainActor func intentRejectsUnusableAmounts(amount: Double) async {
        let intent = AddExpenseIntent()
        intent.amount = amount
        // Empty name: a regression past the amount guard stops at `emptyName` instead of writing to the real store.
        intent.name = ""
        await #expect(throws: AddExpenseIntentError.invalidAmount) { _ = try await intent.perform() }
    }
}

extension CategoryBreakdownRepositoryTests {
    /// Writes through `repository.save` with memos in an isolated suite. Nested in the serialized suite because
    /// saves move the memo generation it checks.
    @Suite
    struct SaveAmountGuardTests {
        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func withIsolatedMemos(_ body: () async throws -> Void) async throws {
            let suite = "NOIRTests.amount.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) { try await body() }
        }

        private func save(_ amount: Double, id: PersistentIdentifier?, to repository: ExpenseRepository) async throws {
            try await repository.save(
                id: id, amount: amount, name: "e", date: .now,
                categoryKey: ExpenseCategory.food.rawValue, description: "", card: ""
            )
        }

        @Test(arguments: [Double.infinity, Expense.maxAmount.nextUp])
        func insertRejectsUnusableAmountsAndStoresNothing(amount: Double) async throws {
            let container = try makeContainer()
            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.invalidAmount) {
                    try await save(amount, id: nil, to: repository)
                }
                let stored = try ModelContext(container).fetchCount(FetchDescriptor<Expense>())
                #expect(stored == 0)
            }
        }

        @Test(arguments: [Double.infinity, Expense.maxAmount.nextUp])
        func editRejectsUnusableAmountsAndKeepsTheRow(amount: Double) async throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            context.insert(Expense(amount: 10, name: "e", date: .now, category: .food))
            try context.save()
            let id = try #require(try context.fetch(FetchDescriptor<Expense>()).first).persistentModelID

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.invalidAmount) {
                    try await save(amount, id: id, to: repository)
                }
                let amounts = try ModelContext(container).fetch(FetchDescriptor<Expense>()).map(\.amount)
                #expect(amounts == [10])
            }
        }

        @Test(arguments: ExpenseAmountTests.accepted)
        func insertStoresNormalAmountsAndExactlyTheMax(amount: Double) async throws {
            let container = try makeContainer()
            try await withIsolatedMemos {
                try await save(amount, id: nil, to: ExpenseRepository(modelContainer: container))
                let amounts = try ModelContext(container).fetch(FetchDescriptor<Expense>()).map(\.amount)
                #expect(amounts == [amount])
            }
        }
    }
}
