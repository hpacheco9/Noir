//
//  SpendingEntry.swift
//  NOIR
//

import Foundation

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
