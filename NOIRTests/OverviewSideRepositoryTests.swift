//
//  OverviewSideRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    /// `overviewSide`: the previous period's total (the Home comparison) and this month's total (the budget).
    /// In-memory store, rows inserted straight into a `ModelContext`. Nested in the serialized
    /// `CategoryBreakdownRepositoryTests` for the memo-generation check.
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

        /// A Thursday in mid-October 2026.
        private var now: Date { date(2026, 10, 15) }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func side(_ container: ModelContainer, _ period: SpendingPeriod, latestLimit: Int = 5) async throws -> SideResult {
            try await ExpenseRepository(modelContainer: container)
                .overviewSide(period: period, now: now, latestLimit: latestLimit, calendar: calendar)
        }

        private func insert(_ rows: [(amount: Double, date: Date)], into container: ModelContainer) throws {
            let context = ModelContext(container)
            for (index, row) in rows.enumerated() {
                context.insert(Expense(amount: row.amount, name: "row \(index)", date: row.date, category: .food))
            }
            try context.save()
        }

        // MARK: Previous period

        @Test(arguments: [SpendingPeriod.day, .week, .month, .year])
        func previousTotalCoversExactlyThePreviousPeriod(period: SpendingPeriod) async throws {
            let previous = try #require(period.previousInterval(calendar: calendar, now: now))
            let current = try #require(period.dateInterval(calendar: calendar, now: now))
            let container = try makeContainer()
            try insert([
                (1, previous.start.addingTimeInterval(-1)),
                (10, previous.start),
                (100, previous.end.addingTimeInterval(-1)),
                (1000, current.start),
                (10_000, current.end.addingTimeInterval(-1)),
            ], into: container)

            let result = try await side(container, period)
            #expect(result.previousTotal == 110)
        }

        @Test func allTimeHasNoPreviousTotal() async throws {
            let container = try makeContainer()
            try insert([(10, date(2026, 10, 3)), (20, date(2025, 1, 1))], into: container)
            #expect(try await side(container, .allTime).previousTotal == nil)
        }

        @Test func aPreviousPeriodWithoutSpendingTotalsZero() async throws {
            let container = try makeContainer()
            try insert([(10, date(2026, 10, 15))], into: container)
            let result = try await side(container, .day)
            #expect(result.previousTotal == 0)
            #expect(PeriodComparison.make(current: 10, previous: result.previousTotal) == nil)
        }

        // MARK: This month

        @Test(arguments: SpendingPeriod.allCases)
        func monthTotalIsTheCurrentMonthWhateverThePeriod(period: SpendingPeriod) async throws {
            let container = try makeContainer()
            try insert([
                (10, date(2026, 10, 1, 0)),
                (5, date(2026, 10, 31, 23)),
                (100, date(2026, 9, 30, 23)),
                (1000, date(2026, 11, 1, 0)),
                (10_000, date(2025, 10, 15)),
            ], into: container)

            #expect(try await side(container, period).monthTotal == 15)
        }

        // MARK: The rest of the side load

        @Test func latestRowsAreNewestFirstAndLimited() async throws {
            let container = try makeContainer()
            try insert([
                (1, date(2026, 10, 1)), (2, date(2026, 10, 2)), (3, date(2026, 10, 3)), (4, date(2026, 10, 4)),
            ], into: container)

            let result = try await side(container, .month, latestLimit: 3)
            #expect(result.latest.map(\.amount) == [4, 3, 2])
            #expect(result.hasAnyExpenses)
        }

        @Test func emptyStoreHasNothingAndZeroTotals() async throws {
            let result = try await side(try makeContainer(), .week)
            #expect(result.latest.isEmpty)
            #expect(!result.hasAnyExpenses)
            #expect(result.previousTotal == 0)
            #expect(result.monthTotal == 0)
        }

        /// Home keeps one repository for its whole life, so a re-read must see edits made through another context.
        @Test func rereadSeesEditsMadeThroughAnotherContext() async throws {
            let container = try makeContainer()
            let writer = ModelContext(container)
            let edited = Expense(amount: 10, name: "edited", date: date(2026, 10, 3), category: .food)
            writer.insert(edited)
            writer.insert(Expense(amount: 5, name: "last month", date: date(2026, 9, 3), category: .food))
            try writer.save()

            let repository = ExpenseRepository(modelContainer: container)
            let first = try await repository.overviewSide(period: .month, now: now, calendar: calendar)
            #expect(first.monthTotal == 10)
            #expect(first.previousTotal == 5)

            let editor = ModelContext(container)
            let id = edited.id
            let row = try #require(try editor.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })).first)
            row.amount = 25
            try editor.save()

            let second = try await repository.overviewSide(period: .month, now: now, calendar: calendar)
            #expect(second.monthTotal == 25)
            #expect(second.latest.first?.amount == 25)
        }

        @Test func overviewMemosAreLeftAlone() async throws {
            let container = try makeContainer()
            try insert([(10, date(2026, 10, 3)), (20, date(2026, 9, 3))], into: container)

            let memosBefore = SpendingPeriod.allCases.map { OverviewMemoStore.load($0) }
            let generationBefore = OverviewMemoStore.generation
            for period in SpendingPeriod.allCases { _ = try await side(container, period) }
            #expect(SpendingPeriod.allCases.map { OverviewMemoStore.load($0) } == memosBefore)
            #expect(OverviewMemoStore.generation == generationBefore)
        }
    }
}
