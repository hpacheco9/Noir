//
//  ImportRow.swift
//  NOIR
//

import Foundation

nonisolated enum ImportCategory: Sendable, Equatable {
    case existing(key: String)
    case new(name: String)

    // What a new category is called: the name cut to what the category form allows.
    static func categoryName(for name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CategoryFormViewModel.maxNameLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct ImportRow: Sendable, Equatable {
    var date: Date
    var name: String
    var amount: Double
    var category: ImportCategory
    var card: String
    var note: String
}

nonisolated struct ImportResult: Sendable, Equatable {
    let imported: Int
    let duplicates: Int
    let categoriesCreated: Int
}
