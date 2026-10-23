//
//  BudgetProgress.swift
//  NOIR
//

import Foundation

nonisolated struct BudgetProgress: Equatable, Sendable {
    let fraction: Double
    let left: Decimal
    let over: Decimal

    var isOver: Bool { over > 0 }

    var wholeLeft: Decimal { Self.rounded(left, scale: 0, .down) }
    var wholeOver: Decimal { Self.rounded(over, scale: 0, .up) }

    init?(total: Decimal, budget: Double) {
        guard budget.isFinite, budget > 0 else { return nil }
        // Sums of Decimal(Double) carry ~1e-17 of noise that floor/ceil would turn into a whole unit.
        let spent = Self.rounded(total, scale: 2, .plain)
        let budgetAmount = Self.rounded(Decimal(budget), scale: 2, .plain)
        guard budgetAmount > 0 else { return nil }
        fraction = min(max(NSDecimalNumber(decimal: spent / budgetAmount).doubleValue, 0), 1)
        left = max(budgetAmount - spent, 0)
        over = max(spent - budgetAmount, 0)
    }

    private static func rounded(_ value: Decimal, scale: Int, _ mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}
