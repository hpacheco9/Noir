//
//  OverviewSideRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // `overviewSide`: the latest rows and the empty-state check.
    // In-memory store, rows inserted straight into a `ModelContext`. Nested in the serialized
    // `CategoryBreakdownRepositoryTests` for the memo-generation check.
    @Suite
    struct OverviewSideRepositoryTests {
        private var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            calendar.firstWeekday = 2
            return calendar
        }

        private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }

        // A Thursday in mid-October 2026.
        private var now: Date { date(2026, 10, 15) }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func side(_ container: ModelContainer, latestLimit: Int = 5) async throws -> SideResult {
            try await ExpenseRepository(modelContainer: container)
                .overviewSide(now: now, latestLimit: latestLimit, calendar: calendar)
        }

        private func insert(_ rows: [(amount: Double, date: Date)], into container: ModelContainer) throws {
            let context = ModelContext(container)
            for (index, row) in rows.enumerated() {
                context.insert(Expense(amount: row.amount, name: "row \(index)", date: row.date, category: .food))
            }
            try context.save()
        }

        @Test func latestRowsAreNewestFirstAndLimited() async throws {
            let container = try makeContainer()
            try insert([
                (1, date(2026, 10, 1)), (2, date(2026, 10, 2)), (3, date(2026, 10, 3)), (4, date(2026, 10, 4)),
            ], into: container)

            let result = try await side(container, latestLimit: 3)
            #expect(result.latest.map(\.amount) == [4, 3, 2])
            #expect(result.hasAnyExpenses)
        }

        @Test func emptyStoreHasNothing() async throws {
            let result = try await side(try makeContainer())
            #expect(result.latest.isEmpty)
            #expect(!result.hasAnyExpenses)
        }

        // Home keeps one repository for its whole life, so a re-read must see edits made through another context.
        @Test func rereadSeesEditsMadeThroughAnotherContext() async throws {
            let container = try makeContainer()
            let writer = ModelContext(container)
            let edited = Expense(amount: 10, name: "edited", date: date(2026, 10, 3), category: .food)
            writer.insert(edited)
            try writer.save()

            let repository = ExpenseRepository(modelContainer: container)
            let first = try await repository.overviewSide(now: now, calendar: calendar)
            #expect(first.latest.first?.amount == 10)

            let editor = ModelContext(container)
            let id = edited.id
            let row = try #require(try editor.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })).first)
            row.amount = 25
            try editor.save()

            let second = try await repository.overviewSide(now: now, calendar: calendar)
            #expect(second.latest.first?.amount == 25)
        }

        @Test func overviewMemosAreLeftAlone() async throws {
            let container = try makeContainer()
            try insert([(10, date(2026, 10, 3)), (20, date(2026, 9, 3))], into: container)

            let memosBefore = SpendingPeriod.allCases.map { OverviewMemoStore.load($0) }
            let generationBefore = OverviewMemoStore.generation
            _ = try await side(container)
            #expect(SpendingPeriod.allCases.map { OverviewMemoStore.load($0) } == memosBefore)
            #expect(OverviewMemoStore.generation == generationBefore)
        }
    }
}
