//
//  ExpenseFormFields.swift
//  NOIR
//

import SwiftUI

/// The list rows of Add and Edit Expense: amount, name, date, category, card and note.
struct ExpenseFormFields: View {
    @Binding var form: ExpenseForm
    let categories: [CategoryInfo]
    let cards: [String]

    @State private var isNewCard = false

    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        let amountStyle = CurrencyPreference.amountInputStyle(for: currencyCode)
        TextField(amountStyle.format(0), value: $form.amount, format: amountStyle)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .font(.system(size: 48, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(L10n.AddExpenseView.amountAccessibilityLabel))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)

        Section(String(localized: L10n.AddExpenseView.expenseSection)) {
            Label {
                TextField(String(localized: L10n.AddExpenseView.name), text: $form.name)
                    .textInputAutocapitalization(.sentences)
            } icon: {
                fieldIcon(AssetName.System.title)
            }
        }

        Section(String(localized: L10n.AddExpenseView.detailsSection)) {
            DatePicker(selection: $form.date, displayedComponents: .date) {
                Label {
                    Text(L10n.AddExpenseView.date)
                } icon: {
                    fieldIcon(AssetName.System.calendar)
                }
            }

            Picker(selection: $form.category) {
                ForEach(categories) { category in
                    Label {
                        Text(category.title)
                    } icon: {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                    }
                    .tag(category.key)
                }
            } label: {
                Label {
                    Text(L10n.AddExpenseView.category)
                } icon: {
                    fieldIcon(AssetName.System.categories)
                }
            }
            .pickerStyle(.menu)

            Picker(selection: Binding<String?>(
                get: { isNewCard ? nil : form.card },
                set: { choice in
                    isNewCard = choice == nil
                    form.card = choice ?? ""
                }
            )) {
                if cards.isEmpty || (form.card.isEmpty && !isNewCard) {
                    Text(L10n.AddExpenseView.noCard).tag(String?.some(""))
                }
                ForEach(cards, id: \.self) { card in
                    Text(card).tag(String?.some(card))
                }
                Text(L10n.AddExpenseView.newCard).tag(String?.none)
            } label: {
                Label {
                    Text(L10n.AddExpenseView.card)
                } icon: {
                    fieldIcon(AssetName.System.card)
                }
            }
            .pickerStyle(.menu)

            if isNewCard {
                TextField(String(localized: L10n.AddExpenseView.cardNamePlaceholder), text: $form.card)
                    .textInputAutocapitalization(.words)
            }
        }

        Section(String(localized: L10n.AddExpenseView.descriptionSection)) {
            TextField(String(localized: L10n.AddExpenseView.notePlaceholder), text: $form.description, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func fieldIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .symbolVariant(.fill)
            .foregroundStyle(.secondary)
    }
}
