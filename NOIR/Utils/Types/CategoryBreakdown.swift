//
//  CategoryBreakdown.swift
//  NOIR
//

import Foundation

/// One category's share of the spending in a period.
nonisolated struct CategorySpending: Sendable, Identifiable, Equatable {
    let info: CategoryInfo
    let amount: Decimal
    /// Expenses that make up `amount`.
    let count: Int

    var id: String { info.key }
}

/// Spending per category for one period, as the Dashboard shows it. Sendable, so the repository actor can return it.
nonisolated struct CategoryBreakdown: Sendable, Equatable {
    /// Sum of `categories` (positive amounts only).
    let total: Decimal
    /// Every category with spending, largest first; ties broken by key so the order is deterministic.
    let categories: [CategorySpending]

    static let empty = CategoryBreakdown(total: 0, categories: [])

    /// Groups raw `(categoryKey, amount)` rows. Keys that no longer resolve (deleted custom category, unknown value)
    /// count as the built-in Other, like `ExpenseDTO`. Categories whose total is not positive are dropped.
    static func make(rows: [(key: String, amount: Double)], categories index: [String: CategoryInfo]) -> CategoryBreakdown {
        var accumulator = Accumulator()
        for row in rows { accumulator.add(key: row.key, amount: row.amount) }
        return accumulator.finish(categories: index)
    }

    /// Streaming version of `make`, so the repository can fold rows in while enumerating instead of holding them all.
    struct Accumulator {
        private var sums: [String: (amount: Decimal, count: Int)] = [:]

        mutating func add(key: String, amount: Double) {
            var entry = sums[key] ?? (0, 0)
            entry.amount += Decimal(amount)
            entry.count += 1
            sums[key] = entry
        }

        func finish(categories index: [String: CategoryInfo]) -> CategoryBreakdown {
            let fallback = index[ExpenseCategory.other.rawValue] ?? CategoryInfo.other
            var resolved: [String: (info: CategoryInfo, amount: Decimal, count: Int)] = [:]
            for (key, entry) in sums {
                let info = index[key] ?? fallback
                var merged = resolved[info.key] ?? (info, 0, 0)
                merged.amount += entry.amount
                merged.count += entry.count
                resolved[info.key] = merged
            }

            let sorted = resolved.values
                .filter { $0.amount > 0 }
                .sorted { lhs, rhs in
                    lhs.amount != rhs.amount ? lhs.amount > rhs.amount : lhs.info.key < rhs.info.key
                }
                .map { CategorySpending(info: $0.info, amount: $0.amount, count: $0.count) }
            return CategoryBreakdown(total: sorted.reduce(0) { $0 + $1.amount }, categories: sorted)
        }
    }
}
