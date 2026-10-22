//
//  StaleExpenseIDTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // Nested in the serialized suite because saves move the memo generation it checks.
    @Suite
    struct StaleExpenseIDTests {
        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func withIsolatedMemos(_ body: () async throws -> Void) async throws {
            let suite = "NOIRTests.staleID.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) { try await body() }
        }

        private func insert(_ name: String, amount: Double = 10, into container: ModelContainer) throws -> PersistentIdentifier {
            let context = ModelContext(container)
            let expense = Expense(amount: amount, name: name, date: .now, category: .food)
            context.insert(expense)
            try context.save()
            return expense.persistentModelID
        }

        private func deleteElsewhere(_ id: PersistentIdentifier, in container: ModelContainer) throws {
            let context = ModelContext(container)
            let rows = try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.persistentModelID == id }))
            context.delete(try #require(rows.first))
            try context.save()
        }

        private func save(_ name: String, amount: Double = 5, id: PersistentIdentifier?, to repository: ExpenseRepository) async throws {
            try await repository.save(
                id: id, amount: amount, name: name, date: .now,
                categoryKey: ExpenseCategory.food.rawValue, description: "", card: ""
            )
        }

        private func names(in container: ModelContainer) throws -> [String] {
            try ModelContext(container).fetch(FetchDescriptor<Expense>()).map(\.name).sorted()
        }

        // MARK: Row gone, never seen by the repository

        @Test func editOfADeletedRowThrowsNotFoundAndInsertsNothing() async throws {
            let container = try makeContainer()
            let id = try insert("gone", into: container)
            try deleteElsewhere(id, in: container)

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.notFound) {
                    try await save("edited", id: id, to: repository)
                }
                let stored = try names(in: container)
                #expect(stored.isEmpty)
            }
        }

        @Test func deleteOfADeletedRowThrowsNotFound() async throws {
            let container = try makeContainer()
            let id = try insert("gone", into: container)
            try deleteElsewhere(id, in: container)

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.notFound) {
                    try await repository.delete(id: id)
                }
            }
        }

        // MARK: Row gone after the repository already loaded it

        @Test func editOfARowDeletedAfterTheRepositoryLoadedItThrowsNotFound() async throws {
            let container = try makeContainer()
            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                try await save("first", id: nil, to: repository)
                let id = try #require(try ModelContext(container).fetch(FetchDescriptor<Expense>()).first?.persistentModelID)
                // The repository's own context now knows the row.
                try await save("second", id: id, to: repository)

                try deleteElsewhere(id, in: container)
                await #expect(throws: RepositoryError.notFound) {
                    try await save("third", id: id, to: repository)
                }
                let stored = try names(in: container)
                #expect(stored.isEmpty)
            }
        }

        @Test func deleteOfARowDeletedAfterTheRepositoryLoadedItThrowsNotFound() async throws {
            let container = try makeContainer()
            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                try await save("first", id: nil, to: repository)
                let id = try #require(try ModelContext(container).fetch(FetchDescriptor<Expense>()).first?.persistentModelID)
                try await save("second", id: id, to: repository)

                try deleteElsewhere(id, in: container)
                await #expect(throws: RepositoryError.notFound) {
                    try await repository.delete(id: id)
                }
            }
        }

        @Test func notFoundLeavesNoWriteInFlight() async throws {
            let container = try makeContainer()
            let id = try insert("gone", into: container)
            _ = try insert("kept", into: container)
            try deleteElsewhere(id, in: container)

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                await #expect(throws: RepositoryError.notFound) { try await repository.delete(id: id) }
                await #expect(throws: RepositoryError.notFound) { try await save("x", id: id, to: repository) }
                // A write left in flight would stop this load from saving its memo.
                _ = try await repository.overviewChart(period: .month)
                #expect(OverviewMemoStore.load(.month) != nil)
            }
        }

        // MARK: Existing rows

        @Test func editOfAnExistingRowStillWorks() async throws {
            let container = try makeContainer()
            let id = try insert("old", amount: 10, into: container)
            _ = try insert("other", into: container)

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                try await save("new", amount: 25, id: id, to: repository)

                let rows = try ModelContext(container).fetch(FetchDescriptor<Expense>())
                #expect(rows.map(\.name).sorted() == ["new", "other"])
                #expect(rows.first { $0.name == "new" }?.amount == 25)
            }
        }

        @Test func deleteOfAnExistingRowStillWorks() async throws {
            let container = try makeContainer()
            let id = try insert("doomed", into: container)
            _ = try insert("kept", into: container)

            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: container)
                try await repository.delete(id: id)
                let stored = try names(in: container)
                #expect(stored == ["kept"])
                // The row is gone for good: a second delete is a clean `notFound`, not a trap.
                await #expect(throws: RepositoryError.notFound) { try await repository.delete(id: id) }
            }
        }
    }
}
