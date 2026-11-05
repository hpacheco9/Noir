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

    struct Loader: Sendable {
        var categories: @Sendable () async throws -> [CategoryInfo]
        var duplicates: @Sendable ([ImportRow], Int) async throws -> Set<Int>
        var importRows: @Sendable ([ImportRow], Bool, Bool, Int) async throws -> ImportResult

        static func live(_ repository: ExpenseRepositoryProvider) -> Loader {
            Loader(
                categories: { try await repository.perform { try await $0.fetchCategories() } },
                duplicates: { rows, digits in
                    try await repository.perform { try await $0.duplicateIndices(in: rows, fractionDigits: digits) }
                },
                importRows: { rows, createCategories, skipDuplicates, digits in
                    try await repository.perform {
                        try await $0.importExpenses(
                            rows, createCategories: createCategories, skipDuplicates: skipDuplicates, fractionDigits: digits
                        )
                    }
                }
            )
        }
    }

    static let previewCount = 5

    let parsed: ExpenseCSVReader.Parsed
    let currencyCode: String

    private(set) var isLoading = true
    private(set) var isRebuilding = false
    private(set) var isImporting = false
    private(set) var loadFailed = false
    private(set) var dateFormat: ImportDateFormat
    private(set) var rows: [ImportRow] = []
    private(set) var invalid: [ExpenseCSVReader.InvalidRow] = []
    private(set) var duplicates: Set<Int> = []
    private(set) var dateSamples: [ImportDateFormat: String] = [:]
    private(set) var summary: Summary?
    var failureMessage: String?

    var createsCategories = true
    var skipsDuplicates = true

    private var categories: [CategoryInfo] = []
    private var matcher: ImportCategoryMatcher?
    private var generation = 0
    private var namesWithDuplicates: [String] = []
    private var namesWithoutDuplicates: [String] = []
    private var previewWithCategories: [ExpenseDTO] = []
    private var previewWithoutCategories: [ExpenseDTO] = []
    private var loader: Loader?
    private let afterImport: () async -> Void

    init(
        parsed: ExpenseCSVReader.Parsed,
        currencyCode: String,
        loader: Loader? = nil,
        afterImport: @escaping () async -> Void = { await WidgetSnapshotPublisher.publish() }
    ) {
        self.parsed = parsed
        self.currencyCode = currencyCode
        self.dateFormat = parsed.dateFormats[0]
        self.loader = loader
        self.afterImport = afterImport
    }

    // MARK: Derived

    var duplicateCount: Int { duplicates.count }

    var importCount: Int { rows.count - (skipsDuplicates ? duplicates.count : 0) }

    var newCategoryNames: [String] { skipsDuplicates ? namesWithoutDuplicates : namesWithDuplicates }

    var previewRows: [ExpenseDTO] { createsCategories ? previewWithCategories : previewWithoutCategories }

    var foreignCurrency: String? { parsed.currencyCodes.first { $0 != currencyCode } }

    var canImport: Bool {
        !isLoading && !isRebuilding && !isImporting && !loadFailed && summary == nil && importCount > 0
    }

    func sample(for format: ImportDateFormat) -> String { dateSamples[format] ?? "" }

    // MARK: Loading

    func load() async {
        isLoading = true
        loadFailed = false
        do {
            categories = try await resolvedLoader().categories()
        } catch {
            loadFailed = true
            isLoading = false
            return
        }
        matcher = ImportCategoryMatcher.make(categories: categories)
        dateSamples = makeDateSamples()
        await rebuild()
        isLoading = false
    }

    func select(_ format: ImportDateFormat) async {
        guard format != dateFormat else { return }
        dateFormat = format
        await rebuild()
    }

    private func resolvedLoader() -> Loader {
        if let loader { return loader }
        let live = Loader.live(.init(container: NOIRApp.sharedModelContainer))
        loader = live
        return live
    }

    private func rebuild() async {
        guard let matcher else { return }
        generation += 1
        let current = generation
        isRebuilding = true
        let built = await Self.build(
            parsed, format: dateFormat, matcher: matcher, untitled: String(localized: L10n.AppIntent.untitled)
        )
        let found: Set<Int>
        do {
            found = try await resolvedLoader().duplicates(built.rows, ExpenseCSV.fractionDigits(for: currencyCode))
        } catch {
            if current == generation {
                loadFailed = true
                isRebuilding = false
            }
            return
        }
        guard current == generation else { return }
        rows = built.rows
        invalid = built.invalid
        duplicates = found
        loadFailed = false
        refreshDerived()
        isRebuilding = false
    }

    @concurrent
    private static func build(
        _ parsed: ExpenseCSVReader.Parsed,
        format: ImportDateFormat,
        matcher: ImportCategoryMatcher,
        untitled: String
    ) async -> (rows: [ImportRow], invalid: [ExpenseCSVReader.InvalidRow]) {
        var rows: [ImportRow] = []
        var invalid = parsed.invalid
        for record in parsed.records {
            guard let date = format.date(from: record.dateText, timeZone: parsed.timeZone) else {
                invalid.append(ExpenseCSVReader.InvalidRow(line: record.line, reason: .date))
                continue
            }
            rows.append(ImportRow(
                date: date,
                name: AddApplePayExpenseIntent.resolvedName(record.name, untitled: untitled),
                amount: record.amount,
                category: matcher.resolve(id: record.categoryID, name: record.category),
                card: record.card,
                note: record.note
            ))
        }
        return (rows, invalid.sorted { $0.line < $1.line })
    }

    // The names to create and the preview rows, for both settings of each switch, so drawing does no work.
    private func refreshDerived() {
        let all = Self.newNames(in: rows)
        namesWithDuplicates = all.map(\.name)
        namesWithoutDuplicates = Self.newNames(in: rows.indices.filter { !duplicates.contains($0) }.map { rows[$0] }).map(\.name)

        let index = Dictionary(categories.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let food = index[ExpenseCategory.food.rawValue] ?? .food
        var created: [String: CategoryInfo] = [:]
        for (position, new) in all.enumerated() {
            created[new.key] = CategoryInfo(custom: CustomCategory(
                name: new.name,
                symbol: AssetName.CategorySymbols.generic,
                colorRawValue: CategoryColor.allCases[position % CategoryColor.allCases.count].rawValue
            ))
        }
        func preview(creating: Bool) -> [ExpenseDTO] {
            rows.prefix(Self.previewCount).map { row in
                let info: CategoryInfo
                switch row.category {
                case .existing(let key): info = index[key] ?? food
                case .new(let name): info = (creating ? created[name.searchKey] : nil) ?? food
                }
                let expense = Expense(
                    amount: row.amount, name: row.name, date: row.date, category: .food,
                    expenseDescription: row.note, card: row.card
                )
                expense.categoryRawValue = info.key
                return ExpenseDTO(expense, categories: [info.key: info])
            }
        }
        previewWithCategories = preview(creating: true)
        previewWithoutCategories = preview(creating: false)
    }

    // The distinct new names (by what the file says) and what each category would be called.
    private static func newNames(in rows: [ImportRow]) -> [(key: String, name: String)] {
        var seen = Set<String>()
        return rows.compactMap { row in
            guard case .new(let name) = row.category, seen.insert(name.searchKey).inserted else { return nil }
            return (name.searchKey, ImportCategory.categoryName(for: name))
        }
    }

    // How each choice would read, from the first date that reads differently in them.
    private func makeDateSamples() -> [ImportDateFormat: String] {
        let formats = parsed.dateFormats
        let record = parsed.records.first { record in
            Set(formats.map { $0.date(from: record.dateText, timeZone: parsed.timeZone) }).count > 1
        } ?? parsed.records.first
        guard let record else { return [:] }
        return Dictionary(uniqueKeysWithValues: formats.map { format in
            let date = format.date(from: record.dateText, timeZone: parsed.timeZone)
            return (format, date?.formatted(.dateTime.year().month(.wide).day()) ?? "")
        })
    }

    // MARK: Import

    func performImport() async -> Summary? {
        guard canImport else { return nil }
        isImporting = true
        defer { isImporting = false }

        let rows = rows
        let createsCategories = createsCategories
        let skipsDuplicates = skipsDuplicates
        do {
            let result = try await resolvedLoader().importRows(
                rows, createsCategories, skipsDuplicates, ExpenseCSV.fractionDigits(for: currencyCode)
            )
            NotificationCenter.default.post(name: .expensesDidChange, object: self)
            if result.categoriesCreated > 0 { NotificationCenter.default.post(name: .categoriesDidChange, object: self) }
            await afterImport()
            let summary = Summary(imported: result.imported, skipped: result.duplicates + invalid.count)
            self.summary = summary
            return summary
        } catch {
            failureMessage = String(localized: L10n.Import.failedMessage)
            return nil
        }
    }
}
