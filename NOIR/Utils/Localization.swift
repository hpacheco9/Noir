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
        static let delete: LocalizedStringResource = "shared.delete"
        static let ok: LocalizedStringResource = "shared.ok"
        static let unexpectedError: LocalizedStringResource = "shared.unexpected_error"
    }

    enum Tab {
        static let home: LocalizedStringResource = "tab.home"
        static let dashboard: LocalizedStringResource = "tab.dashboard"
        static let search: LocalizedStringResource = "tab.search"
    }

    enum Dashboard {
        static let title: LocalizedStringResource = "dashboard.title"
        static let periodPicker: LocalizedStringResource = "dashboard.period_picker"
        static let byCategory: LocalizedStringResource = "dashboard.by_category"
        /// The slice that sums the smallest categories. Not "Other": that is a built-in category.
        static let rest: LocalizedStringResource = "dashboard.rest"
        static let emptyTitle: LocalizedStringResource = "dashboard.empty_title"
        static let emptyDescription: LocalizedStringResource = "dashboard.empty_description"
        static let chartLabel: LocalizedStringResource = "dashboard.chart_label"
        static let amount: LocalizedStringResource = "dashboard.amount"
        static let category: LocalizedStringResource = "dashboard.category"
        static let rowHint: LocalizedStringResource = "dashboard.row_hint"

        static let errorTitle: LocalizedStringResource = "dashboard.error_title"
        static let errorDescription: LocalizedStringResource = "dashboard.error_description"
        static let retry: LocalizedStringResource = "dashboard.retry"

        /// "in All others": the subtitle for a category that is collapsed into the rest slice.
        static func inRest(_ restTitle: String) -> LocalizedStringResource {
            "dashboard.in_rest \(restTitle)"
        }

        /// "€45,00, 23% of total".
        static func value(amount: String, percent: String) -> LocalizedStringResource {
            "dashboard.value \(amount) \(percent)"
        }

        /// The rest slice's value, naming the categories it sums.
        static func valueWithMembers(amount: String, percent: String, members: String) -> LocalizedStringResource {
            "dashboard.value_with_members \(amount) \(percent) \(members)"
        }

        static func announcement(period: String, total: String) -> LocalizedStringResource {
            "dashboard.announcement \(period) \(total)"
        }

        static func expenseCount(_ count: Int) -> LocalizedStringResource {
            "dashboard.expense_count \(count)"
        }
    }

    enum MainView {
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
        static let errorTitle: LocalizedStringResource = "search_view.error_title"
    }

    enum ShortcutsView {
        static let description: LocalizedStringResource = "shortcuts_view.description"
    }



    enum NoirPro {
        static let title: LocalizedStringResource = "noir_pro.title"
        static let description: LocalizedStringResource = "noir_pro.description"
        static let upgrade: LocalizedStringResource = "noir_pro.upgrade"
    }

    enum Preferences {
        static let title: LocalizedStringResource = "preferences.title"
        static let currency: LocalizedStringResource = "preferences.currency"
        static let haptics: LocalizedStringResource = "preferences.haptics"
        static let hapticsFooter: LocalizedStringResource = "preferences.haptics_footer"
        static let intentSummary: LocalizedStringResource = "preferences.intent_summary"
        static let intentSummaryFooter: LocalizedStringResource = "preferences.intent_summary_footer"
        static let shortcuts: LocalizedStringResource = "preferences.shortcuts"
    }

    enum Profile {
        static let title: LocalizedStringResource = "profile.title"
        static let name: LocalizedStringResource = "profile.name"
        static let description: LocalizedStringResource = "profile.description"
        static let nameSection: LocalizedStringResource = "profile.name_section"
        static let namePlaceholder: LocalizedStringResource = "profile.name_placeholder"
    }

    enum Categories {
        static let title: LocalizedStringResource = "categories.title"
        static let builtInSection: LocalizedStringResource = "categories.built_in_section"
        static let customSection: LocalizedStringResource = "categories.custom_section"
        static let customEmpty: LocalizedStringResource = "categories.custom_empty"
        static let add: LocalizedStringResource = "categories.add"
        static let deleteTitle: LocalizedStringResource = "categories.delete_title"
        /// "Its expenses will be moved to “Other”.", with Other's current (possibly renamed) title.
        static func deleteMessage(otherTitle: String) -> LocalizedStringResource {
            "categories.delete_message \(otherTitle)"
        }
        static let loadError: LocalizedStringResource = "categories.load_error"
        static let deleteError: LocalizedStringResource = "categories.delete_error"
        static let errorTitle: LocalizedStringResource = "categories.error_title"
    }

    enum NewCategory {
        static let title: LocalizedStringResource = "new_category.title"
        static let editTitle: LocalizedStringResource = "new_category.edit_title"
        static let restoreDefault: LocalizedStringResource = "new_category.restore_default"
        static let restoreTitle: LocalizedStringResource = "new_category.restore_title"
        static let restoreMessage: LocalizedStringResource = "new_category.restore_message"
        static let restoreDuplicateError: LocalizedStringResource = "new_category.restore_duplicate_error"
        static let namePlaceholder: LocalizedStringResource = "new_category.name_placeholder"
        static let previewPlaceholder: LocalizedStringResource = "new_category.preview_placeholder"
        static let nameSection: LocalizedStringResource = "new_category.name_section"
        static let symbolSection: LocalizedStringResource = "new_category.symbol_section"
        static let colorSection: LocalizedStringResource = "new_category.color_section"
        static let duplicateError: LocalizedStringResource = "new_category.duplicate_error"
        static let emptyError: LocalizedStringResource = "new_category.empty_error"
        static let saveError: LocalizedStringResource = "new_category.save_error"
    }

    enum CategoryColor {
        static let orange: LocalizedStringResource = "category_color.orange"
        static let blue: LocalizedStringResource = "category_color.blue"
        static let indigo: LocalizedStringResource = "category_color.indigo"
        static let purple: LocalizedStringResource = "category_color.purple"
        static let red: LocalizedStringResource = "category_color.red"
        static let green: LocalizedStringResource = "category_color.green"
        static let yellow: LocalizedStringResource = "category_color.yellow"
        static let pink: LocalizedStringResource = "category_color.pink"
        static let teal: LocalizedStringResource = "category_color.teal"
        static let brown: LocalizedStringResource = "category_color.brown"
    }

    enum Legal {
        static let title: LocalizedStringResource = "legal.title"
        static let privacyPolicy: LocalizedStringResource = "legal.privacy_policy"
        static let termsOfService: LocalizedStringResource = "legal.terms_of_service"
    }

    enum AddExpenseView {
        static let createTitle: LocalizedStringResource = "add_expense.create_title"
        static let editTitle: LocalizedStringResource = "add_expense.edit_title"
        static let editHint: LocalizedStringResource = "add_expense.edit_hint"
        static let amountAccessibilityLabel: LocalizedStringResource = "add_expense.amount_accessibility_label"
        static let expenseSection: LocalizedStringResource = "add_expense.expense_section"
        static let name: LocalizedStringResource = "add_expense.name"
        static let detailsSection: LocalizedStringResource = "add_expense.details_section"
        static let date: LocalizedStringResource = "add_expense.date"
        static let category: LocalizedStringResource = "add_expense.category"
        static let card: LocalizedStringResource = "add_expense.card"
        static let noCard: LocalizedStringResource = "add_expense.card.none"
        static let newCard: LocalizedStringResource = "add_expense.card.new"
        static let cardNamePlaceholder: LocalizedStringResource = "add_expense.card.name_placeholder"
        static let descriptionSection: LocalizedStringResource = "add_expense.description_section"
        static let notePlaceholder: LocalizedStringResource = "add_expense.note_placeholder"
        static let saveErrorTitle: LocalizedStringResource = "add_expense.save_error_title"
    }

    enum ExpenseDeletion {
        static let title: LocalizedStringResource = "expense_deletion.title"
        static let message: LocalizedStringResource = "expense_deletion.message"
    }

    enum Onboarding {
        static let getStarted: LocalizedStringResource = "onboarding.get_started"
        static let `continue`: LocalizedStringResource = "onboarding.continue"
        static let setBudget: LocalizedStringResource = "onboarding.set_budget"
        static let finishing: LocalizedStringResource = "onboarding.finishing"
        static let nameTitle: LocalizedStringResource = "onboarding.name.title"
        static let nameSubtitle: LocalizedStringResource = "onboarding.name.subtitle"
        static let nameGreeting: LocalizedStringResource = "onboarding.name.greeting"
        static let namePlaceholder: LocalizedStringResource = "onboarding.name.placeholder"
        static let notificationsTitle: LocalizedStringResource = "onboarding.notifications.title"
        static let notificationsSubtitle: LocalizedStringResource = "onboarding.notifications.subtitle"
        static let enableNotifications: LocalizedStringResource = "onboarding.notifications.enable"
        static let notNow: LocalizedStringResource = "onboarding.notifications.not_now"
        static let openSettings: LocalizedStringResource = "onboarding.notifications.open_settings"
        static let demoTitle: LocalizedStringResource = "onboarding.notifications.demo_title"
        static let demoTimestamp: LocalizedStringResource = "onboarding.notifications.demo_timestamp"
        static let welcomeTitle: LocalizedStringResource = "onboarding.welcome.title"
        static let welcomeSubtitle: LocalizedStringResource = "onboarding.welcome.subtitle"
        static let budgetTitle: LocalizedStringResource = "onboarding.budget.title"
        static let budgetSubtitle: LocalizedStringResource = "onboarding.budget.subtitle"
        static func demoAccessibilityLabel(appName: String, title: String, message: String) -> LocalizedStringResource {
            "onboarding.notifications.demo_accessibility_label \(appName) \(title) \(message)"
        }
        static func demoMessage(amount: String) -> LocalizedStringResource {
            "onboarding.notifications.demo_message \(amount)"
        }
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
        static let shopping: LocalizedStringResource = "expense_category.shopping"
        static let other: LocalizedStringResource = "expense_category.other"
    }

    enum SpendingPeriod {
        static let today: LocalizedStringResource = "spending_period.today"
        static let week: LocalizedStringResource = "spending_period.week"
        static let month: LocalizedStringResource = "spending_period.month"
        static let year: LocalizedStringResource = "spending_period.year"
        static let allTime: LocalizedStringResource = "spending_period.all_time"
    }

    enum SpendingOverview {
        static func totalSpent(for period: NOIR.SpendingPeriod) -> LocalizedStringResource {
            switch period {
            case .day: "spending_overview.total_spent.today"
            case .week: "spending_overview.total_spent.week"
            case .month: "spending_overview.total_spent.month"
            case .year: "spending_overview.total_spent.year"
            case .allTime: "spending_overview.total_spent.all_time"
            }
        }
        static let chartPeriod: LocalizedStringResource = "spending_overview.chart_period"
        static let chartAmount: LocalizedStringResource = "spending_overview.chart_amount"
    }

    enum AppIntent {
        // Title, description and parameter names are literal keys in `AddExpenseIntent` (App Intents metadata must
        // be literals), still translated in Localizable.xcstrings; only the runtime messages need constants.
        static let invalidAmount: LocalizedStringResource = "app_intent.invalid_amount"
        static let emptyName: LocalizedStringResource = "app_intent.empty_name"
        static let expenseSaved: LocalizedStringResource = "app_intent.expense_saved"
        static let summaryHeader: LocalizedStringResource = "app_intent.summary.header"
        /// "Save 12,50 € for Lunch?"
        static func confirmSpoken(amount: String, name: String) -> LocalizedStringResource {
            "app_intent.summary.spoken \(amount) \(name)"
        }
        static let summaryTitle: LocalizedStringResource = "app_intent.summary.title"
        static let category = LocalizedStringResource("app_intent.category", table: "AppIntents")
        static let card = LocalizedStringResource("app_intent.card", table: "AppIntents")
        static let date: LocalizedStringResource = "app_intent.date"
        static let save: LocalizedStringResource = "app_intent.summary.save"
        static let cancel: LocalizedStringResource = "app_intent.summary.cancel"
    }
}
