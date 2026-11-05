//
//  ExpenseCSVRoundTripTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

extension CategoryBreakdownRepositoryTests {
    // Export from one store, import into an empty one. Nested in the serialized `CategoryBreakdownRepositoryTests`:
    // an import moves the global memo generation that suite checks.
    @Suite
    struct ExpenseCSVRoundTripTests {
        private let utc = TimeZone(secondsFromGMT: 0)!
        private let headers = ExpenseCSV.Headers(
            date: "Date", name: "Name", amount: "Amount", currency: "Currency",
            category: "Category", card: "Card", note: "Note"
        )

        private struct Snapshot: Equatable {
            let day: Date
            let name: String
            let amount: Double
            let category: String
            let card: String
            let note: String
        }

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

        private func seed(_ container: ModelContainer) throws {
            let context = ModelContext(container)
            let pets = CustomCategory(name: "Pets, \"Fido\"", symbol: "pawprint.fill", colorRawValue: "orange")
            context.insert(pets)
            context.insert(BuiltInCategoryOverride(key: "leisure", name: "Fun"))

            func add(_ day: Int, _ name: String, _ amount: Double, _ key: String, card: String = "", note: String = "") {
                let expense = Expense(amount: amount, name: name, date: noon(2026, 3, day), category: .food, expenseDescription: note, card: card)
                expense.categoryRawValue = key
                context.insert(expense)
            }
            add(1, "Lunch, with Ana", 19.99, "food", card: "Visa")
            add(2, "Shirt", 1234.5, "clothing", note: "two\nlines")
            add(3, "Café São Paulo", 5, "transport")
            add(4, "Kibble", 42.1, CategoryInfo.key(forCustomID: pets.id), card: "Amex", note: "say \"hi\"")
            add(5, "=SUM(1)", 7.25, "leisure")
            add(6, "Bills", 0.05, "home")
            add(7, "Pills", 15.13, "health")
            try context.save()
        }

        private func export(_ container: ModelContainer) async throws -> String {
            try await ExpenseCSVExport(container: container, headers: headers, currencyCode: "EUR").csv(timeZone: utc)
        }

        private func snapshots(_ container: ModelContainer) async throws -> [Snapshot] {
            let all = try await ExpenseRepository(modelContainer: container).fetchAll()
            return all.map {
                Snapshot(
                    day: Calendar.current.startOfDay(for: $0.date), name: $0.name, amount: $0.amount,
                    category: $0.categoryInfo.title, card: $0.card, note: $0.description
                )
            }
        }

        private func review(_ csv: String, into container: ModelContainer) async throws -> ImportReviewViewModel {
            let parsed = try ExpenseCSVReader.parse(text: csv, currencyCode: "EUR", timeZone: utc)
            let viewModel = ImportReviewViewModel(
                parsed: parsed, currencyCode: "EUR",
                loader: .live(ExpenseRepositoryProvider(container: container)), afterImport: {}
            )
            await viewModel.load()
            return viewModel
        }

        @Test func exportThenImportGivesTheSameExpenses() async throws {
            let source = try makeContainer()
            try seed(source)
            let csv = try await export(source)

            let target = try makeContainer()
            let viewModel = try await review(csv, into: target)
            #expect(viewModel.rows.count == 7)
            #expect(viewModel.invalid.isEmpty)
            #expect(viewModel.duplicateCount == 0)
            #expect(!viewModel.parsed.isAmbiguous)
            #expect(viewModel.newCategoryNames == ["Pets, \"Fido\""])

            let summary = await viewModel.performImport()
            #expect(summary == .init(imported: 7, skipped: 0))

            let imported = try await snapshots(target)
            let original = try await snapshots(source)
            #expect(imported.count == 7)
            // Everything but the renamed "Leisure" (the target has no override) is identical, custom name included.
            let leisureTitle = ExpenseCategory.leisure.title
            let expected = original.map { snapshot in
                snapshot.category == "Fun"
                    ? Snapshot(day: snapshot.day, name: snapshot.name, amount: snapshot.amount, category: leisureTitle, card: snapshot.card, note: snapshot.note)
                    : snapshot
            }
            #expect(imported == expected)
            #expect(imported.map(\.name) == original.map(\.name))
            #expect(imported[0].name == "Lunch, with Ana")
            #expect(imported[3].category == "Pets, \"Fido\"")
            #expect(imported[4].name == "=SUM(1)")
            #expect(imported[1].note == "two\nlines")
        }

        @Test func importingTheSameFileAgainAddsNothing() async throws {
            let source = try makeContainer()
            try seed(source)
            let csv = try await export(source)
            let target = try makeContainer()
            let first = try await review(csv, into: target)
            _ = await first.performImport()
            let afterFirst = try await snapshots(target)

            let second = try await review(csv, into: target)
            #expect(second.rows.count == 7)
            #expect(second.duplicateCount == 7)
            #expect(second.importCount == 0)
            #expect(!second.canImport)
            #expect(await second.performImport() == nil)
            #expect(try await snapshots(target) == afterFirst)
            #expect(try ModelContext(target).fetchCount(FetchDescriptor<CustomCategory>()) == 1)

            // Control: with the duplicate check off, the same file does import again.
            second.skipsDuplicates = false
            #expect(second.importCount == 7)
            #expect(await second.performImport() == .init(imported: 7, skipped: 0))
            #expect(try await snapshots(target).count == 14)
        }

        @Test func importingBackIntoTheSourceStoreIsAllDuplicates() async throws {
            let source = try makeContainer()
            try seed(source)
            let viewModel = try await review(try await export(source), into: source)
            #expect(viewModel.duplicateCount == 7)
            #expect(viewModel.newCategoryNames.isEmpty)
        }

        @Test(arguments: [("JPY", [1235.0, 80]), ("KWD", [12.345, 1000.001])])
        func currenciesWithOtherMinorUnitsComeBackWithTheirDigits(code: String, values: [Double]) async throws {
            let source = try makeContainer()
            let context = ModelContext(source)
            for (offset, value) in values.enumerated() {
                context.insert(Expense(amount: value, name: "row \(offset)", date: noon(2026, 3, offset + 1), category: .food))
            }
            try context.save()
            let csv = try await ExpenseCSVExport(container: source, headers: headers, currencyCode: code).csv(timeZone: utc)

            // Read by an app that uses another currency: the file's Currency column decides.
            let target = try makeContainer()
            let other = try await review(csv, into: target)
            _ = await other.performImport()
            #expect(try await snapshots(target).map(\.amount) == values)

            // Read by an app on the same currency, it recognises every row as already there.
            let parsed = try ExpenseCSVReader.parse(text: csv, currencyCode: code, timeZone: utc)
            let same = ImportReviewViewModel(
                parsed: parsed, currencyCode: code, loader: .live(ExpenseRepositoryProvider(container: target)), afterImport: {}
            )
            await same.load()
            #expect(same.duplicateCount == values.count)
        }
    }
}
