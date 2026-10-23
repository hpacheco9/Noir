//
//  ExpenseDTO.swift
//  NOIR
//

import Foundation
import SwiftData

struct ExpenseDTO: Sendable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let categoryInfo: CategoryInfo
    let amount: Double
    let date: Date
    let description: String
    let card: String

    nonisolated init(_ expense: Expense, categories: [String: CategoryInfo]) {
        self.id = expense.persistentModelID
        self.name = expense.name
        self.categoryInfo = categories[expense.categoryRawValue] ?? categories[ExpenseCategory.other.rawValue] ?? CategoryInfo.other
        self.date = expense.date
        self.amount = expense.amount
        self.description = expense.expenseDescription
        self.card = expense.card
    }
}

extension ExpenseDTO: Equatable {}
