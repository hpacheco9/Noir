//
//  OverviewResults.swift
//  NOIR
//

import Foundation

/// Chart half of the Home overview.
nonisolated struct ChartResult: Sendable {
    let points: [SpendingDataPoint]
    let total: Decimal

    nonisolated init(points: [SpendingDataPoint], total: Decimal) {
        self.points = points
        self.total = total
    }
}

/// Everything else on Home: latest rows, the empty-state check and the totals the card compares against.
nonisolated struct SideResult: Sendable {
    let latest: [ExpenseDTO]
    let hasAnyExpenses: Bool
    let previousTotal: Decimal?
    let monthTotal: Decimal
}
