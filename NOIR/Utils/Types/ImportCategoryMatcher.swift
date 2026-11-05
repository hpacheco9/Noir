//
//  ImportCategoryMatcher.swift
//  NOIR
//

import Foundation

// Decides which category an imported row lands in: its Category ID if that exists, else its name against the titles
// shown now and the built-in titles of every language, else a new category.
nonisolated struct ImportCategoryMatcher: Sendable {
    private let keys: Set<String>
    private let currentTitles: [String: String]
    private let builtInTitles: [String: String]

    // `current`: key and shown title of every category now (built-ins with their overrides, custom ones).
    init(current: [(key: String, title: String)], builtIns: [(key: String, titles: [String])]) {
        keys = Set(current.map(\.key))
        currentTitles = Dictionary(current.map { ($0.title.searchKey, $0.key) }, uniquingKeysWith: { first, _ in first })
        builtInTitles = Dictionary(
            builtIns.flatMap { entry in entry.titles.map { ($0.searchKey, entry.key) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func resolve(id: String, name: String) -> ImportCategory {
        let food = ImportCategory.existing(key: ExpenseCategory.food.rawValue)
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if id == "other" { return food }
        if keys.contains(id) { return .existing(key: id) }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return food }
        let key = name.searchKey
        if let match = currentTitles[key] ?? builtInTitles[key] { return .existing(key: match) }
        return .new(name: name)
    }

    @MainActor
    static func make(categories: [CategoryInfo]) -> ImportCategoryMatcher {
        ImportCategoryMatcher(
            current: categories.map { ($0.key, $0.title) },
            builtIns: ExpenseCategory.allCases.map { ($0.rawValue, $0.titlesInAllLanguages) }
        )
    }
}
