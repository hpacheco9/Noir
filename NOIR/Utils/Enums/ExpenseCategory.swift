//
//  ExpenseCategory.swift
//  NOIR
//
//  Created by Henrique Pacheco on 25/07/2026.
//

import Foundation
import SwiftUI

nonisolated enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food
    case transport
    case home
    case leisure
    case health
    /// Stored as "clothing" (its former name) so existing expenses and saved Shortcuts keep resolving.
    case shopping = "clothing"
    case other

    var id: Self { self }

    @MainActor var title: String {
        switch self {
        case .food: String(localized: L10n.ExpenseCategory.food)
        case .transport: String(localized: L10n.ExpenseCategory.transport)
        case .home: String(localized: L10n.ExpenseCategory.home)
        case .leisure: String(localized: L10n.ExpenseCategory.leisure)
        case .health: String(localized: L10n.ExpenseCategory.health)
        case .other: String(localized: L10n.ExpenseCategory.other)
        case .shopping: String(localized: L10n.ExpenseCategory.shopping)
        }
    }

    var icon: String {
        switch self {
        case .food: AssetName.ExpenseCategory.food
        case .transport: AssetName.ExpenseCategory.transport
        case .home: AssetName.ExpenseCategory.home
        case .leisure: AssetName.ExpenseCategory.leisure
        case .health: AssetName.ExpenseCategory.health
        case .other: AssetName.ExpenseCategory.other
        case .shopping: AssetName.ExpenseCategory.shopping
        }
    }

    var colorKey: CategoryColor {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .home: .indigo
        case .leisure: .purple
        case .health: .red
        case .other: .green
        case .shopping: .yellow
        }
    }

    var color: Color { colorKey.color }
}

struct CategorySpending: Identifiable {
    let category: ExpenseCategory
    let amount: Decimal

    var id: ExpenseCategory { category.id }
}
