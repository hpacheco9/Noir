//
//  OverviewYearAllTimeTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    /// `overviewChart` for Year and All time on an in-memory store, writes through `repository.save`/`delete` so the
    /// memo adjust path runs. Memos go to an isolated suite (`OverviewMemoStore.$suiteName`).
    ///
    /// Uses `Calendar.current` and the real `now`: `save` adjusts memos with `.current`, and a memo whose watermark is
    /// after `now` is always recomputed, which would skip the DELTA path under test. Dates are relative to this year.
    /// Nested in the serialized `CategoryBreakdownRepositoryTests`, which checks that the memo generation stays put.
    @Suite
    struct OverviewYearAllTimeTests {
        private let calendar = Calendar.current
        private let year = Calendar.current.component(.year, from: .now)

        private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        /// Runs `body` with memos in a fresh suite, removed afterwards.
        private func withIsolatedMemos(_ body: () async throws -> Void) async throws {
            let suite = "NOIRTests.overview.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                #expect(OverviewMemoStore.load(.allTime) == nil)
                try await body()
            }
        }

        private func add(_ amount: Double, on date: Date, named name: String = "e", to repository: ExpenseRepository) async throws {
            try await repository.save(
                id: nil, amount: amount, name: name, date: date,
                categoryKey: ExpenseCategory.food.rawValue, description: ""
            )
        }

        private func id(named name: String, in container: ModelContainer) throws -> PersistentIdentifier {
            let rows = try ModelContext(container).fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.name == name }))
            return try #require(rows.first).persistentModelID
        }

        private func chart(_ period: SpendingPeriod, _ repository: ExpenseRepository) async throws -> ChartResult {
            try await repository.overviewChart(period: period, now: .now, calendar: calendar)
        }

        // MARK: All time

        @Test func allTimeFollowsTheEarliestExpense() async throws {
            try await withIsolatedMemos {
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                try await add(10, on: date(year - 1, 5, 1), to: repository)
                try await add(20, on: date(year, 2, 1), to: repository)
                // Positive control for the window's end: next year is not counted.
                try await add(1000, on: date(year + 1, 1, 2), to: repository)

                var result = try await chart(.allTime, repository)
                #expect(result.total == 30)
                #expect(result.points.map(\.amount) == [10, 20])
                #expect(OverviewMemoStore.load(.allTime)?.windowStart == date(year - 1, 1, 1, 0))

                // DELTA: same window, the new row arrives through the watermark.
                let memoBefore = try #require(OverviewMemoStore.load(.allTime))
                try await add(5, on: date(year, 3, 1), named: "march", to: repository)
                result = try await chart(.allTime, repository)
                #expect(result.total == 35)
                #expect(result.points.map(\.amount) == [10, 25])
                let memoAfter = try #require(OverviewMemoStore.load(.allTime))
                #expect(memoAfter.windowStart == memoBefore.windowStart)
                #expect(memoAfter.watermark > memoBefore.watermark)

                // An insert older than the earliest expense widens the window.
                try await add(100, on: date(year - 3, 7, 1), named: "old", to: repository)
                result = try await chart(.allTime, repository)
                #expect(result.total == 135)
                #expect(result.points.map(\.amount) == [100, 0, 10, 25])
                #expect(OverviewMemoStore.load(.allTime)?.windowStart == date(year - 3, 1, 1, 0))

                // An edit moving it even earlier, then an in-window edit (memo adjusted in place, kept).
                try await repository.save(
                    id: try id(named: "old", in: container), amount: 100, name: "old", date: date(year - 5, 1, 1),
                    categoryKey: ExpenseCategory.food.rawValue, description: ""
                )
                result = try await chart(.allTime, repository)
                #expect(result.total == 135)
                #expect(result.points.map(\.amount) == [100, 0, 0, 0, 10, 25])

                try await repository.save(
                    id: try id(named: "march", in: container), amount: 5, name: "march", date: date(year - 4, 3, 1),
                    categoryKey: ExpenseCategory.food.rawValue, description: ""
                )
                #expect(OverviewMemoStore.load(.allTime)?.total == 135)
                result = try await chart(.allTime, repository)
                #expect(result.points.map(\.amount) == [100, 5, 0, 0, 10, 20])

                // Deleting the oldest row shrinks the window again.
                try await repository.delete(id: try id(named: "old", in: container))
                result = try await chart(.allTime, repository)
                #expect(result.total == 35)
                #expect(result.points.map(\.amount) == [5, 0, 0, 10, 20])
            }
        }

        @Test func allTimeWithoutExpensesIsTheCurrentYearAtZero() async throws {
            try await withIsolatedMemos {
                let repository = ExpenseRepository(modelContainer: try makeContainer())
                let result = try await chart(.allTime, repository)
                #expect(result.total == 0)
                #expect(result.points.map(\.amount) == [0])
            }
        }

        // MARK: Year

        @Test func yearCountsOnlyThisCalendarYearByMonth() async throws {
            try await withIsolatedMemos {
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                try await add(10, on: date(year, 1, 1, 0), to: repository)
                try await add(20, on: date(year, 12, 31, 23), to: repository)
                // Positive controls: both neighbouring years are left out.
                try await add(1000, on: date(year - 1, 12, 31, 23), to: repository)
                try await add(1000, on: date(year + 1, 1, 1, 0), to: repository)

                var result = try await chart(.year, repository)
                #expect(result.total == 30)
                #expect(result.points.count == 12)
                #expect(result.points.first?.amount == 10)
                #expect(result.points.last?.amount == 20)

                // An insert in an earlier year than every other expense: All time shows it, Year does not.
                try await add(7, on: date(year - 6, 6, 1), to: repository)
                result = try await chart(.year, repository)
                #expect(result.total == 30)
                let all = try await chart(.allTime, repository)
                #expect(all.total == 1037)
                #expect(all.points.first?.amount == 7)
                #expect(all.points.count == 7)
            }
        }
    }
}
