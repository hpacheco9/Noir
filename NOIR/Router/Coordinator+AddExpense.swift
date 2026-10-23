//
//  Coordinator+AddExpense.swift
//  NOIR
//

import SwiftUI

extension Coordinator {
    /// The Add Expense sheet, as presented by Home's "+" button and by the Add Expense control.
    /// Replaces any other sheet; does nothing when Add Expense is already up.
    func presentAddExpense() {
        let route = MainRoutes.addExpense()
        guard sheet?.id != route.routeId else { return }
        present(route, mode: .percentage(0.8))
    }

    func dismissModals() {
        sheet = nil
        fullScreen = nil
    }

    /// Add Expense on Home. Modals on the other tabs would cover it, so they close.
    static func openAddExpense(home: Coordinator, otherTabs: [Coordinator]) {
        otherTabs.forEach { $0.dismissModals() }
        home.presentAddExpense()
    }
}
