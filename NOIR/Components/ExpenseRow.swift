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
        HStack(spacing: 10) {
            Image(systemName: expense.category.icon)
                .font(.headline)
                .foregroundStyle(expense.category.color)
                .frame(width: 40, height: 40)
                .background(expense.category.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 10) {
                Text(expense.name)
                    .lineLimit(1)
                    .font(.headline)

                Text(expense.category.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(-expense.amount, format: .currency(code: currencyCode))
                    .font(.headline)

                Text(expense.date, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}
