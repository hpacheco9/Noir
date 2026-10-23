//
//  RemovedOtherCategoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

// Rows go straight into a `ModelContext`: `repository.save` would write the overview memo to `UserDefaults.standard`.
struct RemovedOtherCategoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func insert(_ name: String, key: String, into context: ModelContext) {
        let row = Expense(amount: 5, name: name, date: .now, category: .food)
        row.categoryRawValue = key
        context.insert(row)
    }

    private func keysByName(_ container: ModelContainer) throws -> [String: String] {
        let rows = try ModelContext(container).fetch(FetchDescriptor<Expense>())
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.name, $0.categoryRawValue) })
    }

    @Test func otherIsNoLongerABuiltIn() {
        #expect(ExpenseCategory(rawValue: "other") == nil)
        #expect(!CategoryInfo.builtIns.contains { $0.key == "other" })
        #expect(ExpenseForm().category == ExpenseCategory.food.rawValue)
    }

    @Test func unknownKeysShowAsFood() {
        let row = Expense(amount: 5, name: "legacy", date: .now, category: .transport)
        row.categoryRawValue = "other"
        let index = Dictionary(uniqueKeysWithValues: CategoryInfo.builtIns.map { ($0.key, $0) })
        #expect(row.category == .food)
        #expect(ExpenseDTO(row, categories: index).categoryInfo.key == ExpenseCategory.food.rawValue)

        // Positive control: a key that still exists is not rewritten by the fallback.
        row.categoryRawValue = ExpenseCategory.transport.rawValue
        #expect(row.category == .transport)
        #expect(ExpenseDTO(row, categories: index).categoryInfo.key == ExpenseCategory.transport.rawValue)
    }

    @Test func deletingACustomCategoryMovesItsExpensesToFood() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let custom = CustomCategory(name: "Pets", symbol: AssetName.CategorySymbols.all[0], colorRawValue: "teal")
        context.insert(custom)
        insert("pet", key: CategoryInfo.key(forCustomID: custom.id), into: context)
        insert("bus", key: ExpenseCategory.transport.rawValue, into: context)
        try context.save()
        #expect(try keysByName(container)["pet"] == CategoryInfo.key(forCustomID: custom.id))

        let moved = try await ExpenseRepository(modelContainer: container).deleteCategory(id: custom.id)

        #expect(moved == 1)
        #expect(try keysByName(container) == ["pet": "food", "bus": "transport"])
    }

    // MARK: Cleanup

    @Test func cleanupMovesOtherRowsToFoodAndLeavesTheRest() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let customKey = CategoryInfo.key(forCustomID: UUID())
        insert("old 1", key: "other", into: context)
        insert("old 2", key: "other", into: context)
        insert("meal", key: "food", into: context)
        insert("bus", key: "transport", into: context)
        insert("pet", key: customKey, into: context)
        try context.save()
        #expect(try keysByName(container)["old 1"] == "other")

        let moved = try await ExpenseRepository(modelContainer: container).retireOtherCategory()

        #expect(moved == 2)
        #expect(try keysByName(container) == [
            "old 1": "food", "old 2": "food", "meal": "food", "bus": "transport", "pet": customKey,
        ])
    }

    @Test func cleanupDropsOnlyTheOtherOverride() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(BuiltInCategoryOverride(key: "other", name: "Misc"))
        context.insert(BuiltInCategoryOverride(key: "food", name: "Meals"))
        try context.save()
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<BuiltInCategoryOverride>()) == 2)

        try await ExpenseRepository(modelContainer: container).retireOtherCategory()

        let left = try ModelContext(container).fetch(FetchDescriptor<BuiltInCategoryOverride>())
        #expect(left.map(\.key) == ["food"])
        #expect(left.first?.name == "Meals")
    }

    @Test func cleanupOnAnEmptyStoreDoesNothing() async throws {
        let container = try makeContainer()
        let moved = try await ExpenseRepository(modelContainer: container).retireOtherCategory()
        #expect(moved == 0)
    }

    @Test func cleanupRunsOnlyOnce() async throws {
        let suite = "NOIRTests.otherRetired.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try makeContainer()
        let context = ModelContext(container)
        let provider = ExpenseRepositoryProvider(container: container)
        insert("first", key: "other", into: context)
        try context.save()

        #expect(!defaults.bool(forKey: ExpenseRepositoryProvider.otherRetiredKey))
        await provider.retireOtherCategoryOnce(defaults: defaults)
        #expect(try keysByName(container)["first"] == "food")
        #expect(defaults.bool(forKey: ExpenseRepositoryProvider.otherRetiredKey))

        // The flag stops a second pass, so this row is left alone...
        insert("second", key: "other", into: context)
        try context.save()
        await provider.retireOtherCategoryOnce(defaults: defaults)
        #expect(try keysByName(container)["second"] == "other")

        // ...and clearing it runs the cleanup again.
        defaults.removeObject(forKey: ExpenseRepositoryProvider.otherRetiredKey)
        await provider.retireOtherCategoryOnce(defaults: defaults)
        #expect(try keysByName(container)["second"] == "food")
    }
}
