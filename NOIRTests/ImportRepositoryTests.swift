//
//  ImportRepositoryTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // `duplicateIndices` and `importExpenses` on an in-memory store. Nested in the serialized
    // `CategoryBreakdownRepositoryTests`: an import moves the global memo generation that suite checks.
    @Suite
    struct ImportRepositoryTests {
        private struct Boom: Error {}

        private var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar
        }

        private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func row(
            _ name: String = "Coffee", _ amount: Double = 3.5, _ date: Date? = nil,
            category: ImportCategory = .existing(key: "food"), card: String = "", note: String = ""
        ) -> ImportRow {
            ImportRow(date: date ?? self.date(2026, 3, 5), name: name, amount: amount, category: category, card: card, note: note)
        }

        private func insert(_ expenses: [(String, Double, Date)], into container: ModelContainer) throws {
            let context = ModelContext(container)
            for (name, amount, date) in expenses {
                context.insert(Expense(amount: amount, name: name, date: date, category: .food))
            }
            try context.save()
        }

        @discardableResult
        private func run(
            _ rows: [ImportRow], in container: ModelContainer, create: Bool = true, skip: Bool = false, digits: Int = 2,
            beforeSave: @Sendable () throws -> Void = {}
        ) async throws -> ImportResult {
            try await ExpenseRepository(modelContainer: container).importExpenses(
                rows, createCategories: create, skipDuplicates: skip, fractionDigits: digits, calendar: calendar, beforeSave: beforeSave
            )
        }

        private func withIsolatedDefaults(_ body: (String) async throws -> Void) async throws {
            let suite = "NOIRTests.import.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }
            try await OverviewMemoStore.$suiteName.withValue(suite) {
                try await SavedCards.$suiteName.withValue(suite) { try await body(suite) }
            }
        }

        // MARK: Duplicates

        @Test func aDuplicateIsTheSameDayAmountAndNameIgnoringCaseAndAccents() async throws {
            let container = try makeContainer()
            try insert([("Café Crème", 12.5, date(2026, 3, 5, 23))], into: container)

            let rows = [
                row("cafe creme", 12.5, date(2026, 3, 5, 1)),   // same day, other time, name differs by case/accents
                row("Café Crème", 12.5, date(2026, 3, 6, 1)),   // other day
                row("Café Crème", 12.51, date(2026, 3, 5)),     // other amount
                row("Café Latte", 12.5, date(2026, 3, 5)),      // other name
                row("CAFÉ CRÈME", 12.499999, date(2026, 3, 5)), // equal at minor units
            ]
            let found = try await ExpenseRepository(modelContainer: container)
                .duplicateIndices(in: rows, fractionDigits: 2, calendar: calendar)
            // One existing expense absorbs one row: the first of the two that match.
            #expect(found == [0])
            // Control: the last row alone does match, so only the absorbing made it a new one above.
            #expect(try await ExpenseRepository(modelContainer: container)
                .duplicateIndices(in: [rows[4]], fractionDigits: 2, calendar: calendar) == [0])
        }

        @Test func amountsAreComparedAtTheCurrencysMinorUnits() async throws {
            let container = try makeContainer()
            try insert([("Ramen", 100, date(2026, 3, 5))], into: container)
            let repository = ExpenseRepository(modelContainer: container)
            let rows = [row("Ramen", 100.4)]

            #expect(try await repository.duplicateIndices(in: rows, fractionDigits: 0, calendar: calendar) == [0])
            // Control: with cents the same two amounts differ.
            #expect(try await repository.duplicateIndices(in: rows, fractionDigits: 2, calendar: calendar).isEmpty)
        }

        @Test func noRowsAndAnEmptyStoreHaveNoDuplicates() async throws {
            let repository = ExpenseRepository(modelContainer: try makeContainer())
            #expect(try await repository.duplicateIndices(in: [], fractionDigits: 2, calendar: calendar).isEmpty)
            #expect(try await repository.duplicateIndices(in: [row()], fractionDigits: 2, calendar: calendar).isEmpty)
        }

        @Test func eachExistingExpenseAbsorbsOnlyOneIdenticalRow() async throws {
            let container = try makeContainer()
            let repository = ExpenseRepository(modelContainer: container)
            let twins = [row(), row(), row()]

            try insert([("Coffee", 3.5, date(2026, 3, 5))], into: container)
            #expect(try await repository.duplicateIndices(in: twins, fractionDigits: 2, calendar: calendar) == [0])

            try insert([("Coffee", 3.5, date(2026, 3, 5, 9))], into: container)
            #expect(try await repository.duplicateIndices(in: twins, fractionDigits: 2, calendar: calendar) == [0, 1])
        }

        // MARK: Import

        @Test func importInsertsRowsAndCreatesCategoriesInOneGo() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let before = Date.now

                let result = try await run([
                    row("Lunch", 12.5, date(2026, 3, 1), category: .existing(key: "transport"), card: "Visa", note: "with Ana"),
                    row("Walk", 8, date(2026, 3, 2), category: .new(name: "Pets")),
                    row("Food", 20, date(2026, 3, 3), category: .new(name: "pets")),
                    row("Gym", 30, date(2026, 3, 4), category: .new(name: "Gym")),
                ], in: container)
                let after = Date.now

                #expect(result == ImportResult(imported: 4, duplicates: 0, categoriesCreated: 2))
                let context = ModelContext(container)
                let categories = try context.fetch(FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.createdAt)]))
                #expect(Set(categories.map(\.name)) == ["Pets", "Gym"])
                #expect(categories.allSatisfy { $0.symbol == AssetName.CategorySymbols.generic })
                #expect(Set(categories.map(\.colorRawValue)).count == 2)

                let pets = try #require(categories.first { $0.name == "Pets" })
                let gym = try #require(categories.first { $0.name == "Gym" })
                let expenses = try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))
                #expect(expenses.map(\.name) == ["Lunch", "Walk", "Food", "Gym"])
                #expect(expenses.map(\.categoryRawValue) == [
                    "transport", CategoryInfo.key(forCustomID: pets.id), CategoryInfo.key(forCustomID: pets.id),
                    CategoryInfo.key(forCustomID: gym.id),
                ])
                let lunch = expenses[0]
                #expect(lunch.amount == 12.5)
                #expect(lunch.card == "Visa")
                #expect(lunch.expenseDescription == "with Ana")
                #expect(lunch.date == date(2026, 3, 1))
                #expect(expenses.allSatisfy { $0.createdAt >= before && $0.createdAt <= after })
            }
        }

        @Test func duplicatesAreSkippedInTheSameCallAndCounted() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                try insert([("Coffee", 3.5, date(2026, 3, 5))], into: container)
                let rows = [row(), row("Tea", 2)]

                let skipping = try await run(rows, in: container, skip: true)
                #expect(skipping == ImportResult(imported: 1, duplicates: 1, categoriesCreated: 0))
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 2)

                // Control: with the check off the same rows are all inserted.
                let keeping = try await run(rows, in: container, skip: false)
                #expect(keeping.imported == 2 && keeping.duplicates == 0)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 4)
            }
        }

        @Test func aNewCategoryOnlyDuplicatesNeedIsNotCreated() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                try insert([("Gym", 30, date(2026, 3, 5))], into: container)

                let result = try await run([row("Gym", 30, category: .new(name: "Fitness"))], in: container, skip: true)

                #expect(result == ImportResult(imported: 0, duplicates: 1, categoriesCreated: 0))
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 0)
            }
        }

        @Test func aNewNameThatMatchesAnExistingCategoryReusesIt() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let context = ModelContext(container)
                let fitness = CustomCategory(name: "Fitness", symbol: "dumbbell.fill", colorRawValue: "red")
                context.insert(fitness)
                context.insert(BuiltInCategoryOverride(key: "health", name: "Doctor"))
                try context.save()

                let result = try await run([
                    row("a", category: .new(name: "FITNESS")),
                    row("b", category: .new(name: "doctor")),
                    row("c", category: .new(name: "Hobbies")),
                ], in: container)

                #expect(result.categoriesCreated == 1)
                let expenses = try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.name)]))
                #expect(expenses[0].categoryRawValue == CategoryInfo.key(forCustomID: fitness.id))
                #expect(expenses[1].categoryRawValue == "health")
                let hobbies = try #require(try ModelContext(container).fetch(FetchDescriptor<CustomCategory>(predicate: #Predicate { $0.name == "Hobbies" })).first)
                #expect(expenses[2].categoryRawValue == CategoryInfo.key(forCustomID: hobbies.id))
                // Control: the two matches did not add a second Fitness.
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 2)
            }
        }

        @Test func longNamesAreCutAfterTheyAreToldApart() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let limit = CategoryFormViewModel.maxNameLength
                let stem = String(repeating: "x", count: limit)

                let result = try await run([
                    row("a", category: .new(name: stem + "-one")),
                    row("b", category: .new(name: stem + "-one")),
                    row("c", category: .new(name: stem + "-two")),
                ], in: container)

                // The two long names differ, but both are called the same once cut: one category serves them.
                #expect(result.categoriesCreated == 1)
                let categories = try ModelContext(container).fetch(FetchDescriptor<CustomCategory>())
                #expect(categories.map(\.name) == [stem])
                let keys = Set(try ModelContext(container).fetch(FetchDescriptor<Expense>()).map(\.categoryRawValue))
                #expect(keys == [CategoryInfo.key(forCustomID: categories[0].id)])
            }
        }

        @Test func unknownCategoriesGoToFood() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let missing = CategoryInfo.key(forCustomID: UUID())
                try await run([
                    row("a", category: .existing(key: missing)),
                    row("b", category: .new(name: "Not created")),
                    row("c", category: .existing(key: "health")),
                ], in: container, create: false)

                let expenses = try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.name)]))
                // Control: a key that exists is kept.
                #expect(expenses.map(\.categoryRawValue) == ["food", "food", "health"])
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 0)
            }
        }

        @Test func cardsAreRememberedTrimmedAndBlankOnesAreNot() async throws {
            try await withIsolatedDefaults { suite in
                let container = try makeContainer()
                try await run(
                    [row("a", card: "Visa"), row("b", card: "  Amex "), row("c", card: ""), row("d", card: "Visa")],
                    in: container
                )
                let remembered = UserDefaults(suiteName: suite)?.stringArray(forKey: SavedCards.storageKey) ?? []
                #expect(Set(remembered) == ["Visa", "Amex"])
            }
        }

        // MARK: Failures

        @Test func aRowWithABadAmountIsRejectedBeforeAnythingIsWritten() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let good = row("good", category: .new(name: "Pets"))

                await #expect(throws: RepositoryError.self) { try await run([good, row("bad", 0)], in: container) }
                await #expect(throws: RepositoryError.self) { try await run([good, row("worse", .nan)], in: container) }
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 0)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 0)

                // Control: without the bad row the same import goes through.
                #expect(try await run([good], in: container).imported == 1)
            }
        }

        @Test func aFailureAfterTheInsertsLeavesNothingBehindForARetryToSaveTwice() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                // One repository for both attempts, like the app's: pending inserts would live on in its context.
                let repository = ExpenseRepository(modelContainer: container)
                let rows = [row("a", category: .new(name: "Pets")), row("b"), row("c")]

                await #expect(throws: Boom.self) {
                    try await repository.importExpenses(
                        rows, createCategories: true, skipDuplicates: false, fractionDigits: 2,
                        calendar: calendar, beforeSave: { throw Boom() }
                    )
                }
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 0)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 0)

                let retry = try await repository.importExpenses(
                    rows, createCategories: true, skipDuplicates: false, fractionDigits: 2, calendar: calendar
                )
                #expect(retry.imported == 3)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 3)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 1)
            }
        }

        // MARK: Overview memo

        @Test func theOverviewMemoCountsImportedRowsOnItsNextLoad() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                try await repository.save(
                    id: nil, amount: 10, name: "existing", date: .now,
                    categoryKey: "food", description: "", card: ""
                )
                let first = try await repository.overviewChart(period: .month, now: .now, calendar: .current)
                #expect(first.total == 10)
                let memo = try #require(OverviewMemoStore.load(.month))
                #expect(memo.total == 10)

                try await run([row("a", 5.5, .now), row("b", 4.5, .now)], in: container)

                // The memo is not touched by the import; the new rows sit past its watermark and arrive by delta.
                #expect(OverviewMemoStore.load(.month)?.total == 10)
                let created = try ModelContext(container).fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.name != "existing" }))
                #expect(created.count == 2)
                #expect(created.allSatisfy { $0.createdAt > memo.watermark })

                let second = try await repository.overviewChart(period: .month, now: .now, calendar: .current)
                #expect(second.total == 20)
                #expect(OverviewMemoStore.load(.month)?.total == 20)

                // Control: loading again without an import changes nothing.
                #expect(try await repository.overviewChart(period: .month, now: .now, calendar: .current).total == 20)
            }
        }
    }
}
