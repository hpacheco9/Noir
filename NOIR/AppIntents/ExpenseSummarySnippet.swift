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

/// The summary's picks and open list. The controls run as separate intents, possibly in another process.
nonisolated struct ExpenseSummaryDraft: Codable, Equatable {
    enum List: String, Codable {
        case category, card
    }

    static let storageKey = "app_intent.summary_draft"

    var categoryKey: String
    var categoryName: String
    var card: String
    var expanded: List? = nil

    mutating func toggle(_ list: List) {
        expanded = expanded == list ? nil : list
    }

    mutating func selectCategory(key: String, name: String) {
        categoryKey = key
        categoryName = name
        expanded = nil
    }

    mutating func selectCard(_ name: String) {
        card = name
        expanded = nil
    }

    static func load(from defaults: UserDefaults = .standard) -> ExpenseSummaryDraft? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ExpenseSummaryDraft.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    static func update(in defaults: UserDefaults = .standard, _ change: (inout ExpenseSummaryDraft) -> Void) {
        guard var draft = load(from: defaults) else { return }
        change(&draft)
        draft.save(to: defaults)
    }
}

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

struct ExpenseSummaryView: View {
    let amount: String
    let name: String
    var categoryKey: String? = nil
    let categoryName: String
    let card: String
    let date: Date
    var expanded: ExpenseSummaryDraft.List? = nil
    var categories: [CategoryInfo] = []
    var cards: [String] = []

    var body: some View {
        VStack(spacing: 24) {
            Text(amount)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            VStack(spacing: 18) {
                row(L10n.AppIntent.summaryTitle, systemImage: AssetName.System.title) {
                    Text(name)
                }
                row(L10n.AppIntent.category, systemImage: AssetName.System.categories) {
                    listButton(Text(categoryName), list: .category)
                }
                if expanded == .category {
                    options {
                        ForEach(categories, id: \.key) { info in
                            option(Text(info.title), isSelected: info.key == categoryKey) {
                                SelectSummaryCategoryIntent(key: info.key, name: info.title)
                            }
                        }
                    }
                }
                
                row(L10n.AppIntent.card, systemImage: AssetName.System.card) {
                    listButton(cardTitle(card), list: .card)
                }
                
                if expanded == .card {
                    options {
                        ForEach([""] + cards, id: \.self) { option in
                            self.option(cardTitle(option), isSelected: option == card) {
                                SelectSummaryCardIntent(card: option)
                            }
                        }
                    }
                }
                row(L10n.AppIntent.date, systemImage: AssetName.System.calendar) {
                    Text(date.formatted(date: .numeric, time: .omitted))
                }
            }
        }
    }

    private func cardTitle(_ card: String) -> Text {
        card.isEmpty ? Text(ExpenseCardEntity.noCardTitle) : Text(card)
    }

    private func listButton(_ value: Text, list: ExpenseSummaryDraft.List) -> some View {
        Button(intent: ToggleSummaryListIntent(list)) {
            HStack(spacing: 4) {
                value
                Image(systemName: AssetName.System.picker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func options(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 14) {
            content()
        }
        .padding(.leading, 28)
    }

    private func option(_ title: Text, isSelected: Bool, intent: () -> some AppIntent) -> some View {
        Button(intent: intent()) {
            HStack {
                title
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: AssetName.System.checkmark)
                        .font(.footnote.weight(.semibold))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func row(
        _ label: LocalizedStringResource,
        systemImage: String,
        @ViewBuilder value: () -> some View
    ) -> some View {
        HStack {
            Label {
                Text(label)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: systemImage)
                    .symbolVariant(.fill)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            value()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ExpenseSummaryView(
        amount: "12,50 €", name: "Lunch", categoryName: "Food", card: "Visa", date: .now,
        expanded: .card, cards: ["Visa", "Amex"]
    )
}
