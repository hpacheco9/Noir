//
//  Expense.swift
//  NOIR
//

import Foundation
import SwiftData

@Model
final class Expense {
    // `date`: Home reads are range scans on it. `createdAt`: every overview delta asks for
    // `createdAt > watermark`, and a full recompute reads the newest `createdAt`; both would otherwise scan the table.
    #Index<Expense>([\.date], [\.createdAt])

    @Attribute(.unique) var id: UUID
    var amount: Double
    var name: String
    var date: Date
    var categoryRawValue: String
    var expenseDescription: String
    /// When the row was inserted (never edited). The default is what rows from before this property get on migration.
    /// Overview memos use it, not `date`, to find "new since last time": the Shortcut can add past-dated expenses.
    var createdAt: Date = Date.distantPast
    /// Name of the card that paid; empty = no card.
    var card: String = ""

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        name: String,
        date: Date,
        category: ExpenseCategory,
        expenseDescription: String = "",
        card: String = "",
        createdAt: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.name = name
        self.date = date
        self.categoryRawValue = category.rawValue
        self.expenseDescription = expenseDescription
        self.card = card
        self.createdAt = createdAt
    }
}
