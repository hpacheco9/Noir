//
//  OpenAddExpenseIntent.swift
//  NOIR
//

import AppIntents

/// Opens NOIR on the Add Expense sheet. Compiled into the app and the widget extension (the control's action);
/// `.foreground` makes the system run `perform()` in the app process.
struct OpenAddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "app_intent.open_add_expense"
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        AddExpenseRequest.shared.request()
        return .result()
    }
}
