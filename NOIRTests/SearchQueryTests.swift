//
//  SearchQueryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

struct SearchQueryTests {
    private func makeRepository() throws -> ExpenseRepository {
        let container = try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(Expense(amount: 10, name: "Coffee", date: .now, category: .food, card: "Visa"))
        context.insert(Expense(amount: 20, name: "Taxi", date: .now, category: .transport, card: "Amex"))
        context.insert(Expense(amount: 30, name: "Groceries", date: .now, category: .food))
        try context.save()
        return ExpenseRepository(modelContainer: container)
    }

    private func names(_ query: String) async throws -> Set<String> {
        Set(try await makeRepository().fetchPage(query: query, offset: 0, limit: 50).map(\.name))
    }

    @Test func matchesTheName() async throws {
        #expect(try await names("taxi") == ["Taxi"])
    }

    @Test func matchesTheCard() async throws {
        #expect(try await names("amex") == ["Taxi"])
    }

    @Test func matchesTheCategoryTitle() async throws {
        let food = ExpenseCategory.food.title
        #expect(try await names(food) == ["Coffee", "Groceries"])
    }

    @Test func noMatchFindsNothing() async throws {
        #expect(try await names("zzz").isEmpty)
    }
}
