//
//  DueRecurringRow.swift
//  NOIR
//

import SwiftUI

// Add inserts the due occurrence as an expense, Skip moves on to its next date.
struct DueRecurringRow: View {
    let recurring: RecurringExpenseDTO
    let isBusy: Bool
    let onAdd: () -> Void
    let onSkip: () -> Void

    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: recurring.categoryInfo.icon)
                    .font(.headline)
                    .foregroundStyle(recurring.categoryInfo.color)
                    .frame(width: 40, height: 40)
                    .background(recurring.categoryInfo.color.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(recurring.name)
                        .lineLimit(1)
                        .font(.headline)

                    Text(L10n.Recurring.due(date: recurring.nextDueDate.formatted(.dateTime.day().month(.abbreviated))))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(verbatim: CurrencyPreference.string(for: recurring.amount, code: currencyCode))
                    .font(.headline)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Button(action: onSkip) {
                    Text(L10n.Recurring.skip)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                Button(action: onAdd) {
                    Text(L10n.Recurring.add)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .tint(.primary)
                .buttonStyle(.glassProminent)
            }
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }
}
