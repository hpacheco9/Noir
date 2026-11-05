//
//  ImportReviewViewModelTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // The review sheet's logic over an in-memory store. Nested in the serialized `CategoryBreakdownRepositoryTests`:
    // an import moves the global memo generation that suite checks.
    @Suite
    struct ImportReviewViewModelTests {
        private let utc = TimeZone(secondsFromGMT: 0)!

        private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = utc
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }

        private func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        private func insert(_ name: String, _ amount: Double, _ date: Date, into container: ModelContainer) throws {
            let context = ModelContext(container)
            context.insert(Expense(amount: amount, name: name, date: date, category: .food))
            try context.save()
        }

        private func makeViewModel(
            _ text: String, container: ModelContainer, currency: String = "EUR",
            afterImport: @escaping () async -> Void = {}
        ) throws -> ImportReviewViewModel {
            let parsed = try ExpenseCSVReader.parse(text: text, currencyCode: currency, timeZone: utc)
            return ImportReviewViewModel(
                parsed: parsed, currencyCode: currency,
                repository: ExpenseRepositoryProvider(container: container), afterImport: afterImport
            )
        }

        private let file = """
        Date,Name,Amount,Category
        2026-03-05,Coffee,3.5,Food
        2026-03-06,Gym,40,Fitness
        2026-03-07,Tea,2,Fitness
        2026-03-08,Broken,xyz,Food
        """

        private final class Recorder {
            var expenses = 0
            var categories = 0
            var published = 0
        }

        private func recording(from viewModel: ImportReviewViewModel, _ recorder: Recorder, _ body: () async throws -> Void) async rethrows {
            let expenses = NotificationCenter.default.addObserver(forName: .expensesDidChange, object: viewModel, queue: nil) { _ in
                MainActor.assumeIsolated { recorder.expenses += 1 }
            }
            let categories = NotificationCenter.default.addObserver(forName: .categoriesDidChange, object: viewModel, queue: nil) { _ in
                MainActor.assumeIsolated { recorder.categories += 1 }
            }
            defer {
                NotificationCenter.default.removeObserver(expenses)
                NotificationCenter.default.removeObserver(categories)
            }
            try await body()
        }

        // MARK: Review

        @Test func loadCountsRowsInvalidRowsDuplicatesAndNewCategories() async throws {
            let container = try makeContainer()
            try insert("coffee", 3.5, noon(2026, 3, 5), into: container)
            let viewModel = try makeViewModel(file, container: container)
            #expect(viewModel.isLoading)

            await viewModel.load()

            #expect(!viewModel.isLoading)
            #expect(viewModel.rows.count == 3)
            #expect(viewModel.invalid == [.init(line: 5, reason: .amount)])
            #expect(viewModel.duplicateCount == 1)
            #expect(viewModel.newCategoryNames == ["Fitness"])
            #expect(viewModel.importCount == 2)
            #expect(viewModel.canImport)

            viewModel.skipsDuplicates = false
            #expect(viewModel.importCount == 3)
        }

        @Test func aFileWithNothingToImportCannotBeImported() async throws {
            let container = try makeContainer()
            let viewModel = try makeViewModel("Date,Amount\nnope,1\n", container: container)
            await viewModel.load()
            #expect(viewModel.rows.isEmpty)
            #expect(viewModel.importCount == 0)
            #expect(!viewModel.canImport)
            #expect(await viewModel.performImport() == nil)
        }

        @Test func aNewCategoryUsedOnlyByDuplicatesIsNotOffered() async throws {
            let container = try makeContainer()
            try insert("Gym", 40, noon(2026, 3, 6), into: container)
            let viewModel = try makeViewModel("Date,Name,Amount,Category\n2026-03-06,Gym,40,Fitness\n", container: container)
            await viewModel.load()

            #expect(viewModel.newCategoryNames.isEmpty)
            #expect(viewModel.importCount == 0)
            #expect(!viewModel.canImport)
            // Control: with duplicates kept, the category is offered.
            viewModel.skipsDuplicates = false
            #expect(viewModel.newCategoryNames == ["Fitness"])
            #expect(viewModel.canImport)
        }

        @Test func blankNamesBecomeUntitled() async throws {
            let container = try makeContainer()
            let viewModel = try makeViewModel("Date,Name,Amount\n2026-03-05,,3\n2026-03-06,Tea,2\n", container: container)
            await viewModel.load()
            #expect(viewModel.rows.map(\.name) == [String(localized: L10n.AppIntent.untitled), "Tea"])
        }

        @Test func theCurrencyWarningNeedsADifferentCurrencyInTheFile() async throws {
            let container = try makeContainer()
            let different = try makeViewModel("Date,Amount,Currency\n2026-03-05,3,DKK\n", container: container, currency: "EUR")
            let same = try makeViewModel("Date,Amount,Currency\n2026-03-05,3,eur\n", container: container, currency: "EUR")
            let none = try makeViewModel("Date,Amount\n2026-03-05,3\n", container: container, currency: "EUR")
            #expect(different.foreignCurrency == "DKK")
            #expect(same.foreignCurrency == nil)
            #expect(none.foreignCurrency == nil)
        }

        @Test func anAmbiguousDateFormatCanBeChosenAndMovesTheDates() async throws {
            let container = try makeContainer()
            try insert("Rent", 500, noon(2026, 3, 5), into: container)
            let viewModel = try makeViewModel("Date,Name,Amount\n03/05/2026,Rent,500\n04/06/2026,Bills,80\n", container: container)
            await viewModel.load()

            #expect(viewModel.parsed.isAmbiguous)
            #expect(viewModel.dateFormat == .dayMonthYear)
            #expect(viewModel.rows.map(\.date) == [noon(2026, 5, 3), noon(2026, 6, 4)])
            #expect(viewModel.duplicateCount == 0)

            await viewModel.select(.monthDayYear)

            #expect(viewModel.dateFormat == .monthDayYear)
            #expect(viewModel.rows.map(\.date) == [noon(2026, 3, 5), noon(2026, 4, 6)])
            // Control: the same row is only a duplicate once it reads as 5 March.
            #expect(viewModel.duplicateCount == 1)

            let labels = viewModel.parsed.dateFormats.map(viewModel.sample(for:))
            #expect(labels.count == 2)
            #expect(labels.allSatisfy { !$0.isEmpty })
            #expect(Set(labels).count == 2)
        }

        @Test func aFormatWithNoAmbiguityOffersNoChoice() async throws {
            let viewModel = try makeViewModel("Date,Amount\n13/03/2026,1\n", container: try makeContainer())
            #expect(!viewModel.parsed.isAmbiguous)
        }

        @Test func previewShowsTheFirstFiveRowsWithTheCategoryTheyWouldGet() async throws {
            let container = try makeContainer()
            let text = "Date,Name,Amount,Category\n" + (1...7).map { "2026-03-0\($0),Row \($0),\($0),\($0 == 2 ? "Fitness" : "Food")" }.joined(separator: "\n")
            let viewModel = try makeViewModel(text, container: container)
            await viewModel.load()

            let preview = viewModel.previewRows
            #expect(preview.map(\.name) == (1...5).map { "Row \($0)" })
            #expect(preview[1].categoryInfo.title == "Fitness")
            #expect(preview[0].categoryInfo.title == ExpenseCategory.food.title)
            #expect(Set(preview.map(\.id)).count == 5)

            viewModel.createsCategories = false
            #expect(viewModel.previewRows[1].categoryInfo.title == ExpenseCategory.food.title)
        }

        // MARK: Import

        @Test func importInsertsTheRowsSkipsDuplicatesAndTellsEveryone() async throws {
            let container = try makeContainer()
            try insert("coffee", 3.5, noon(2026, 3, 5), into: container)
            var published = 0
            let viewModel = try makeViewModel(file, container: container, afterImport: { published += 1 })
            await viewModel.load()
            let recorder = Recorder()

            var summary: ImportReviewViewModel.Summary?
            try await recording(from: viewModel, recorder) { summary = await viewModel.performImport() }

            #expect(summary == .init(imported: 2, skipped: 2))   // 1 duplicate + 1 unreadable row
            #expect(recorder.expenses == 1)
            #expect(recorder.categories == 1)
            #expect(published == 1)
            #expect(!viewModel.isImporting)

            let context = ModelContext(container)
            let expenses = try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))
            #expect(expenses.map(\.name) == ["coffee", "Gym", "Tea"])
            let fitness = try #require(try context.fetch(FetchDescriptor<CustomCategory>()).first)
            #expect(fitness.name == "Fitness")
            #expect(expenses[1].categoryRawValue == CategoryInfo.key(forCustomID: fitness.id))
            #expect(expenses[2].categoryRawValue == CategoryInfo.key(forCustomID: fitness.id))
        }

        @Test func keepingDuplicatesImportsThemToo() async throws {
            let container = try makeContainer()
            try insert("Coffee", 3.5, noon(2026, 3, 5), into: container)
            let viewModel = try makeViewModel(file, container: container)
            await viewModel.load()
            viewModel.skipsDuplicates = false

            let summary = await viewModel.performImport()

            #expect(summary == .init(imported: 3, skipped: 1))
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<Expense>()) == 4)
        }

        @Test func withoutCreatingCategoriesTheRowsGoToFood() async throws {
            let container = try makeContainer()
            let viewModel = try makeViewModel(file, container: container)
            await viewModel.load()
            viewModel.createsCategories = false
            let recorder = Recorder()

            try await recording(from: viewModel, recorder) { _ = await viewModel.performImport() }

            let context = ModelContext(container)
            #expect(try context.fetchCount(FetchDescriptor<CustomCategory>()) == 0)
            let keys = try context.fetch(FetchDescriptor<Expense>()).map(\.categoryRawValue)
            #expect(keys.count == 3 && keys.allSatisfy { $0 == "food" })
            #expect(recorder.expenses == 1)
            #expect(recorder.categories == 0)
        }

        @Test func namedCategoriesThatExistAreUsedNotDuplicated() async throws {
            let container = try makeContainer()
            let context = ModelContext(container)
            let existing = CustomCategory(name: "Fitness", symbol: "dumbbell.fill", colorRawValue: "red")
            context.insert(existing)
            try context.save()
            let viewModel = try makeViewModel(file, container: container)
            await viewModel.load()

            #expect(viewModel.newCategoryNames.isEmpty)
            _ = await viewModel.performImport()

            #expect(try ModelContext(container).fetchCount(FetchDescriptor<CustomCategory>()) == 1)
            let gym = try #require(try ModelContext(container).fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.name == "Gym" })).first)
            #expect(gym.categoryRawValue == CategoryInfo.key(forCustomID: existing.id))
        }

        @Test func aGermanFileFindsTheBuiltInCategories() async throws {
            let container = try makeContainer()
            let viewModel = try makeViewModel(
                "Datum;Name;Betrag;Kategorie\n05.03.2026;Kaffee;3,50;Essen\n06.03.2026;Bahn;12,00;Mobilität\n",
                container: container
            )
            await viewModel.load()
            #expect(viewModel.newCategoryNames.isEmpty)
            _ = await viewModel.performImport()

            let expenses = try ModelContext(container).fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))
            #expect(expenses.map(\.categoryRawValue) == ["food", "transport"])
            #expect(expenses.map(\.amount) == [3.5, 12])
        }
    }
}
