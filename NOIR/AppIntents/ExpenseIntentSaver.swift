//
//  ExpenseIntentSaver.swift
//  NOIR
//

import Foundation
import SwiftData

enum ExpenseIntentSaver {
    // Intents read the cache the app keeps in step with RevenueCat: they may run offline, or before the app has
    // answered. The system asks for required parameters before perform(), so the earliest check is the summary prompt.
    static func requireAccess(defaults: UserDefaults? = MonthTotalSnapshot.sharedDefaults) throws {
        guard ProAccess.isGranted(in: defaults) else { throw AddExpenseIntentError.subscriptionRequired }
    }

    static func save(
        name: String,
        amount: Double,
        date: Date,
        categoryKey: String,
        note: String,
        card: String
    ) async throws {
        try requireAccess()
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
        // Keeps the cache honest for the next run (a renewal, a lapse); an offline failure keeps what it had.
        async let access: Void = PurchaseStore.shared.refreshAccess()
        await WidgetSnapshotPublisher.publish()
        try? await NotificationService.shared.notifyExpenseAdded(name: name, amount: amount)
        await access
    }
}
