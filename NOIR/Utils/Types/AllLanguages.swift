//
//  AllLanguages.swift
//  NOIR
//

import Foundation

nonisolated enum AllLanguages {
    private static let bundles: [Bundle] = Bundle.main.localizations
        .filter { $0 != "Base" }
        .compactMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
        .compactMap(Bundle.init(path:))

    // One string per language the app ships; a language without the key is left out.
    static func strings(forKey key: String) -> [String] {
        bundles.map { $0.localizedString(forKey: key, value: key, table: nil) }.filter { $0 != key }
    }
}

extension ExpenseCategory {
    nonisolated var titleKey: String {
        switch self {
        case .food: "expense_category.food"
        case .transport: "expense_category.transport"
        case .home: "expense_category.home"
        case .leisure: "expense_category.leisure"
        case .health: "expense_category.health"
        case .shopping: "expense_category.shopping"
        }
    }

    nonisolated var titlesInAllLanguages: [String] { AllLanguages.strings(forKey: titleKey) }
}
