//
//  ImportReviewViewModel.swift
//  NOIR
//

import Foundation
import Observation

@MainActor
@Observable
final class ImportReviewViewModel {
    struct Summary: Equatable {
        let imported: Int
        let skipped: Int
    }

    static let previewCount = 5

    let parsed: ExpenseCSVReader.Parsed
    let currencyCode: String

    private(set) var isLoading = true
    private(set) var isImporting = false
    private(set) var dateFormat: ImportDateFormat
    private(set) var rows: [ImportRow] = []
    private(set) var invalid: [ExpenseCSVReader.InvalidRow] = []
    private(set) var duplicates: Set<Int> = []
    var failureMessage: String?

    var createsCategories = true
    var skipsDuplicates = true

    private var categories: [CategoryInfo] = []
    private var matcher: ImportCategoryMatcher?
    private var generation = 0
    private let repository: ExpenseRepositoryProvider
    private let afterImport: () async -> Void

    init(
        parsed: ExpenseCSVReader.Parsed,
        currencyCode: String,
        repository: ExpenseRepositoryProvider? = nil,
        afterImport: @escaping () async -> Void = { await WidgetSnapshotPublisher.publish() }
    ) {
        self.parsed = parsed
        self.currencyCode = currencyCode
        self.dateFormat = parsed.dateFormats[0]
        self.repository = repository ?? .init(container: NOIRApp.sharedModelContainer)
        self.afterImport = afterImport
    }

    // MARK: Derived

    var importable: [ImportRow] {
        skipsDuplicates ? rows.indices.filter { !duplicates.contains($0) }.map { rows[$0] } : rows
    }

    var importCount: Int { rows.count - (skipsDuplicates ? duplicates.count : 0) }

    var duplicateCount: Int { duplicates.count }

    var newCategoryNames: [String] { Self.newNames(in: importable) }

    // The first rows as the list will show them, with the category each would get.
    var previewRows: [ExpenseDTO] {
        let index = Dictionary(categories.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let food = index[ExpenseCategory.food.rawValue] ?? .food
        let names = Self.newNames(in: rows)
        return rows.prefix(Self.previewCount).map { row in
            let info: CategoryInfo
            switch row.category {
            case .existing(let key):
                info = index[key] ?? food
            case .new(let name):
                if createsCategories, let position = names.firstIndex(where: { $0.searchKey == name.searchKey }) {
                    info = CategoryInfo(custom: CustomCategory(
                        name: name, symbol: ImportDefaults.symbol, colorRawValue: ImportDefaults.color(at: position).rawValue
                    ))
                } else {
                    info = food
                }
            }
            let expense = Expense(
                amount: row.amount, name: row.name, date: row.date, category: .food,
                expenseDescription: row.note, card: row.card
            )
            expense.categoryRawValue = info.key
            return ExpenseDTO(expense, categories: [info.key: info])
        }
    }

    var foreignCurrency: String? { parsed.currencyCodes.first { $0 != currencyCode } }

    var canImport: Bool { !isLoading && !isImporting && importCount > 0 }

    // The first record whose day and month read differently, so the choices don't look alike.
    func sample(for format: ImportDateFormat) -> String {
        let candidates = parsed.dateFormats
        let record = parsed.records.first { record in
            let readings = candidates.map { $0.date(from: record.dateText, timeZone: parsed.timeZone) }
            return Set(readings).count > 1
        } ?? parsed.records.first
        guard let record, let date = format.date(from: record.dateText, timeZone: parsed.timeZone) else { return "" }
        return date.formatted(.dateTime.year().month(.wide).day())
    }

    // MARK: Loading

    func load() async {
        if let all = try? await repository.perform({ try await $0.fetchCategories() }) {
            categories = all
        } else {
            categories = CategoryInfo.builtIns
        }
        matcher = ImportCategoryMatcher.make(categories: categories)
        await rebuild()
        isLoading = false
    }

    func select(_ format: ImportDateFormat) async {
        guard format != dateFormat else { return }
        dateFormat = format
        await rebuild()
    }

    private func rebuild() async {
        guard let matcher else { return }
        generation += 1
        let current = generation
        let built = await Self.build(
            parsed, format: dateFormat, matcher: matcher, untitled: String(localized: L10n.AppIntent.untitled)
        )
        let digits = ExpenseCSV.fractionDigits(for: currencyCode)
        let found = (try? await repository.perform {
            try await $0.duplicateIndices(in: built.rows, fractionDigits: digits)
        }) ?? []
        guard current == generation else { return }
        rows = built.rows
        invalid = built.invalid
        duplicates = found
    }

    @concurrent
    private static func build(
        _ parsed: ExpenseCSVReader.Parsed,
        format: ImportDateFormat,
        matcher: ImportCategoryMatcher,
        untitled: String
    ) async -> (rows: [ImportRow], invalid: [ExpenseCSVReader.InvalidRow]) {
        let dated = parsed.dated(using: format)
        let rows = dated.rows.map { item in
            ImportRow(
                date: item.date,
                name: AddApplePayExpenseIntent.resolvedName(item.record.name, untitled: untitled),
                amount: item.record.amount,
                category: matcher.resolve(id: item.record.categoryID, name: item.record.category),
                card: item.record.card,
                note: item.record.note
            )
        }
        return (rows, dated.invalid)
    }

    private static func newNames(in rows: [ImportRow]) -> [String] {
        var seen = Set<String>()
        return rows.compactMap { row in
            guard case .new(let name) = row.category, seen.insert(name.searchKey).inserted else { return nil }
            return name
        }
    }

    // MARK: Import

    func performImport() async -> Summary? {
        guard canImport else { return nil }
        isImporting = true
        defer { isImporting = false }

        let names = createsCategories ? newCategoryNames : []
        let toImport = createsCategories ? importable : importable.map(Self.foodIfNew)
        do {
            let count = try await repository.perform { try await $0.importExpenses(toImport, newCategories: names) }
            NotificationCenter.default.post(name: .expensesDidChange, object: self)
            if !names.isEmpty { NotificationCenter.default.post(name: .categoriesDidChange, object: self) }
            await afterImport()
            return Summary(imported: count, skipped: rows.count - count + invalid.count)
        } catch {
            failureMessage = String(localized: L10n.Import.failedMessage)
            return nil
        }
    }

    private static func foodIfNew(_ row: ImportRow) -> ImportRow {
        guard case .new = row.category else { return row }
        var row = row
        row.category = .existing(key: ExpenseCategory.food.rawValue)
        return row
    }
}
