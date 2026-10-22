//
//  NOIRShortcuts.swift
//  NOIR
//

import AppIntents

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
