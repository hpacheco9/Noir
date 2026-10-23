//
//  ProfileStorage.swift
//  NOIR
//

import Foundation

nonisolated enum ProfileStorage {
    static let nameKey = "profile.name"

    static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func initial(of name: String) -> String {
        trimmed(name).first.map { String($0).uppercased() } ?? ""
    }

    static func nameToStore(draft: String, current: String) -> String {
        let name = trimmed(draft)
        return name.isEmpty ? current : name
    }

    static func nameOnLeaving(draft: String, entry: String) -> String {
        let name = trimmed(draft)
        return name.isEmpty ? entry : name
    }
}
