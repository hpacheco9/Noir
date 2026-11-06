//
//  RecurringExpense.swift
//  NOIR
//

import Foundation
import SwiftData

@Model
final class RecurringExpense {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var categoryRawValue: String = ExpenseCategory.food.rawValue
    var card: String = ""
    var note: String = ""
    var frequencyRawValue: String = RecurrenceFrequency.monthly.rawValue
    var startDate: Date = Date.now
    var nextDueDate: Date = Date.now

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }

    nonisolated static func isDue(_ nextDueDate: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        nextDueDate < (calendar.dateInterval(of: .day, for: now)?.end ?? now)
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
        nextDueDate: Date
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
    }
}
