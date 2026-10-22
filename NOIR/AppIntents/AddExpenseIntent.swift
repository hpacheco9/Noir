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

    @Parameter(title: "app_intent.name", requestValueDialog: "app_intent.name_prompt")
    var name: String

    @Parameter(title: "app_intent.amount", requestValueDialog: "app_intent.amount_prompt")
    var amount: Double
    
    @Parameter(title: "app_intent.date", requestValueDialog: "app_intent.date_prompt")
    var date: Date

    @Parameter(
        title: LocalizedStringResource("app_intent.category", table: "AppIntents"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("app_intent.category_prompt", table: "AppIntents")
        )
    )
    var category: ExpenseCategoryEntity

    @Parameter(
        title: LocalizedStringResource("app_intent.card", table: "AppIntents"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("app_intent.card_prompt", table: "AppIntents")
        )
    )
    var card: ExpenseCardEntity

    @Parameter(title: "app_intent.note", default: "")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard Expense.isValidAmount(amount) else {
            throw AddExpenseIntentError.invalidAmount
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AddExpenseIntentError.emptyName
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var categoryKey = category.id
        var trimmedCard = card.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if IntentSummaryPreference.isEnabled() {
            ExpenseSummaryDraft(categoryKey: categoryKey, categoryName: category.name, card: trimmedCard).save()
            defer { ExpenseSummaryDraft.clear() }
            let code = UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
            try await requestConfirmation(
                actionName: .custom(
                    acceptLabel: L10n.AppIntent.save,
                    acceptAlternatives: [],
                    denyLabel: L10n.AppIntent.cancel,
                    denyAlternatives: []
                ),
                dialog: IntentDialog(
                    full: L10n.AppIntent.confirmSpoken(
                        amount: CurrencyPreference.string(for: amount, code: code),
                        name: trimmedName
                    ),
                    supporting: L10n.AppIntent.summaryHeader
                ),
                snippetIntent: ExpenseSummarySnippetIntent(
                    name: trimmedName,
                    amount: amount,
                    categoryName: category.name,
                    card: trimmedCard,
                    date: date
                )
            )
            if let draft = ExpenseSummaryDraft.load() {
                categoryKey = draft.categoryKey
                trimmedCard = draft.card
            }
        }

        let modelContext = ModelContext(NOIRApp.sharedModelContainer)
        let expense = Expense(
            amount: amount,
            name: trimmedName,
            date: date,
            category: .other,
            expenseDescription: trimmedNote,
            card: trimmedCard,
            createdAt: .now
        )
        expense.categoryRawValue = CategoryCatalog.resolvedKey(categoryKey, in: modelContext)

        modelContext.insert(expense)
        try modelContext.save()
        SavedCards.remember(trimmedCard)

        // Counts toward the review prompt, but never asks: an intent has no UI. Home asks at its next eligible moment.
        ReviewPromptStore().recordCreatedExpense()

        NotificationCenter.default.post(name: .expensesDidChange, object: nil)
        await WidgetSnapshotPublisher.publish()
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
