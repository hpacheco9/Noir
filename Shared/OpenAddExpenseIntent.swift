//
//  OpenAddExpenseIntent.swift
//  NOIR
//

import AppIntents

struct OpenAddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "app_intent.open_add_expense"
    // Foreground: the system runs perform() in the app, not in the widget extension that hosts the control.
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        AddExpenseRequest.shared.request()
        return .result()
    }
}
