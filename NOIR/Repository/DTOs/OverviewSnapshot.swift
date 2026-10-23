//
//  OverviewSnapshot.swift
//  NOIR
//

import Foundation

/// Everything the home screen shows for one selected period, computed off the main thread.
nonisolated struct OverviewSnapshot: Sendable, Identifiable {
    /// New for every load, so views can react to "new data" even when the values are equal.
    let id = UUID()
    let period: SpendingPeriod
    let points: [SpendingDataPoint]
    let total: Decimal
    let latest: [ExpenseDTO]
    let hasAnyExpenses: Bool
    /// Total of the whole period before `period`; `nil` for All Time.
    let previousTotal: Decimal?
    /// Total of the current calendar month, whatever `period` is (the budget is monthly).
    let monthTotal: Decimal

    nonisolated init(period: SpendingPeriod, points: [SpendingDataPoint], total: Decimal,
                     latest: [ExpenseDTO], hasAnyExpenses: Bool,
                     previousTotal: Decimal? = nil, monthTotal: Decimal = 0) {
        self.period = period
        self.points = points
        self.total = total
        self.latest = latest
        self.hasAnyExpenses = hasAnyExpenses
        self.previousTotal = previousTotal
        self.monthTotal = monthTotal
    }

    /// Same data under a new id and period. Used when a load fails so the chart can still be shown.
    /// The comparison belongs to the old period, so it is dropped.
    nonisolated func retagged(for period: SpendingPeriod) -> OverviewSnapshot {
        OverviewSnapshot(
            period: period, points: points, total: total, latest: latest, hasAnyExpenses: hasAnyExpenses,
            previousTotal: nil, monthTotal: monthTotal
        )
    }
}
