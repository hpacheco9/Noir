//
//  ExpenseSummarySnippet.swift
//  NOIR
//

import AppIntents
import SwiftData
import SwiftUI


struct ExpenseSummarySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "app_intent.summary.snippet_title"
    static let isDiscoverable = false

    @Parameter var name: String
    @Parameter var amount: Double
    @Parameter var date: Date
    @Parameter var categoryName: String
    @Parameter var card: String

    init() {}

    init(name: String, amount: Double, categoryName: String, card: String, date: Date) {
        self.name = name
        self.amount = amount
        self.categoryName = categoryName
        self.card = card
        self.date = date
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let code = UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
        let draft = ExpenseSummaryDraft.load()
        let selectedCard = draft?.card ?? card
        let context = ModelContext(NOIRApp.sharedModelContainer)
        var categories: [CategoryInfo] = []
        var cards: [String] = []
        switch draft?.expanded {
        case .category:
            categories = (try? CategoryInfo.all(in: context)) ?? []
        case .card:
            cards = (try? SavedCards.fetch(in: context)) ?? []
            // A card typed in the Shortcut isn't saved yet.
            if !selectedCard.isEmpty, !cards.contains(selectedCard) { cards.insert(selectedCard, at: 0) }
        case nil:
            break
        }
        return .result(
            view: ExpenseSummaryView(
                amount: CurrencyPreference.string(for: amount, code: code),
                name: name,
                categoryKey: draft?.categoryKey,
                categoryName: draft?.categoryName ?? categoryName,
                card: selectedCard,
                date: date,
                expanded: draft?.expanded,
                categories: categories,
                cards: cards
            )
        )
    }
}
