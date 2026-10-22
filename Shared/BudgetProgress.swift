//
//  BudgetProgress.swift
//  NOIR
//

import Foundation

nonisolated struct BudgetProgress: Equatable, Sendable {
    let fraction: Double
    let left: Decimal

    init?(total: Decimal, budget: Double) {
        guard budget.isFinite, budget > 0 else { return nil }
        let budgetAmount = Decimal(budget)
        fraction = min(max(NSDecimalNumber(decimal: total / budgetAmount).doubleValue, 0), 1)
        left = max(budgetAmount - total, 0)
    }
}
