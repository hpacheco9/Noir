//
//  ExpenseCSVExport.swift
//  NOIR
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

nonisolated struct ExpenseCSVExport: Transferable {
    let container: ModelContainer
    let headers: ExpenseCSV.Headers
    let currencyCode: String

    static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "CSVExport", directoryHint: .isDirectory)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            SentTransferredFile(try await export.writeFile())
        }
    }

    @concurrent
    func csv(timeZone: TimeZone = .current) async throws -> String {
        let expenses = try await ExpenseRepositoryProvider(container: container).perform { try await $0.fetchAll() }
        let categories = Set(expenses.map(\.categoryInfo))
        let titles = await MainActor.run {
            Dictionary(categories.map { ($0.key, $0.title) }, uniquingKeysWith: { first, _ in first })
        }
        let rows = expenses.map {
            ExpenseCSV.Row(
                date: $0.date,
                name: $0.name,
                amount: $0.amount,
                category: titles[$0.categoryInfo.key] ?? $0.categoryInfo.key,
                card: $0.card,
                note: $0.description
            )
        }
        return ExpenseCSV.make(rows: rows, headers: headers, currencyCode: currencyCode, timeZone: timeZone)
    }

    @concurrent
    func writeFile(
        now: Date = .now,
        timeZone: TimeZone = .current,
        directory: URL = Self.exportDirectory
    ) async throws -> URL {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let text = try await csv(timeZone: timeZone)
        let file = directory.appending(path: ExpenseCSV.fileName(for: now, timeZone: timeZone))
        try Data(text.utf8).write(to: file, options: .atomic)
        return file
    }
}

extension ExpenseCSV.Headers {
    static var localized: ExpenseCSV.Headers {
        ExpenseCSV.Headers(
            date: String(localized: L10n.Export.headerDate),
            name: String(localized: L10n.Export.headerName),
            amount: String(localized: L10n.Export.headerAmount),
            currency: String(localized: L10n.Export.headerCurrency),
            category: String(localized: L10n.Export.headerCategory),
            card: String(localized: L10n.Export.headerCard),
            note: String(localized: L10n.Export.headerNote)
        )
    }
}
