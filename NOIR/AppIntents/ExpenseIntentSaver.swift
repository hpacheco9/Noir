//
//  ExpenseIntentSaver.swift
//  NOIR
//

import Foundation
import SwiftData

enum ExpenseIntentSaver {
    static func save(
        name: String,
        amount: Double,
        date: Date,
        categoryKey: String,
        note: String,
        card: String
    ) async throws {
        let modelContext = ModelContext(NOIRApp.sharedModelContainer)
        let expense = Expense(
            amount: amount,
            name: name,
            date: date,
            category: .food,
            expenseDescription: note,
            card: card,
            createdAt: .now
        )
        expense.categoryRawValue = CategoryCatalog.resolvedKey(categoryKey, in: modelContext)

        modelContext.insert(expense)
        try modelContext.save()
        SavedCards.remember(card)

        ReviewPromptStore().recordCreatedExpense()

        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        await WidgetSnapshotPublisher.publish()
        try? await NotificationService.shared.notifyExpenseAdded(name: name, amount: amount)
        await ExpenseRepositoryProvider(container: NOIRApp.sharedModelContainer).checkBudget()
    }
}
