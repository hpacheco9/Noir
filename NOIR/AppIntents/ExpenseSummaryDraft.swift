//
//  ExpenseSummaryDraft.swift
//  NOIR
//

import Foundation

/// The summary's picks and open list. The controls run as separate intents, possibly in another process.
nonisolated struct ExpenseSummaryDraft: Codable, Equatable {
    enum List: String, Codable {
        case category, card
    }

    static let storageKey = "app_intent.summary_draft"

    var categoryKey: String
    var categoryName: String
    var card: String
    var expanded: List? = nil

    mutating func toggle(_ list: List) {
        expanded = expanded == list ? nil : list
    }

    mutating func selectCategory(key: String, name: String) {
        categoryKey = key
        categoryName = name
        expanded = nil
    }

    mutating func selectCard(_ name: String) {
        card = name
        expanded = nil
    }

    static func load(from defaults: UserDefaults = .standard) -> ExpenseSummaryDraft? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ExpenseSummaryDraft.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    static func update(in defaults: UserDefaults = .standard, _ change: (inout ExpenseSummaryDraft) -> Void) {
        guard var draft = load(from: defaults) else { return }
        change(&draft)
        draft.save(to: defaults)
    }
}
