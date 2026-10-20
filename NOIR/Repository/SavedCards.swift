//
//  SavedCards.swift
//  NOIR
//

import Foundation
import SwiftData

nonisolated enum SavedCards {
    static let storageKey = "cards.saved"
    @TaskLocal static var suiteName: String?
    private static var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    static func make(from names: [String], remembered: [String] = []) -> [String] {
        var uses: [String: Int] = [:]
        for name in remembered {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { uses[trimmed, default: 0] += 0 }
        }
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { uses[trimmed, default: 0] += 1 }
        }
        return uses.sorted {
            $0.value != $1.value ? $0.value > $1.value : $0.key.localizedStandardCompare($1.key) == .orderedAscending
        }
        .map(\.key)
    }

    static func fetch(in context: ModelContext) throws -> [String] {
        var descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.card != "" }
        )
        descriptor.propertiesToFetch = [\.card]
        return make(
            from: try context.fetch(descriptor).map(\.card),
            remembered: defaults.stringArray(forKey: storageKey) ?? []
        )
    }

    static func remember(_ card: String) {
        let trimmed = card.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var saved = defaults.stringArray(forKey: storageKey) ?? []
        guard !saved.contains(trimmed) else { return }
        saved.append(trimmed)
        defaults.set(saved, forKey: storageKey)
    }
}
