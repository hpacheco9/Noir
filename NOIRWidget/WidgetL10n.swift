//
//  WidgetL10n.swift
//  NOIR
//

import Foundation

enum L10n {
    static let displayName: LocalizedStringResource = "widget.month_total.display_name"
    static let description: LocalizedStringResource = "widget.month_total.description"
    static let title: LocalizedStringResource = "widget.month_total.title"

    static func left(_ amount: String) -> LocalizedStringResource {
        "widget.month_total.left \(amount)"
    }

    enum AddExpenseControl {
        static let displayName: LocalizedStringResource = "widget.add_expense.display_name"
        static let description: LocalizedStringResource = "widget.add_expense.description"
    }
}
