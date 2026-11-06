//
//  ExpenseRow.swift
//  NOIR
//
//  Created by Henrique Pacheco on 25/07/2026.
//

import SwiftUI

struct ExpenseRow: View {
    let expense: ExpenseDTO

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ExpenseRowLabel(
                category: expense.categoryInfo,
                title: expense.name,
                subtitle: expense.categoryInfo.title,
                amount: expense.amount,
                date: expense.date
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(L10n.AddExpenseView.editHint))
    }
}
