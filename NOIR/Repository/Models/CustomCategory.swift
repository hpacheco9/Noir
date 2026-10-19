//
//  CustomCategory.swift
//  NOIR
//

import Foundation
import SwiftData

/// A user-defined expense category. Expenses reference it through `Expense.categoryRawValue == "custom:<id>"`
/// (see `CategoryInfo.key(forCustomID:)`), so `Expense` itself needs no schema change.
@Model
final class CustomCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    /// SF Symbol name (one of `AssetName.CategorySymbols.all`).
    var symbol: String
    /// `CategoryColor.rawValue`.
    var colorRawValue: String
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        colorRawValue: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorRawValue = colorRawValue
        self.createdAt = createdAt
    }
}
