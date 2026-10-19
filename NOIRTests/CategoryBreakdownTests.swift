//
//  CategoryBreakdownTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct CategoryBreakdownTests {
    private let index: [String: CategoryInfo] = Dictionary(
        uniqueKeysWithValues: ExpenseCategory.allCases.map { ($0.rawValue, CategoryInfo(builtIn: $0)) }
    )

    private func make(_ rows: [(String, Double)]) -> CategoryBreakdown {
        CategoryBreakdown.make(rows: rows.map { (key: $0.0, amount: $0.1) }, categories: index)
    }

    @Test func emptyRowsGiveEmptyBreakdown() {
        let result = make([])
        #expect(result.total == 0)
        #expect(result.categories.isEmpty)
    }

    @Test func sumsAndCountsPerKey() {
        let result = make([("food", 10), ("transport", 5), ("food", 2.5)])
        #expect(result.categories.map(\.info.key) == ["food", "transport"])
        #expect(result.categories[0].amount == Decimal(string: "12.5"))
        #expect(result.categories[0].count == 2)
        #expect(result.categories[1].amount == 5)
        #expect(result.total == Decimal(string: "17.5"))
    }

    @Test func unknownKeysCountAsOther() {
        let result = make([("custom:\(UUID().uuidString)", 7), ("nonsense", 3), ("other", 1)])
        #expect(result.categories.count == 1)
        #expect(result.categories[0].info.key == ExpenseCategory.other.rawValue)
        #expect(result.categories[0].amount == 11)
        #expect(result.categories[0].count == 3)
    }

    @Test func nonPositiveTotalsAreDropped() {
        // food nets to zero, transport is negative, health stays.
        let result = make([("food", 5), ("food", -5), ("transport", -3), ("health", 2)])
        #expect(result.categories.map(\.info.key) == ["health"])
        #expect(result.total == 2)
    }

    @Test func sortedByAmountDescending() {
        let result = make([("food", 1), ("health", 9), ("home", 5)])
        #expect(result.categories.map(\.info.key) == ["health", "home", "food"])
    }

    @Test func tiesBreakByKey() {
        let result = make([("home", 4), ("food", 4), ("health", 4)])
        #expect(result.categories.map(\.info.key) == ["food", "health", "home"])
    }

    @Test func totalIsTheSumOfTheKeptCategories() {
        let result = make([("food", 3), ("transport", 4), ("health", -9)])
        #expect(result.total == result.categories.reduce(0) { $0 + $1.amount })
        #expect(result.total == 7)
    }
}
