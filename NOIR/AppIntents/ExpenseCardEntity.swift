//
//  ExpenseCardEntity.swift
//  NOIR
//

import AppIntents
import Foundation
import SwiftData

/// A card name as a Shortcuts parameter value: `id` is the name itself, so a typed new name is a valid card too.
nonisolated struct ExpenseCardEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("app_intent.card", table: "AppIntents")
    )
    static let defaultQuery = ExpenseCardQuery()

    static let noCardID = "noir.no-card"
    static let noCard = ExpenseCardEntity(id: noCardID)
    static let noCardTitle = LocalizedStringResource("app_intent.card.none", table: "AppIntents")

    let id: String

    var name: String { id == Self.noCardID ? "" : id }

    var displayRepresentation: DisplayRepresentation {
        if id == Self.noCardID {
            return DisplayRepresentation(title: Self.noCardTitle)
        }
        return DisplayRepresentation(title: "\(id)")
    }
}

nonisolated struct ExpenseCardQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ExpenseCardEntity] {
        identifiers.map(ExpenseCardEntity.init)
    }

    func suggestedEntities() async throws -> [ExpenseCardEntity] {
        [.noCard] + (try await savedCards()).map(ExpenseCardEntity.init)
    }

    /// "No card", the matching saved cards, or the typed name as a new card.
    func entities(matching string: String) async throws -> [ExpenseCardEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await suggestedEntities() }
        if Self.isNoCard(needle) { return [.noCard] }
        return Self.matches(needle, in: try await savedCards()).map(ExpenseCardEntity.init)
    }

    // An exact name is the only match, so an unattended run never has to disambiguate.
    static func matches(_ needle: String, in saved: [String]) -> [String] {
        if let exact = saved.first(where: { same($0, needle) }) { return [exact] }
        return saved.filter { $0.localizedStandardContains(needle) } + [needle]
    }

    static func isNoCard(_ text: String) -> Bool {
        same(text, String(localized: ExpenseCardEntity.noCardTitle))
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    @MainActor
    private func savedCards() throws -> [String] {
        try SavedCards.fetch(in: ModelContext(NOIRApp.sharedModelContainer))
    }
}
