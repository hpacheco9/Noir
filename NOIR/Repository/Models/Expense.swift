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
    var isRecurring: Bool = false
    var recurrenceDay: Int = 1
    var recurrenceSeriesID: UUID?
    var isRecurrenceTemplate: Bool = false
    var recurrenceOccurrenceKey: String?
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
        isRecurring: Bool = false,
        recurrenceDay: Int? = nil,
        recurrenceSeriesID: UUID? = nil,
        isRecurrenceTemplate: Bool = false,
        recurrenceOccurrenceKey: String? = nil,
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
        self.isRecurring = isRecurring
        self.recurrenceDay = recurrenceDay ?? Calendar.current.component(.day, from: date)
        self.recurrenceSeriesID = recurrenceSeriesID
        self.isRecurrenceTemplate = isRecurrenceTemplate
        self.recurrenceOccurrenceKey = recurrenceOccurrenceKey
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
