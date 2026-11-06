//
//  ExpenseRowLabel.swift
//  NOIR
//

import SwiftUI

struct ExpenseRowLabel: View {
    let category: CategoryInfo
    let title: String
    let subtitle: String
    let amount: Double
    var date: Date?

    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.headline)
                .foregroundStyle(category.color)
                .frame(width: 40, height: 40)
                .background(category.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(title)
                    .lineLimit(1)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(verbatim: CurrencyPreference.string(for: amount, code: currencyCode))
                    .font(.headline)

                if let date {
                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
