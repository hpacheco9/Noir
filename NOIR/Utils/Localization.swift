//
//  Localization.swift
//  NOIR
//

import Foundation

/// Centralized, feature-based localization keys.
/// Add translations in `Localizable.xcstrings` rather than scattering literals through views.
enum L10n {
    enum Shared {
        static let cancel: LocalizedStringResource = "shared.cancel"
        static let save: LocalizedStringResource = "shared.save"
        static let close: LocalizedStringResource = "shared.close"
        static let delete: LocalizedStringResource = "shared.delete"
        static let ok: LocalizedStringResource = "shared.ok"
        static let unexpectedError: LocalizedStringResource = "shared.unexpected_error"
    }

    enum MainView {
        static let title: LocalizedStringResource = "main_view.title"
        static let emptyTitle: LocalizedStringResource = "main_view.empty_title"
        static let emptyDescription: LocalizedStringResource = "main_view.empty_description"
        static let latestTransactions: LocalizedStringResource = "main_view.latest_transactions"
    }

    enum SettingsView {
        static let title: LocalizedStringResource = "settings_view.title"
    }

    enum SearchView {
        static let title: LocalizedStringResource = "search_view.title"
        static let prompt: LocalizedStringResource = "search_view.prompt"
        static let emptyTitle: LocalizedStringResource = "search_view.empty_title"
        static let emptyDescription: LocalizedStringResource = "search_view.empty_description"
    }

    enum ShortcutsView {
        static let description: LocalizedStringResource = "shortcuts_view.description"
    }

    enum PrivacyPolicyView {
        static let description: LocalizedStringResource = "privacy_policy_view.description"
    }

    enum TermsOfServiceView {
        static let description: LocalizedStringResource = "terms_of_service_view.description"
    }

    enum NoirPro {
        static let title: LocalizedStringResource = "noir_pro.title"
        static let description: LocalizedStringResource = "noir_pro.description"
        static let upgrade: LocalizedStringResource = "noir_pro.upgrade"
    }

    enum Preferences {
        static let title: LocalizedStringResource = "preferences.title"
        static let currency: LocalizedStringResource = "preferences.currency"
        static let shortcuts: LocalizedStringResource = "preferences.shortcuts"
    }

    enum Profile {
        static let title: LocalizedStringResource = "profile.title"
        static let name: LocalizedStringResource = "profile.name"
        static let description: LocalizedStringResource = "profile.description"
    }

    enum Legal {
        static let title: LocalizedStringResource = "legal.title"
        static let privacyPolicy: LocalizedStringResource = "legal.privacy_policy"
        static let termsOfService: LocalizedStringResource = "legal.terms_of_service"
    }

    enum AddExpenseView {
        static let createTitle: LocalizedStringResource = "add_expense.create_title"
        static let editTitle: LocalizedStringResource = "add_expense.edit_title"
        static let amountPlaceholder: LocalizedStringResource = "add_expense.amount_placeholder"
        static let amountAccessibilityLabel: LocalizedStringResource = "add_expense.amount_accessibility_label"
        static let expenseSection: LocalizedStringResource = "add_expense.expense_section"
        static let name: LocalizedStringResource = "add_expense.name"
        static let detailsSection: LocalizedStringResource = "add_expense.details_section"
        static let date: LocalizedStringResource = "add_expense.date"
        static let category: LocalizedStringResource = "add_expense.category"
        static let descriptionSection: LocalizedStringResource = "add_expense.description_section"
        static let notePlaceholder: LocalizedStringResource = "add_expense.note_placeholder"
        static let saveErrorTitle: LocalizedStringResource = "add_expense.save_error_title"
        static let closeAccessibilityLabel: LocalizedStringResource = "add_expense.close_accessibility_label"
        static let saveAccessibilityLabel: LocalizedStringResource = "add_expense.save_accessibility_label"
    }

    enum ExpenseDeletion {
        static let title: LocalizedStringResource = "expense_deletion.title"
        static let message: LocalizedStringResource = "expense_deletion.message"
    }

    enum Notification {
        static let expenseAddedTitle: LocalizedStringResource = "notification.expense_added_title"
    }

    enum ExpenseCategory {
        static let food: LocalizedStringResource = "expense_category.food"
        static let transport: LocalizedStringResource = "expense_category.transport"
        static let home: LocalizedStringResource = "expense_category.home"
        static let leisure: LocalizedStringResource = "expense_category.leisure"
        static let health: LocalizedStringResource = "expense_category.health"
        static let clothing: LocalizedStringResource = "expense_category.clothing"
        static let other: LocalizedStringResource = "expense_category.other"
    }

    enum SpendingPeriod {
        static let today: LocalizedStringResource = "spending_period.today"
        static let week: LocalizedStringResource = "spending_period.week"
        static let month: LocalizedStringResource = "spending_period.month"
        static let allTime: LocalizedStringResource = "spending_period.all_time"
    }

    enum SpendingOverview {
        static let totalSpent: LocalizedStringResource = "spending_overview.total_spent"
        static let chartPeriod: LocalizedStringResource = "spending_overview.chart_period"
        static let chartAmount: LocalizedStringResource = "spending_overview.chart_amount"
    }

    enum AppIntent {
        static let title: LocalizedStringResource = "app_intent.title"
        static let description: LocalizedStringResource = "app_intent.description"
        static let amount: LocalizedStringResource = "app_intent.amount"
        static let amountPrompt: LocalizedStringResource = "app_intent.amount_prompt"
        static let name: LocalizedStringResource = "app_intent.name"
        static let namePrompt: LocalizedStringResource = "app_intent.name_prompt"
        static let date: LocalizedStringResource = "app_intent.date"
        static let note: LocalizedStringResource = "app_intent.note"
        static let invalidAmount: LocalizedStringResource = "app_intent.invalid_amount"
        static let emptyName: LocalizedStringResource = "app_intent.empty_name"
        static let expenseSaved: LocalizedStringResource = "app_intent.expense_saved"
        static let shortcutPhraseAdd: LocalizedStringResource = "app_intent.shortcut_phrase_add"
        static let shortcutPhraseRecord: LocalizedStringResource = "app_intent.shortcut_phrase_record"
    }
}
