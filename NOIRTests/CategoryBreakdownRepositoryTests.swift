//
//  CategoryBreakdownRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// In-memory store, rows inserted straight into a `ModelContext`: `repository.save` would write the overview memo
/// to `UserDefaults.standard`.
/// Serialized with the nested `OverviewYearAllTimeTests`: their writes move the global memo generation this suite checks.
@Suite(.serialized)
struct CategoryBreakdownRepositoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// "Now" is mid-October 2026.
    private var now: Date { date(2026, 10, 15) }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func breakdown(
        _ container: ModelContainer, period: SpendingPeriod
    ) async throws -> CategoryBreakdown {
        try await ExpenseRepository(modelContainer: container)
            .categoryBreakdown(period: period, now: now, calendar: calendar)
    }

    @Test func monthExcludesRowsOutsideTheWindowAndAllTimeIncludesThem() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 10, name: "in", date: date(2026, 10, 3), category: .food))
        context.insert(Expense(amount: 5, name: "in 2", date: date(2026, 10, 30), category: .food))
        context.insert(Expense(amount: 100, name: "before", date: date(2026, 9, 30), category: .food))
        context.insert(Expense(amount: 200, name: "next month", date: date(2026, 11, 1), category: .transport))
        context.insert(Expense(amount: 1000, name: "years ago", date: date(2019, 1, 1), category: .health))
        try context.save()

        let month = try await breakdown(container, period: .month)
        #expect(month.categories.map(\.info.key) == ["food"])
        #expect(month.total == 15)
        #expect(month.categories.first?.count == 2)

        // Truly all time: includes the 2019 row (not limited to any window).
        let all = try await breakdown(container, period: .allTime)
        #expect(all.total == 1315)
        #expect(all.categories.map(\.info.key) == ["health", "transport", "food"])
    }

    @Test func dayUsesItsOwnWindowAndMonthSpansIt() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 1, name: "today", date: date(2026, 10, 15), category: .food))
        context.insert(Expense(amount: 2, name: "yesterday", date: date(2026, 10, 14), category: .food))
        context.insert(Expense(amount: 4, name: "long ago", date: date(2026, 10, 1), category: .food))
        try context.save()

        #expect(try await breakdown(container, period: .day).total == 1)
        #expect(try await breakdown(container, period: .month).total == 7)
    }

    @Test func resolvesCustomCategoriesAndFallsBackToOther() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let custom = CustomCategory(name: "Pets", symbol: AssetName.CategorySymbols.all[0], colorRawValue: "teal")
        context.insert(custom)
        let petRow = Expense(amount: 30, name: "pet", date: date(2026, 10, 2), category: .other)
        petRow.categoryRawValue = CategoryInfo.key(forCustomID: custom.id)
        let orphan = Expense(amount: 8, name: "orphan", date: date(2026, 10, 2), category: .other)
        orphan.categoryRawValue = CategoryInfo.key(forCustomID: UUID())
        context.insert(petRow)
        context.insert(orphan)
        try context.save()

        let result = try await breakdown(container, period: .month)
        #expect(result.categories.map(\.info.key) == [CategoryInfo.key(forCustomID: custom.id), ExpenseCategory.other.rawValue])
        #expect(result.categories[0].info.customName == "Pets")
        #expect(result.categories[1].amount == 8)
    }

    @Test func emptyStoreGivesEmptyBreakdown() async throws {
        let result = try await breakdown(try makeContainer(), period: .allTime)
        #expect(result == .empty)
    }

    // MARK: Window boundaries

    @Test(arguments: [SpendingPeriod.day, .week, .month, .year])
    func windowStartIsIncludedAndEndIsExcluded(period: SpendingPeriod) async throws {
        let interval = try #require(period.dateInterval(calendar: calendar, now: now))
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 1, name: "just before", date: interval.start.addingTimeInterval(-1), category: .transport))
        context.insert(Expense(amount: 10, name: "start", date: interval.start, category: .food))
        context.insert(Expense(amount: 100, name: "last second", date: interval.end.addingTimeInterval(-1), category: .food))
        context.insert(Expense(amount: 1000, name: "end instant", date: interval.end, category: .health))
        try context.save()

        let result = try await breakdown(container, period: period)
        #expect(result.categories.map(\.info.key) == ["food"])
        #expect(result.total == 110)
        #expect(result.categories.first?.count == 2)
    }

    // MARK: Overview memo

    @Test func overviewMemoIsLeftAlone() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 10, name: "a", date: date(2026, 10, 3), category: .food))
        try context.save()

        let memosBefore = SpendingPeriod.allCases.map { OverviewMemoStore.load($0) }
        let generationBefore = OverviewMemoStore.generation
        for period in SpendingPeriod.allCases { _ = try await breakdown(container, period: period) }
        #expect(SpendingPeriod.allCases.map { OverviewMemoStore.load($0) } == memosBefore)
        #expect(OverviewMemoStore.generation == generationBefore)
    }

    // MARK: Freshness

    @Test func rereadSeesEditsMadeThroughAnotherContext() async throws {
        let container = try makeContainer()
        let writer = ModelContext(container)
        let expense = Expense(amount: 10, name: "a", date: date(2026, 10, 3), category: .food)
        writer.insert(expense)
        try writer.save()

        let repository = ExpenseRepository(modelContainer: container)
        let first = try await repository.categoryBreakdown(period: .month, now: now, calendar: calendar)
        #expect(first.categories.map(\.info.key) == ["food"])
        #expect(first.total == 10)

        // A separate context edits the amount and the category, then saves.
        let editor = ModelContext(container)
        let id = expense.id
        let row = try #require(try editor.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })).first)
        row.amount = 25
        row.categoryRawValue = ExpenseCategory.transport.rawValue
        try editor.save()

        let second = try await repository.categoryBreakdown(period: .month, now: now, calendar: calendar)
        #expect(second.categories.map(\.info.key) == ["transport"])
        #expect(second.total == 25)
    }
}
