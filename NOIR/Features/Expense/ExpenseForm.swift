//
//  ExpenseForm.swift
//  NOIR
//

import Foundation
import SwiftData

/// The fields Add and Edit Expense both edit.
nonisolated struct ExpenseForm: Sendable {
    var amount = Decimal.zero
    var name = ""
    var date = Date.now
    /// `CategoryInfo.key` of the selected category (built-in raw value or `custom:<uuid>`).
    var category: String = ExpenseCategory.other.rawValue
    var description = ""
    var card = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    /// The amount as it is stored. Through the description: `NSDecimalNumber.doubleValue` turns 19.99 into
    /// 19.990000000000002.
    var amountValue: Double {
        Double(amount.description) ?? NSDecimalNumber(decimal: amount).doubleValue
    }

    /// The values as they are stored: name, description and card trimmed.
    var trimmed: ExpenseForm {
        var form = self
        form.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        form.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        form.card = card.trimmingCharacters(in: .whitespacesAndNewlines)
        return form
    }
}

extension ExpenseRepositoryProvider {
    /// Inserts (`id == nil`) or updates an expense with the form's values.
    func save(_ form: ExpenseForm, id: PersistentIdentifier?) async throws {
        try await perform {
            try await $0.save(
                id: id,
                amount: form.amountValue,
                name: form.name,
                date: form.date,
                categoryKey: form.category,
                description: form.description,
                card: form.card
            )
        }
    }
}
