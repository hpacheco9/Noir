//
//  AddExpenseIntent.swift
//  NOIR
//

import AppIntents
import Foundation
import SwiftData

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "app_intent.title"
    static var description = IntentDescription("app_intent.description")
    static var openAppWhenRun = false

    @Parameter(title: "app_intent.amount", requestValueDialog: "app_intent.amount_prompt")
    var amount: Double

    @Parameter(title: "app_intent.name", requestValueDialog: "app_intent.name_prompt")
    var name: String

    /// Optional: no category saves as Other. A deleted or unknown category is resolved by `entities(for:)` into a
    /// stand-in that keeps its id, and `CategoryCatalog.resolvedKey` then falls back to Other.
    @Parameter(
        title: LocalizedStringResource("app_intent.category", table: "AppIntents"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("app_intent.category_prompt", table: "AppIntents")
        )
    )
    var category: ExpenseCategoryEntity?

    @Parameter(title: "app_intent.date", default: .now)
    var date: Date

    @Parameter(title: "app_intent.note", default: "")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw AddExpenseIntentError.invalidAmount
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AddExpenseIntentError.emptyName
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let modelContext = ModelContext(NOIRApp.sharedModelContainer)
        let expense = Expense(
            amount: amount,
            name: trimmedName,
            date: date,
            category: .other,
            expenseDescription: trimmedNote,
            createdAt: .now
        )
        expense.categoryRawValue = CategoryCatalog.resolvedKey(category?.id, in: modelContext)

        modelContext.insert(expense)
        try modelContext.save()

        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        try? await NotificationService.shared.notifyExpenseAdded(name: trimmedName, amount: amount)

        return .result(
            dialog: IntentDialog(L10n.AppIntent.expenseSaved)
        )
    }
}

enum AddExpenseIntentError: LocalizedError {
    case invalidAmount
    case emptyName

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            String(localized: L10n.AppIntent.invalidAmount)
        case .emptyName:
            String(localized: L10n.AppIntent.emptyName)
        }
    }
}

struct NOIRShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Record expense in \(.applicationName)"
            ],
            shortTitle: "app_intent.title",
            systemImageName: "plus.circle.fill"
        )
    }
}
