//
//  RecurringExpense.swift
//  NOIR
//

import Foundation
import SwiftData

/// A template for an expense that repeats. Due occurrences are never added on their own: the user confirms each one.
/// Every property has a default so the store migrates lightweight.
@Model
final class RecurringExpense {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    /// Same keys as `Expense.categoryRawValue`.
    var categoryRawValue: String = ExpenseCategory.food.rawValue
    var card: String = ""
    var note: String = ""
    var createdAt: Date = Date.now
    var frequencyRawValue: String = RecurrenceFrequency.monthly.rawValue
    /// Occurrence 0. Every date is counted from it (see `RecurrenceFrequency.occurrence`).
    var startDate: Date = Date.now
    var nextDueDate: Date = Date.now

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        categoryRawValue: String,
        card: String = "",
        note: String = "",
        frequency: RecurrenceFrequency,
        startDate: Date,
        nextDueDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryRawValue = categoryRawValue
        self.card = card
        self.note = note
        self.frequencyRawValue = frequency.rawValue
        self.startDate = startDate
        self.nextDueDate = nextDueDate
        self.createdAt = createdAt
    }
}
