//
//  ExpenseCSVExportTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

// In-memory store, rows inserted straight into a `ModelContext`.
struct ExpenseCSVExportTests {
    private let headers = ExpenseCSV.Headers(
        date: "Date", name: "Name", amount: "Amount", currency: "Currency",
        category: "Category", card: "Card", note: "Note"
    )

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func export(_ container: ModelContainer, currency: String = "EUR") -> ExpenseCSVExport {
        ExpenseCSVExport(container: container, headers: headers, currencyCode: currency)
    }

    private func fetchAll(_ container: ModelContainer) async throws -> [ExpenseDTO] {
        try await ExpenseRepository(modelContainer: container).fetchAll()
    }

    // MARK: fetchAll

    @Test func fetchAllIsOldestFirstAndThenByInsertTime() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 3, name: "newest", date: date(2026, 3, 9), category: .food, createdAt: date(2026, 3, 1)))
        context.insert(Expense(amount: 2, name: "same day, inserted later", date: date(2026, 3, 5), category: .food, createdAt: date(2026, 3, 8)))
        context.insert(Expense(amount: 1, name: "same day, inserted first", date: date(2026, 3, 5), category: .food, createdAt: date(2026, 3, 2)))
        context.insert(Expense(amount: 0.5, name: "oldest", date: date(2025, 1, 1), category: .food, createdAt: date(2026, 3, 3)))
        try context.save()

        let names = try await fetchAll(container).map(\.name)
        #expect(names == ["oldest", "same day, inserted first", "same day, inserted later", "newest"])
    }

    @Test func fetchAllOfAnEmptyStoreIsEmpty() async throws {
        #expect(try await fetchAll(try makeContainer()).isEmpty)
    }

    @Test func fetchAllResolvesUnknownCategoryKeysToFood() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let known = Expense(amount: 1, name: "known", date: date(2026, 3, 1), category: .transport)
        let deleted = Expense(amount: 2, name: "deleted custom", date: date(2026, 3, 2), category: .food)
        deleted.categoryRawValue = CategoryInfo.key(forCustomID: UUID())
        let legacy = Expense(amount: 3, name: "legacy other", date: date(2026, 3, 3), category: .food)
        legacy.categoryRawValue = "other"
        [known, deleted, legacy].forEach(context.insert)
        try context.save()

        let all = try await fetchAll(container)
        #expect(all.map(\.categoryInfo.key) == [ExpenseCategory.transport.rawValue, "food", "food"])
        #expect(all[1].categoryInfo.title == ExpenseCategory.food.title)
        #expect(all[2].categoryInfo.title == ExpenseCategory.food.title)
        #expect(all[0].categoryInfo.title == ExpenseCategory.transport.title)
        #expect(ExpenseCategory.transport.title != ExpenseCategory.food.title)
    }

    // MARK: csv

    @Test func csvOfAnEmptyStoreIsTheHeaderOnly() async throws {
        let text = try await export(try makeContainer()).csv()
        #expect(text == "\u{FEFF}Date,Name,Amount,Currency,Category,Card,Note\r\n")
    }

    @Test func csvShowsCustomNamesOverridesAndFoodFallback() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let custom = CustomCategory(name: "Pets, \"Fido\"", symbol: "pawprint.fill", colorRawValue: CategoryColor.orange.rawValue)
        context.insert(custom)
        context.insert(BuiltInCategoryOverride(key: ExpenseCategory.health.rawValue, name: "Doctor"))

        let inCustom = Expense(amount: 12.5, name: "Food for Fido", date: date(2026, 3, 1), category: .food, card: "Visa")
        inCustom.categoryRawValue = CategoryInfo.key(forCustomID: custom.id)
        let renamed = Expense(amount: 40, name: "Checkup", date: date(2026, 3, 2), category: .health, expenseDescription: "yearly")
        let orphan = Expense(amount: 7, name: "Orphan", date: date(2026, 3, 3), category: .food)
        orphan.categoryRawValue = CategoryInfo.key(forCustomID: UUID())
        [inCustom, renamed, orphan].forEach(context.insert)
        try context.save()

        let text = try await export(container, currency: "USD").csv(timeZone: TimeZone(secondsFromGMT: 0)!)
        let food = ExpenseCategory.food.title
        let expected = [
            "Date,Name,Amount,Currency,Category,Card,Note",
            "2026-03-01,Food for Fido,12.5,USD,\"Pets, \"\"Fido\"\"\",Visa,",
            "2026-03-02,Checkup,40,USD,Doctor,,yearly",
            "2026-03-03,Orphan,7,USD,\(food),,",
        ].joined(separator: "\r\n") + "\r\n"
        #expect(text == "\u{FEFF}" + expected)
    }

    // MARK: writeFile

    private let utc = TimeZone(secondsFromGMT: 0)!

    private func scratchDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "csv-export-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func writeFileNamesTheFileAfterTheDayAndHoldsTheCSV() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Expense(amount: 19.99, name: "Café", date: date(2026, 3, 1), category: .food))
        try context.save()

        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let export = export(container)
        let url = try await export.writeFile(now: date(2026, 11, 5), timeZone: utc, directory: directory)

        #expect(url.lastPathComponent == "NOIR Expenses 2026-11-05.csv")
        #expect(url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        let written = String(decoding: data, as: UTF8.self)
        #expect(written.hasPrefix("\u{FEFF}Date,Name,Amount,Currency,Category,Card,Note\r\n"))
        #expect(written.contains("2026-03-01,Café,19.99,EUR,"))
    }

    @Test func anExportReplacesThePreviousFile() async throws {
        let container = try makeContainer()
        let directory = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileManager = FileManager.default

        let export = export(container)
        let first = try await export.writeFile(now: date(2026, 11, 5), timeZone: utc, directory: directory)
        let stray = directory.appending(path: "leftover.txt")
        try Data("x".utf8).write(to: stray)
        #expect(fileManager.fileExists(atPath: first.path))
        #expect(fileManager.fileExists(atPath: stray.path))

        let second = try await export.writeFile(now: date(2026, 11, 6), timeZone: utc, directory: directory)

        #expect(second.lastPathComponent == "NOIR Expenses 2026-11-06.csv")
        #expect(fileManager.fileExists(atPath: second.path))
        #expect(!fileManager.fileExists(atPath: first.path))
        #expect(!fileManager.fileExists(atPath: stray.path))
        #expect(try fileManager.contentsOfDirectory(atPath: directory.path) == ["NOIR Expenses 2026-11-06.csv"])
    }

    @Test func theDefaultFolderIsOneFixedFolderInTemp() {
        #expect(ExpenseCSVExport.exportDirectory.lastPathComponent == "CSVExport")
        #expect(ExpenseCSVExport.exportDirectory.deletingLastPathComponent().standardizedFileURL
                == FileManager.default.temporaryDirectory.standardizedFileURL)
    }
}
