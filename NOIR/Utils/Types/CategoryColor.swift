//
//  CategoryColor.swift
//  NOIR
//

import Foundation
import SwiftUI

/// Colours a category can use. The first seven are the ones the built-in categories use.
nonisolated enum CategoryColor: String, CaseIterable, Identifiable, Sendable {
    case orange
    case blue
    case indigo
    case purple
    case red
    case green
    case yellow
    case pink
    case teal
    case brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: .orange
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .red: .red
        case .green: .green
        case .yellow: .yellow
        case .pink: .pink
        case .teal: .teal
        case .brown: .brown
        }
    }

    @MainActor var title: String {
        switch self {
        case .orange: String(localized: L10n.CategoryColor.orange)
        case .blue: String(localized: L10n.CategoryColor.blue)
        case .indigo: String(localized: L10n.CategoryColor.indigo)
        case .purple: String(localized: L10n.CategoryColor.purple)
        case .red: String(localized: L10n.CategoryColor.red)
        case .green: String(localized: L10n.CategoryColor.green)
        case .yellow: String(localized: L10n.CategoryColor.yellow)
        case .pink: String(localized: L10n.CategoryColor.pink)
        case .teal: String(localized: L10n.CategoryColor.teal)
        case .brown: String(localized: L10n.CategoryColor.brown)
        }
    }

    /// Colour for a stored raw value; unknown values fall back to gray.
    static func color(forRawValue rawValue: String) -> Color {
        CategoryColor(rawValue: rawValue)?.color ?? .gray
    }
}
