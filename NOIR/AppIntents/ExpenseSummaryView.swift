//
//  ExpenseSummaryView.swift
//  NOIR
//

import AppIntents
import SwiftUI

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
