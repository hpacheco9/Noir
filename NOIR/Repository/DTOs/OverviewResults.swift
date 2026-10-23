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

/// Latest-rows half of the Home overview.
nonisolated struct SideResult: Sendable {
    let latest: [ExpenseDTO]
    let hasAnyExpenses: Bool
    let previousTotal: Decimal?
    let monthTotal: Decimal
}
