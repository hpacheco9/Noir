//
//  ExpenseCSVExport.swift
//  NOIR
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Shared with `ShareLink`. Nothing is read until the share sheet asks for the file.
nonisolated struct ExpenseCSVExport: Transferable {
    let container: ModelContainer
    let headers: ExpenseCSV.Headers
    let currencyCode: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            SentTransferredFile(try await export.writeFile())
        }
    }

    func csv(timeZone: TimeZone = .current) async throws -> String {
        let expenses = try await ExpenseRepositoryProvider(container: container).perform { try await $0.fetchAll() }
        // Category titles are localized on the main actor; resolve each distinct one once.
        let categories = Set(expenses.map(\.categoryInfo))
        let titles = await MainActor.run {
            Dictionary(categories.map { ($0.key, $0.title) }, uniquingKeysWith: { first, _ in first })
        }
        let rows = expenses.map {
            ExpenseCSV.Row(
                date: $0.date,
                name: $0.name,
                amount: $0.amount,
                category: titles[$0.categoryInfo.key] ?? "",
                card: $0.card,
                note: $0.description
            )
        }
        return ExpenseCSV.make(rows: rows, headers: headers, currencyCode: currencyCode, timeZone: timeZone)
    }

    // Own folder per export, so the file keeps the right name and exports never overwrite each other.
    func writeFile(
        now: Date = .now,
        directory: URL = FileManager.default.temporaryDirectory
    ) async throws -> URL {
        let text = try await csv()
        let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: ExpenseCSV.fileName(for: now))
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
