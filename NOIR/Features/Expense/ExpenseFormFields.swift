//
//  ExpenseFormFields.swift
//  NOIR
//

import SwiftUI

/// The list rows of Add and Edit Expense: amount, name, date, category and note.
struct ExpenseFormFields: View {
    @Binding var form: ExpenseForm
    let categories: [CategoryInfo]

    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        TextField(
            String(localized: L10n.AddExpenseView.amountPlaceholder),
            value: $form.amount,
            format: CurrencyPreference.amountInputStyle(for: currencyCode)
        )
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
            TextField(String(localized: L10n.AddExpenseView.name), text: $form.name)
                .textInputAutocapitalization(.sentences)
        }

        Section(String(localized: L10n.AddExpenseView.detailsSection)) {
            DatePicker(String(localized: L10n.AddExpenseView.date), selection: $form.date, displayedComponents: .date)

            Picker(String(localized: L10n.AddExpenseView.category), selection: $form.category) {
                ForEach(categories) { category in
                    Label {
                        Text(category.title)
                    } icon: {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                    }
                    .tag(category.key)
                }
            }
            .pickerStyle(.menu)
        }

        Section(String(localized: L10n.AddExpenseView.descriptionSection)) {
            TextField(String(localized: L10n.AddExpenseView.notePlaceholder), text: $form.description, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}
