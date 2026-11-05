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
            let context = ModelContext(container)
            context.insert(Expense(amount: 12.5, name: "Café Crème", date: date(2026, 3, 5, 23), category: .food))
            try context.save()

            let rows = [
                row("cafe creme", 12.5, date(2026, 3, 5, 1)),   // same day, other time, name differs by case/accents
                row("Café Crème", 12.5, date(2026, 3, 6, 1)),   // other day
                row("Café Crème", 12.51, date(2026, 3, 5)),     // other amount
                row("Café Latte", 12.5, date(2026, 3, 5)),      // other name
                row("CAFÉ CRÈME", 12.499999, date(2026, 3, 5)), // equal at minor units
                row("Café Crème", 12.5, date(2026, 3, 5)),      // exactly the same
            ]
            let found = try await ExpenseRepository(modelContainer: container)
                .duplicateIndices(in: rows, fractionDigits: 2, calendar: calendar)
            #expect(found == [0, 4, 5])
        }

        @Test func amountsAreComparedAtTheCurrencysMinorUnits() async throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            context.insert(Expense(amount: 100, name: "Ramen", date: date(2026, 3, 5), category: .food))
            try context.save()
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

        @Test func theSameRowsAreAllDuplicatesWhenTheyRepeatInTheFile() async throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            context.insert(Expense(amount: 3.5, name: "Coffee", date: date(2026, 3, 5), category: .food))
            try context.save()
            let found = try await ExpenseRepository(modelContainer: container)
                .duplicateIndices(in: [row(), row()], fractionDigits: 2, calendar: calendar)
            #expect(found == [0, 1])
        }

        // MARK: Import

        @Test func importInsertsRowsAndCreatesCategoriesInOneGo() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let before = Date.now

                let count = try await repository.importExpenses([
                    row("Lunch", 12.5, date(2026, 3, 1), category: .existing(key: "transport"), card: "Visa", note: "with Ana"),
                    row("Walk", 8, date(2026, 3, 2), category: .new(name: "Pets")),
                    row("Food", 20, date(2026, 3, 3), category: .new(name: "pets")),
                    row("Gym", 30, date(2026, 3, 4), category: .new(name: "Gym")),
                ], newCategories: ["Pets", "Gym"])
                let after = Date.now

                #expect(count == 4)
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

        @Test func unknownCategoriesGoToFood() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let missing = CategoryInfo.key(forCustomID: UUID())
                _ = try await ExpenseRepository(modelContainer: container).importExpenses([
                    row("a", category: .existing(key: missing)),
                    row("b", category: .new(name: "Not created")),
                    row("c", category: .existing(key: "health")),
                ], newCategories: [])

                let expenses = try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.name)]))
                // Control: a key that exists is kept.
                #expect(expenses.map(\.categoryRawValue) == ["food", "food", "health"])
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 0)
            }
        }

        @Test func cardsAreRememberedTrimmedAndBlankOnesAreNot() async throws {
            try await withIsolatedDefaults { suite in
                let container = try makeContainer()
                _ = try await ExpenseRepository(modelContainer: container).importExpenses(
                    [row("a", card: "Visa"), row("b", card: "  Amex "), row("c", card: ""), row("d", card: "Visa")],
                    newCategories: []
                )
                let remembered = UserDefaults(suiteName: suite)?.stringArray(forKey: SavedCards.storageKey) ?? []
                #expect(Set(remembered) == ["Visa", "Amex"])
            }
        }

        @Test func aBadRowImportsNothingNotEvenTheCategories() async throws {
            try await withIsolatedDefaults { _ in
                let container = try makeContainer()
                let repository = ExpenseRepository(modelContainer: container)
                let good = row("good", category: .new(name: "Pets"))

                await #expect(throws: RepositoryError.self) {
                    _ = try await repository.importExpenses([good, row("bad", 0)], newCategories: ["Pets"])
                }
                await #expect(throws: RepositoryError.self) {
                    _ = try await repository.importExpenses([good, row("worse", .nan)], newCategories: ["Pets"])
                }
                let context = ModelContext(container)
                #expect(try context.fetchCount(FetchDescriptor<Expense>()) == 0)
                #expect(try context.fetchCount(FetchDescriptor<CustomCategory>()) == 0)

                // Control: without the bad row the same import goes through.
                #expect(try await repository.importExpenses([good], newCategories: ["Pets"]) == 1)
                #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 1)
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

                _ = try await repository.importExpenses([row("a", 5.5, .now), row("b", 4.5, .now)], newCategories: [])

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
