//
//  CategoryInfo.swift
//  NOIR
//

import Foundation
import SwiftData
import SwiftUI

/// Everything the UI needs to show a category, built-in or custom. Sendable, so the repository actor can return it.
/// `key` is what `Expense.categoryRawValue` stores: the built-in raw value, or `custom:<uuid>`.
nonisolated struct CategoryInfo: Sendable, Identifiable, Hashable {
    static let customPrefix = "custom:"

    let key: String
    /// The name the user set: a custom category's name, or a built-in's override. `nil` for a built-in that keeps
    /// its localized default title (see `title`).
    let customName: String?
    let icon: String
    let colorRawValue: String
    let isBuiltIn: Bool
    /// A built-in with a stored `BuiltInCategoryOverride`.
    let isOverridden: Bool

    var id: String { key }
    var color: Color { CategoryColor.color(forRawValue: colorRawValue) }

    /// Localized for built-ins, the stored name for custom ones. Main actor: built-in titles come from `L10n`.
    @MainActor var title: String {
        if let customName { return customName }
        return (ExpenseCategory(rawValue: key) ?? .other).title
    }

    /// The built-in this key stands for, if any.
    var builtIn: ExpenseCategory? { isBuiltIn ? ExpenseCategory(rawValue: key) : nil }

    /// The UUID of a custom category, `nil` for built-ins.
    var customID: UUID? { Self.customID(fromKey: key) }

    /// A built-in, with the user's override applied when there is one.
    init(builtIn category: ExpenseCategory, override: BuiltInCategoryOverride? = nil) {
        self.key = category.rawValue
        self.customName = override?.name
        self.icon = override?.symbol ?? category.icon
        self.colorRawValue = override?.colorRawValue ?? category.colorKey.rawValue
        self.isBuiltIn = true
        self.isOverridden = override != nil
    }

    init(custom category: CustomCategory) {
        self.key = Self.key(forCustomID: category.id)
        self.customName = category.name
        self.icon = category.symbol
        self.colorRawValue = category.colorRawValue
        self.isBuiltIn = false
        self.isOverridden = false
    }

    static func key(forCustomID id: UUID) -> String {
        customPrefix + id.uuidString
    }

    static func customID(fromKey key: String) -> UUID? {
        guard key.hasPrefix(customPrefix) else { return nil }
        return UUID(uuidString: String(key.dropFirst(customPrefix.count)))
    }

    static let other = CategoryInfo(builtIn: .other)

    static var builtIns: [CategoryInfo] {
        ExpenseCategory.allCases.map { CategoryInfo(builtIn: $0) }
    }

    /// Built-ins (overrides applied) first, then custom categories by creation date.
    static func all(in context: ModelContext) throws -> [CategoryInfo] {
        let overrides = try context.fetch(FetchDescriptor<BuiltInCategoryOverride>())
        let byKey = Dictionary(overrides.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let builtIns = ExpenseCategory.allCases.map { CategoryInfo(builtIn: $0, override: byKey[$0.rawValue]) }
        let descriptor = FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)])
        let custom = try context.fetch(descriptor).map(CategoryInfo.init(custom:))
        return builtIns + custom
    }
}
