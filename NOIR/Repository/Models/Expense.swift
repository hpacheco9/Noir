//
//  Expense.swift
//  NOIR
//

import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var name: String
    var date: Date
    var categoryRawValue: String
    var expenseDescription: String
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

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
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
