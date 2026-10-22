//
//  CategoryCatalog.swift
//  NOIR
//

import Foundation
import SwiftData

/// Reads categories straight from the shared container (Shortcuts runs outside the repository).
enum CategoryCatalog {
    static func entities() throws -> [ExpenseCategoryEntity] {
        let context = ModelContext(NOIRApp.sharedModelContainer)
        return try CategoryInfo.all(in: context).map(ExpenseCategoryEntity.init)
    }

    /// `key` if it is a built-in or an existing custom category, otherwise `other` (a deleted category, a stale Shortcut).
    static func resolvedKey(_ key: String?, in context: ModelContext) -> String {
        let fallback = ExpenseCategory.other.rawValue
        guard let key else { return fallback }
        if ExpenseCategory(rawValue: key) != nil { return key }
        guard let id = CategoryInfo.customID(fromKey: key) else { return fallback }
        let count = (try? context.fetchCount(FetchDescriptor<CustomCategory>(predicate: #Predicate { $0.id == id }))) ?? 0
        return count > 0 ? CategoryInfo.key(forCustomID: id) : fallback
    }
}
