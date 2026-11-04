//
//  DueRecurringRow.swift
//  NOIR
//

import SwiftUI

struct DueRecurringRow: View {
    let recurring: RecurringExpenseDTO
    let isBusy: Bool
    let onAdd: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ExpenseRowLabel(
                category: recurring.categoryInfo,
                title: recurring.name,
                subtitle: String(localized: L10n.Recurring.due(date: recurring.nextDueDate.formatted(.dateTime.day().month(.abbreviated)))),
                amount: recurring.amount
            )
            .accessibilityElement(children: .combine)
            .accessibilityActions {
                Button(String(localized: L10n.Recurring.add), action: onAdd)
                Button(String(localized: L10n.Recurring.skip), action: onSkip)
            }

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
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
