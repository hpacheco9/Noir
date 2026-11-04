//
//  RecurringExpenseDTO.swift
//  NOIR
//

import Foundation

nonisolated struct RecurringExpenseDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Double
    let categoryInfo: CategoryInfo
    let card: String
    let note: String
    let frequency: RecurrenceFrequency
    let startDate: Date
    let nextDueDate: Date

    nonisolated init(_ recurring: RecurringExpense, categories: [String: CategoryInfo]) {
        self.id = recurring.id
        self.name = recurring.name
        self.amount = recurring.amount
        self.categoryInfo = categories[recurring.categoryRawValue] ?? categories[ExpenseCategory.food.rawValue] ?? CategoryInfo.food
        self.card = recurring.card
        self.note = recurring.note
        self.frequency = recurring.frequency
        self.startDate = recurring.startDate
        self.nextDueDate = recurring.nextDueDate
    }
}
