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

    /// Whole units that never flatter: what is left rounds down, what is over rounds up.
    var wholeLeft: Decimal { Self.rounded(left, .down) }
    var wholeOver: Decimal { Self.rounded(over, .up) }

    init?(total: Decimal, budget: Double) {
        guard budget.isFinite, budget > 0 else { return nil }
        let budgetAmount = Decimal(budget)
        fraction = min(max(NSDecimalNumber(decimal: total / budgetAmount).doubleValue, 0), 1)
        left = max(budgetAmount - total, 0)
        over = max(total - budgetAmount, 0)
    }

    private static func rounded(_ value: Decimal, _ mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, 0, mode)
        return result
    }
}
