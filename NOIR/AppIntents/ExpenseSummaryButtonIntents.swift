//
//  ExpenseSummaryButtonIntents.swift
//  NOIR
//

import AppIntents
import Foundation

struct ToggleSummaryListIntent: AppIntent {
    static let title = LocalizedStringResource("app_intent.summary.toggle_list", table: "AppIntents")
    static let isDiscoverable = false

    @Parameter var list: String

    init() {}
    init(_ list: ExpenseSummaryDraft.List) { self.list = list.rawValue }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let list = ExpenseSummaryDraft.List(rawValue: list) {
            ExpenseSummaryDraft.update { $0.toggle(list) }
        }
        return .result()
    }
}

struct SelectSummaryCategoryIntent: AppIntent {
    static let title = LocalizedStringResource("app_intent.summary.change_category", table: "AppIntents")
    static let isDiscoverable = false

    @Parameter var key: String
    @Parameter var name: String

    init() {}
    init(key: String, name: String) {
        self.key = key
        self.name = name
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        ExpenseSummaryDraft.update { $0.selectCategory(key: key, name: name) }
        return .result()
    }
}

struct SelectSummaryCardIntent: AppIntent {
    static let title = LocalizedStringResource("app_intent.summary.change_card", table: "AppIntents")
    static let isDiscoverable = false

    // An empty String parameter can read as unset, so "No card" travels as the entity's sentinel id.
    @Parameter var card: String

    init() {}
    init(card: String) { self.card = card.isEmpty ? ExpenseCardEntity.noCardID : card }

    @MainActor
    func perform() async throws -> some IntentResult {
        ExpenseSummaryDraft.update { $0.selectCard(ExpenseCardEntity(id: card).name) }
        return .result()
    }
}
