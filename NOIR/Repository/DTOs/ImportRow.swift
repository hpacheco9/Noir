//
//  ImportRow.swift
//  NOIR
//

import Foundation

nonisolated enum ImportCategory: Sendable, Equatable {
    case existing(key: String)
    case new(name: String)
}

nonisolated struct ImportRow: Sendable, Equatable {
    var date: Date
    var name: String
    var amount: Double
    var category: ImportCategory
    var card: String
    var note: String
}

nonisolated enum ImportDefaults {
    static let symbol = AssetName.CategorySymbols.generic

    static func color(at index: Int) -> CategoryColor {
        CategoryColor.allCases[index % CategoryColor.allCases.count]
    }
}

// Same day, same amount at the currency's minor units, same name ignoring case and accents.
nonisolated struct ExpenseDuplicateKey: Hashable, Sendable {
    let day: Date
    let amount: String
    let name: String

    init(date: Date, amount: Double, name: String, fractionDigits: Int, calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: date)
        self.amount = ExpenseCSV.amountString(amount, fractionDigits: fractionDigits)
        self.name = name.searchKey
    }
}

extension String {
    nonisolated var searchKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
