//
//  ProfileStorage.swift
//  NOIR
//

import Foundation

/// The profile name: its UserDefaults key and the rules that keep it non-empty.
nonisolated enum ProfileStorage {
    static let nameKey = "profile.name"

    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First character of the trimmed name, uppercased; empty when there is no name.
    static func initial(of name: String) -> String {
        trimmed(name).first.map { String($0).uppercased() } ?? ""
    }

    /// What to store when the user finishes editing: the trimmed draft, or `current` when the draft is blank.
    static func nameToStore(draft: String, current: String) -> String {
        let name = trimmed(draft)
        return name.isEmpty ? current : name
    }
}
