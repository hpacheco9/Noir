//
//  AddApplePayExpenseIntent.swift
//  NOIR
//

import AppIntents
import Foundation

struct AddApplePayExpenseIntent: AppIntent {
    static let title = LocalizedStringResource("apple_pay_intent.title", table: "AppIntents")
    static let description = IntentDescription(
        LocalizedStringResource("apple_pay_intent.description", table: "AppIntents")
    )
    static var openAppWhenRun = false

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) at \(\.$name) in \(\.$category) with \(\.$card)", table: "AppIntents")
    }

    @Parameter(title: LocalizedStringResource("apple_pay_intent.merchant", table: "AppIntents"))
    var name: String?

    @Parameter(title: "app_intent.amount", requestValueDialog: "app_intent.amount_prompt")
    var amount: String

    // Optional/plain text so an unattended automation never stops to ask or disambiguate (the card is text for that reason).
    @Parameter(
        title: LocalizedStringResource("app_intent.category", table: "AppIntents"),
        default: ExpenseCategoryEntity.food
    )
    var category: ExpenseCategoryEntity?

    @Parameter(title: LocalizedStringResource("app_intent.card", table: "AppIntents"))
    var card: String?

    nonisolated static func resolvedName(_ name: String?, untitled: String) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? untitled : trimmed
    }

    // Wallet's Amount is text like "-4,50 €" or "-$1,234.56". Dropping everything but digits and marks drops the sign too.
    nonisolated static func parsedAmount(_ text: String, code: String) -> Double? {
        let cleaned = String(text.filter { ($0.isASCII && $0.isNumber) || $0 == "." || $0 == "," })
        let style = CurrencyPreference.amountInputStyle(for: code)
        guard let value = try? style.parseStrategy.parse(cleaned) else { return nil }
        let amount = ExpenseForm(amount: value).amountValue
        return Expense.isValidAmount(amount) ? amount : nil
    }

    nonisolated static func resolvedCard(_ card: String?) -> String {
        card?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let code = UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
        guard let value = Self.parsedAmount(amount, code: code) else {
            throw AddExpenseIntentError.invalidAmount
        }

        try await ExpenseIntentSaver.save(
            name: Self.resolvedName(name, untitled: String(localized: L10n.AppIntent.untitled)),
            amount: value,
            date: .now,
            categoryKey: category?.id ?? ExpenseCategory.food.rawValue,
            note: "",
            card: Self.resolvedCard(card)
        )

        return .result(
            dialog: IntentDialog(L10n.AppIntent.expenseSaved)
        )
    }
}
