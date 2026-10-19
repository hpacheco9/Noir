//
//  BuiltInCategoryOverride.swift
//  NOIR
//

import Foundation
import SwiftData

/// The user's changes to a built-in category. `key` is the built-in raw value (never changes, so stored expenses
/// keep resolving). A `nil` field means "use the default": a nil name keeps following the app language.
@Model
final class BuiltInCategoryOverride {
    @Attribute(.unique) var key: String
    var name: String?
    var symbol: String?
    var colorRawValue: String?

    init(key: String, name: String? = nil, symbol: String? = nil, colorRawValue: String? = nil) {
        self.key = key
        self.name = name
        self.symbol = symbol
        self.colorRawValue = colorRawValue
    }
}
