//
//  ExpenseRow.swift
//  NOIR
//
//  Created by Henrique Pacheco on 25/07/2026.
//

import SwiftUI

struct ExpenseRow: View {
    let expense: ExpenseDTO
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    
    let action: () -> Void

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(L10n.AddExpenseView.editHint))
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: expense.categoryInfo.icon)
                .font(.headline)
                .foregroundStyle(expense.categoryInfo.color)
                .frame(width: 40, height: 40)
                .background(expense.categoryInfo.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(expense.name)
                    .lineLimit(1)
                    .font(.headline)

                Text(expense.categoryInfo.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(verbatim: CurrencyPreference.string(for: expense.amount, code: currencyCode))
                    .font(.headline)

                Text(expense.date, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
