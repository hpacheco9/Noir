//
//  ExpenseViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftData

struct ExpenseLocation: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var name: String
}

@MainActor
@Observable
final class ExpenseViewModel {

    var amount = Decimal.zero
    var name = ""
    var date = Date.now
    var category: ExpenseCategory = .other
    var description = ""
    var isRecurring = false
    var location: ExpenseLocation?
    
    var isEditing: Bool = false
    
    let repository: ExpenseRepository
    
    private var editingExpense: ExpenseDTO?
    
    var title: String { isEditing ? String(localized: L10n.AddExpenseView.editTitle) : String(localized: L10n.AddExpenseView.createTitle) }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }
    
    init(model: ModelContainer) {
        self.repository = .init(modelContainer: model)
    }

    func save() async throws {
        guard canSave else { return }

        try await repository.save(
            id: editingExpense?.id,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            category: category,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            isRecurring: isRecurring,
            recurrenceDay: Calendar.current.component(.day, from: date),
            latitude: location?.latitude,
            longitude: location?.longitude,
            locationName: location?.name
        )
        reset()
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
   
    }

    func delete() async throws {
        guard let id = editingExpense?.id else { return }

        try await repository.delete(id: id)
        reset()
        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
    }

    func configure(with expense: ExpenseDTO?) {
        guard let expense else {
            reset()
            return
        }

        editingExpense = expense
        amount = Decimal(expense.amount)
        name = expense.name
        date = expense.date
        category = expense.category
        description = expense.description
        isRecurring = expense.isRecurring
        if let latitude = expense.latitude, let longitude = expense.longitude {
            location = ExpenseLocation(latitude: latitude, longitude: longitude, name: expense.locationName ?? "")
        } else {
            location = nil
        }
        
        isEditing = true
    }
    
    func reset() {
        amount = 0
        name = ""
        category = .other
        description = ""
        isRecurring = false
        location = nil
        date = .now
        
        isEditing = false
        
       editingExpense = nil
    }
}
