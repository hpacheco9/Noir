//
//  Coordinator+AddExpense.swift
//  NOIR
//

import SwiftUI

extension Coordinator {
    func presentAddExpense() {
        present(MainRoutes.addExpense(), mode: .percentage(0.85))
    }

    // For the control, which can fire while Add Expense is already up. Home's "+" always presents.
    func presentAddExpenseIfNeeded() {
        guard sheet?.id != MainRoutes.addExpense().routeId else { return }
        presentAddExpense()
    }
}
