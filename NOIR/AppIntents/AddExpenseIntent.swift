//
//  AddExpenseIntent.swift
//  NOIR
//

import AppIntents
import Foundation
import SwiftData

enum ShortcutExpenseCategory: String, AppEnum {
    case food
    case transport
    case home
    case leisure
    case health
    case clothing
    case other

    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("app_intent.category", table: "AppIntents")
    )

    static var caseDisplayRepresentations: [ShortcutExpenseCategory: DisplayRepresentation] = [
        .food: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.food", table: "AppIntents")),
        .transport: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.transport", table: "AppIntents")),
        .home: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.home", table: "AppIntents")),
        .leisure: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.leisure", table: "AppIntents")),
        .health: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.health", table: "AppIntents")),
        .clothing: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.clothing", table: "AppIntents")),
        .other: DisplayRepresentation(title: LocalizedStringResource("app_intent.category.other", table: "AppIntents"))
    ]

    var expenseCategory: ExpenseCategory {
        ExpenseCategory(rawValue: rawValue) ?? .other
    }
}

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "app_intent.title"
    static var description = IntentDescription("app_intent.description")
    static var openAppWhenRun = false

    @Parameter(title: "app_intent.amount", requestValueDialog: "app_intent.amount_prompt")
    var amount: Double

    @Parameter(title: "app_intent.name", requestValueDialog: "app_intent.name_prompt")
    var name: String

    @Parameter(
        title: LocalizedStringResource("app_intent.category", table: "AppIntents"),
        default: .other,
        requestValueDialog: IntentDialog(
            LocalizedStringResource("app_intent.category_prompt", table: "AppIntents")
        )
    )
    var category: ShortcutExpenseCategory

    @Parameter(title: "app_intent.date", default: .now)
    var date: Date

    @Parameter(title: "app_intent.note", default: "")
    var note: String

    @Parameter(title: "app_intent.recurring", default: false)
    var isRecurring: Bool

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
            category: category.expenseCategory,
            expenseDescription: trimmedNote,
            isRecurring: isRecurring,
            recurrenceDay: Calendar.current.component(.day, from: date),
            recurrenceSeriesID: isRecurring ? UUID() : nil,
            isRecurrenceTemplate: isRecurring
        )

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
