//
//  Types.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/09/2026.
//

import Foundation

struct SpendingDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let amount: Decimal
}

/// The two fields the chart needs from an expense. Cheap to build (no name/description faulting).
nonisolated struct SpendingEntry: Sendable {
    let date: Date
    let amount: Double
    let createdAt: Date

    nonisolated init(date: Date, amount: Double, createdAt: Date) {
        self.date = date
        self.amount = amount
        self.createdAt = createdAt
    }

    nonisolated init(_ expense: Expense) {
        self.date = expense.date
        self.amount = expense.amount
        self.createdAt = expense.createdAt
    }
}

/// Everything the home screen shows for one selected period, computed off the main thread.
nonisolated struct OverviewSnapshot: Sendable, Identifiable {
    /// New for every load, so views can react to "new data" even when the values are equal.
    let id = UUID()
    let period: SpendingPeriod
    let points: [SpendingDataPoint]
    let total: Decimal
    let latest: [ExpenseDTO]
    let hasAnyExpenses: Bool

    nonisolated init(period: SpendingPeriod, points: [SpendingDataPoint], total: Decimal,
                     latest: [ExpenseDTO], hasAnyExpenses: Bool) {
        self.period = period
        self.points = points
        self.total = total
        self.latest = latest
        self.hasAnyExpenses = hasAnyExpenses
    }

    /// Same data under a new id and period. Used when a load fails so the chart can still be shown.
    nonisolated func retagged(for period: SpendingPeriod) -> OverviewSnapshot {
        OverviewSnapshot(period: period, points: points, total: total, latest: latest, hasAnyExpenses: hasAnyExpenses)
    }
}

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
}
