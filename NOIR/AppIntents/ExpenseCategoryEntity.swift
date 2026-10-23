//
//  ExpenseCategoryEntity.swift
//  NOIR
//

import AppIntents
import Foundation

/// A category (built-in or custom) as a Shortcuts parameter value. `id` is the category key stored on expenses
/// (`food`, `other`, `custom:<uuid>`...), which is also what the old `ShortcutExpenseCategory` enum used for built-ins.
nonisolated struct ExpenseCategoryEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("app_intent.category", table: "AppIntents")
    )
    static let defaultQuery = ExpenseCategoryQuery()

    let id: String
    let name: String
    /// `false` for a built-in that still has its default title, which is shown localized from AppIntents.xcstrings.
    let showsName: Bool

    /// Names only: the category prompt lists plain names, no icons.
    var displayRepresentation: DisplayRepresentation {
        if !showsName, let title = Self.builtInTitle(forKey: id) {
            return DisplayRepresentation(title: title)
        }
        return DisplayRepresentation(title: "\(name)")
    }

    nonisolated init(id: String, name: String) {
        self.id = id
        self.name = name
        self.showsName = true
    }

    @MainActor
    init(_ info: CategoryInfo) {
        self.id = info.key
        self.name = info.title
        self.showsName = !info.isBuiltIn || info.customName != nil
    }

    /// Localized from `AppIntents.xcstrings`, so Shortcuts shows them in the app's language.
    private static func builtInTitle(forKey key: String) -> LocalizedStringResource? {
        switch ExpenseCategory(rawValue: key) {
        case .food: LocalizedStringResource("app_intent.category.food", table: "AppIntents")
        case .transport: LocalizedStringResource("app_intent.category.transport", table: "AppIntents")
        case .home: LocalizedStringResource("app_intent.category.home", table: "AppIntents")
        case .leisure: LocalizedStringResource("app_intent.category.leisure", table: "AppIntents")
        case .health: LocalizedStringResource("app_intent.category.health", table: "AppIntents")
        case .shopping: LocalizedStringResource("app_intent.category.shopping", table: "AppIntents")
        case .other: LocalizedStringResource("app_intent.category.other", table: "AppIntents")
        case nil: nil
        }
    }
}

nonisolated struct ExpenseCategoryQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ExpenseCategoryEntity] {
        let all = try await CategoryCatalog.entities()
        // An id that no longer exists (deleted custom category, stale Shortcut) is handed back as a stand-in that
        // displays as Other but keeps the requested id, so `CategoryCatalog.resolvedKey` is what falls back.
        let other = all.first { $0.id == ExpenseCategory.other.rawValue }
        return identifiers.compactMap { id in
            if let found = all.first(where: { $0.id == id }) { return found }
            return other.map { ExpenseCategoryEntity(id: id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        try await CategoryCatalog.entities()
    }

    func entities(matching string: String) async throws -> [ExpenseCategoryEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = try await CategoryCatalog.entities()
        guard !needle.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(needle) }
    }
}
