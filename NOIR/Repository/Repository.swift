//
//  Repository.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation
import SwiftData

/// Hand-written `ModelActor` conformance (equivalent to the `@ModelActor` macro). Where it runs is decided by the
/// caller's isolation, not the init: see `ExpenseRepositoryProvider.perform`.
actor ExpenseRepository: ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.modelContainer = modelContainer
    }

    // MARK: - Overview

    /// What the chart needs for one period: points and total from the period's memo.
    /// DELTA when a memo for the same window exists (only rows created since its watermark are read),
    /// FULL otherwise (the whole window is read once and the memo rebuilt).
    func overviewChart(
        period: SpendingPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> ChartResult {
        // All Time spans the oldest to the newest expense's year: a row added or moved past either end changes the
        // window, so FULL.
        var earliest: Date?
        var latest: Date?
        if period == .allTime {
            var oldestDescriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)])
            oldestDescriptor.fetchLimit = 1
            earliest = try modelContext.fetch(oldestDescriptor).first?.date
            var newestDescriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            newestDescriptor.fetchLimit = 1
            latest = try modelContext.fetch(newestDescriptor).first?.date
        }
        guard let layout = SpendingBuckets.layout(
            for: period, calendar: calendar, now: now, earliest: earliest, latest: latest
        ) else {
            return ChartResult(points: [], total: 0)
        }

        let generation = OverviewMemoStore.generation
        var memo: OverviewMemo?

        // DELTA: a memo for this window, a sane watermark, and a store that still agrees on the row count.
        if let stored = OverviewMemoStore.load(period),
           stored.windowStart == layout.window.start,
           stored.windowEnd == layout.window.end,
           stored.buckets.count == layout.starts.count,
           stored.watermark <= now {   // watermark in the future: the clock went back, createdAt order can't be trusted
            var updated = stored
            let watermark = stored.watermark
            // No date clause: the invariant is "createdAt <= watermark AND in window", so every row after the
            // watermark is consumed here and `accumulate` keeps only the in-window ones.
            let descriptor = FetchDescriptor<Expense>(predicate: #Predicate<Expense> { $0.createdAt > watermark })

            let fresh = try modelContext.fetch(descriptor).map(SpendingEntry.init)

            if !fresh.isEmpty {
                let added = SpendingBuckets.accumulate(fresh, into: &updated.buckets, layout: layout)
                updated.total += added.sum
                updated.count += added.count
                updated.watermark = fresh.map(\.createdAt).max() ?? updated.watermark
                updated.computedAt = now
            }

            // Catches rows the watermark skipped (late commits, clock changes): compare with the store.
            let window = layout.window
            let storeCount = try modelContext.fetchCount(FetchDescriptor<Expense>(predicate: Self.datePredicate(window)))
            // A mismatch leaves `memo` nil, so the FULL path below repairs it.
            if storeCount == updated.count {
                if !fresh.isEmpty {
                    OverviewMemoStore.save(updated, for: period, ifGeneration: generation)
                }
                memo = updated
            }
        }

        // FULL: read the whole window once and rebuild the memo.
        if memo == nil {
            let window = layout.window
            let descriptor = FetchDescriptor<Expense>(
                predicate: Self.datePredicate(window),
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )

            let entries = try modelContext.fetch(descriptor).map(SpendingEntry.init)

            // Newest createdAt in the whole store, read AFTER the window: a row committed in between is covered by
            // the watermark but missing from the buckets, which the DELTA row-count check repairs.
            // (It also keeps rows outside the window from being refetched by every delta.)
            var newestDescriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            newestDescriptor.fetchLimit = 1
            let newest = try modelContext.fetch(newestDescriptor).first?.createdAt ?? .distantPast

            var sums = [Decimal](repeating: 0, count: layout.starts.count)
            let counted = SpendingBuckets.accumulate(entries, into: &sums, layout: layout)
            let rebuilt = OverviewMemo(
                windowStart: window.start,
                windowEnd: window.end,
                watermark: max(newest, entries.map(\.createdAt).max() ?? .distantPast),
                total: counted.sum,
                buckets: sums,
                count: counted.count,
                computedAt: now
            )
            OverviewMemoStore.save(rebuilt, for: period, ifGeneration: generation)
            memo = rebuilt
        }

        guard let memo else { return ChartResult(points: [], total: 0) }
        return ChartResult(points: layout.points(from: memo.buckets), total: memo.total)
    }

    /// The rest of the Home screen: newest rows overall, the empty-state check, the total of the period before `period`
    /// (`nil` for All Time) and this month's total (the budget is monthly, whatever the period).
    /// Reads rows only, the overview memos are not involved. Meant for a second repository instance so it runs in
    /// parallel with `overviewChart`.
    func overviewSide(
        period: SpendingPeriod,
        now: Date = .now,
        latestLimit: Int = 5,
        calendar: Calendar = .current
    ) throws -> SideResult {
        var latestDescriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        latestDescriptor.fetchLimit = max(latestLimit, 0)
        let categories = try categoryIndex()
        let latest = try modelContext.fetch(latestDescriptor).map { ExpenseDTO($0, categories: categories) }

        var anyDescriptor = FetchDescriptor<Expense>()
        anyDescriptor.fetchLimit = 1
        let hasAny = try !modelContext.fetchIdentifiers(anyDescriptor).isEmpty

        let previousTotal = try period.previousInterval(calendar: calendar, now: now).map { try total(in: $0) }
        let monthTotal = try SpendingPeriod.month.dateInterval(calendar: calendar, now: now).map { try total(in: $0) } ?? 0

        return SideResult(latest: latest, hasAnyExpenses: hasAny, previousTotal: previousTotal, monthTotal: monthTotal)
    }

    /// Sum of the amounts dated inside `interval`.
    private func total(in interval: DateInterval) throws -> Decimal {
        var descriptor = FetchDescriptor<Expense>(predicate: Self.datePredicate(interval))
        descriptor.propertiesToFetch = [\.amount]
        var sum = Decimal(0)
        try modelContext.enumerate(descriptor, batchSize: 1000) { sum += Decimal($0.amount) }
        return sum
    }

    func cumulativeDays(in month: DateInterval, calendar: Calendar = .current) throws -> [Double] {
        var descriptor = FetchDescriptor<Expense>(predicate: Self.datePredicate(month))
        descriptor.propertiesToFetch = [\.date, \.amount]
        let rows = try modelContext.fetch(descriptor).map { (date: $0.date, amount: $0.amount) }
        return MonthTotalSnapshot.cumulativeDays(rows, in: month, calendar: calendar)
    }

    nonisolated private static func datePredicate(_ interval: DateInterval) -> Predicate<Expense> {
        let start = interval.start
        let end = interval.end
        return #Predicate<Expense> { $0.date >= start && $0.date < end }
    }

    /// Spending per category for `period` (unbounded for `.allTime`).
    /// Reads rows only; the overview memo is not involved.
    func categoryBreakdown(period: SpendingPeriod, now: Date = .now, calendar: Calendar = .current) throws -> CategoryBreakdown {
        let predicate = period.dateInterval(calendar: calendar, now: now).map(Self.datePredicate)
        var descriptor = FetchDescriptor<Expense>(predicate: predicate)
        descriptor.propertiesToFetch = [\.amount, \.categoryRawValue]
        // Streams the rows in batches, so a large all-time read never holds them all at once.
        var accumulator = CategoryBreakdown.Accumulator()
        try modelContext.enumerate(descriptor, batchSize: 1000) { expense in
            accumulator.add(key: expense.categoryRawValue, amount: expense.amount)
        }
        return accumulator.finish(categories: try categoryIndex())
    }

    func fetchPage(query: String, offset: Int, limit: Int) async throws -> [ExpenseDTO] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let categories = try categoryIndex()
        let predicate: Predicate<Expense>?

        if normalizedQuery.isEmpty {
            predicate = nil
        } else {
            // Categories are stored by key: match their shown titles (main actor, localized) and search by key.
            let infos = Array(categories.values)
            let categoryKeys = await MainActor.run {
                infos.filter { $0.title.localizedStandardContains(normalizedQuery) }.map(\.key)
            }
            predicate = #Predicate<Expense> { expense in
                expense.name.localizedStandardContains(normalizedQuery)
                    || expense.card.localizedStandardContains(normalizedQuery)
                    || categoryKeys.contains(expense.categoryRawValue)
            }
        }

        var descriptor = FetchDescriptor<Expense>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor).map { ExpenseDTO($0, categories: categories) }
    }

    // MARK: - Categories
    // Overview memos only hold date/amount/createdAt, so category writes never touch them.

    /// Built-in categories first, then custom ones by creation date.
    func fetchCategories() throws -> [CategoryInfo] {
        try CategoryInfo.all(in: modelContext)
    }

    /// Key -> info, used to resolve each expense's category in one pass.
    private func categoryIndex() throws -> [String: CategoryInfo] {
        Dictionary(try fetchCategories().map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Titles every other category currently shows: built-ins (override name, else the localized default from
    /// `defaultTitles`, keyed by built-in raw value) and custom names. `excludingKey` leaves one category out.
    private func takenTitles(defaultTitles: [String: String], excludingKey: String?) throws -> [String] {
        let overrides = try modelContext.fetch(FetchDescriptor<BuiltInCategoryOverride>())
        let overrideNames = Dictionary(overrides.compactMap { o in o.name.map { (o.key, $0) } }, uniquingKeysWith: { first, _ in first })
        var titles = defaultTitles.compactMap { key, title in
            key == excludingKey ? nil : (overrideNames[key] ?? title)
        }
        for custom in try modelContext.fetch(FetchDescriptor<CustomCategory>()) {
            if CategoryInfo.key(forCustomID: custom.id) != excludingKey { titles.append(custom.name) }
        }
        return titles
    }

    nonisolated private static func sameTitle(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Creates a custom category. Throws `CategoryError.emptyName` for a blank name and `.duplicateName` when
    /// another category already shows that name (case- and diacritic-insensitive). `reservedNames` maps each
    /// built-in raw value to its localized default title (owned by the main actor); renamed built-ins use their
    /// override instead.
    func createCategory(name: String, symbol: String, color: CategoryColor, reservedNames: [String: String]) throws -> CategoryInfo {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.emptyName }
        guard !(try takenTitles(defaultTitles: reservedNames, excludingKey: nil)).contains(where: { Self.sameTitle($0, trimmed) }) else {
            throw CategoryError.duplicateName
        }

        let category = CustomCategory(name: trimmed, symbol: symbol, colorRawValue: color.rawValue)
        modelContext.insert(category)
        try commit()
        return CategoryInfo(custom: category)
    }

    /// Updates a custom category's name, symbol and colour (`nil` keeps the current colour).
    /// The key (`custom:<id>`) stays, so expenses are untouched. The name is checked like `createCategory`,
    /// ignoring this category's own current name.
    func updateCategory(id: UUID, name: String, symbol: String, color: CategoryColor?, reservedNames: [String: String]) throws -> CategoryInfo {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.emptyName }

        guard let category = try modelContext.fetch(FetchDescriptor<CustomCategory>()).first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        // Keeping the stored name (even only changing its case) always passes, e.g. when a built-in's title
        // now happens to match it after a language change.
        if !Self.sameTitle(category.name, trimmed) {
            let taken = try takenTitles(defaultTitles: reservedNames, excludingKey: CategoryInfo.key(forCustomID: id))
            guard !taken.contains(where: { Self.sameTitle($0, trimmed) }) else { throw CategoryError.duplicateName }
        }

        category.name = trimmed
        category.symbol = symbol
        // `nil`: the stored colour isn't one of the palette, and the user didn't pick another one.
        if let color { category.colorRawValue = color.rawValue }
        try commit()
        return CategoryInfo(custom: category)
    }

    /// Saves the user's changes to a built-in as a `BuiltInCategoryOverride`. Values equal to the defaults are
    /// stored as `nil` (a name equal to the localized default keeps following the app language), and when
    /// nothing differs the override is removed. The key never changes.
    func updateBuiltInCategory(key: String, name: String, symbol: String, color: CategoryColor, reservedNames: [String: String]) throws -> CategoryInfo {
        guard let builtIn = ExpenseCategory(rawValue: key) else { throw RepositoryError.notFound }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.emptyName }

        let existing = try modelContext.fetch(FetchDescriptor<BuiltInCategoryOverride>()).first { $0.key == key }
        let defaultTitle = reservedNames[key]
        let currentTitle = existing?.name ?? defaultTitle ?? trimmed
        if !Self.sameTitle(currentTitle, trimmed) {
            let taken = try takenTitles(defaultTitles: reservedNames, excludingKey: key)
            guard !taken.contains(where: { Self.sameTitle($0, trimmed) }) else { throw CategoryError.duplicateName }
        }

        // Same title up to case/accents counts as the default, so it keeps following the app language.
        let storedName = defaultTitle.map { Self.sameTitle($0, trimmed) } == true ? nil : trimmed
        let storedSymbol = symbol == builtIn.icon ? nil : symbol
        let storedColor = color == builtIn.colorKey ? nil : color.rawValue

        if storedName == nil, storedSymbol == nil, storedColor == nil {
            if let existing { modelContext.delete(existing) }
            try commit()
            return CategoryInfo(builtIn: builtIn)
        }
        let override = existing ?? BuiltInCategoryOverride(key: key)
        override.name = storedName
        override.symbol = storedSymbol
        override.colorRawValue = storedColor
        if existing == nil { modelContext.insert(override) }
        try commit()
        return CategoryInfo(builtIn: builtIn, override: override)
    }

    /// Removes a built-in's override, back to its default name, symbol and colour. Throws `.duplicateName` when
    /// another category now uses the default title (e.g. Food renamed, then a custom "Food" created).
    @discardableResult
    func restoreBuiltInCategory(key: String, reservedNames: [String: String]) throws -> CategoryInfo {
        guard let builtIn = ExpenseCategory(rawValue: key) else { throw RepositoryError.notFound }
        if let existing = try modelContext.fetch(FetchDescriptor<BuiltInCategoryOverride>()).first(where: { $0.key == key }) {
            if existing.name != nil, let defaultTitle = reservedNames[key] {
                let taken = try takenTitles(defaultTitles: reservedNames, excludingKey: key)
                guard !taken.contains(where: { Self.sameTitle($0, defaultTitle) }) else { throw CategoryError.duplicateName }
            }
            modelContext.delete(existing)
            try commit()
        }
        return CategoryInfo(builtIn: builtIn)
    }

    /// Deletes a custom category and moves its expenses to `other` in the same save.
    /// Returns how many expenses were reassigned.
    @discardableResult
    func deleteCategory(id: UUID) throws -> Int {
        let categories = try modelContext.fetch(FetchDescriptor<CustomCategory>(predicate: #Predicate { $0.id == id }))
        guard let category = categories.first else { throw RepositoryError.notFound }

        let key = CategoryInfo.key(forCustomID: id)
        let affected = try modelContext.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.categoryRawValue == key }))
        for expense in affected {
            expense.category = .other
        }
        modelContext.delete(category)
        try commit()
        return affected.count
    }

    /// The key to store: the given one if it is a built-in or an existing custom category, otherwise `other`.
    private func resolvedCategoryKey(_ key: String) throws -> String {
        if ExpenseCategory(rawValue: key) != nil { return key }
        guard let id = CategoryInfo.customID(fromKey: key) else { return ExpenseCategory.other.rawValue }
        let count = try modelContext.fetchCount(FetchDescriptor<CustomCategory>(predicate: #Predicate { $0.id == id }))
        return count > 0 ? CategoryInfo.key(forCustomID: id) : ExpenseCategory.other.rawValue
    }

    func save(
        id: PersistentIdentifier?,
        amount: Double,
        name: String,
        date: Date,
        categoryKey: String,
        description: String,
        card: String,
    ) throws {
        guard Expense.isValidAmount(amount) else { throw RepositoryError.invalidAmount }
        let categoryKey = try resolvedCategoryKey(categoryKey)
        let existing = try id.map(existingExpense)
        // Two-phase with the overview memos: nothing may save a memo while this write is in flight.
        OverviewMemoStore.beginWrite()

        if let expense = existing {
            // Edit: remember what the memos currently count for this row, then move it.
            let before = SpendingEntry(expense)
            expense.amount = amount
            expense.name = name
            expense.date = date
            expense.categoryRawValue = categoryKey
            expense.expenseDescription = description
            expense.card = card
            do {
                try commit()
            } catch {
                OverviewMemoStore.cancelWrite()
                throw error
            }

            OverviewMemoStore.finishWrite(
                old: before,
                new: SpendingEntry(date: date, amount: amount, createdAt: before.createdAt)
            )
            SavedCards.remember(card)
        } else {
            let expense = Expense(
                amount: amount,
                name: name,
                date: date,
                category: .other,
                expenseDescription: description,
                card: card,
            )
            expense.categoryRawValue = categoryKey
            expense.createdAt = .now
            modelContext.insert(expense)
            do {
                try commit()
            } catch {
                OverviewMemoStore.cancelWrite()
                throw error
            }
            OverviewMemoStore.finishWrite()
            SavedCards.remember(card)
        }
    }

    func fetchCards() throws -> [String] {
        try SavedCards.fetch(in: modelContext)
    }

    func delete(id: PersistentIdentifier) throws {
        let expense = try existingExpense(id)
        OverviewMemoStore.beginWrite()
        let before = SpendingEntry(expense)
        modelContext.delete(expense)
        do {
            try commit()
        } catch {
            OverviewMemoStore.cancelWrite()
            throw error
        }
        OverviewMemoStore.finishWrite(old: before)
    }

    // Not model(for:): for a row deleted elsewhere it returns a fault that traps when read.
    private func existingExpense(_ id: PersistentIdentifier) throws -> Expense {
        var descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        guard let expense = try modelContext.fetch(descriptor).first else { throw RepositoryError.notFound }
        return expense
    }

    /// `save()` that leaves the context clean on failure, so a failed write can't leak into the next one.
    private func commit() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
