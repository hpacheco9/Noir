//
//  CurrencyPreference.swift
//  NOIR
//

import Foundation

enum CurrencyPreference {
    static let storageKey = "settings.currency_code"

    private static let baseCodes = ["EUR", "USD", "GBP", "BRL", "JPY", "CAD"]

    static var defaultCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static var availableCodes: [String] {
        let currentCode = defaultCode
        return baseCodes.contains(currentCode) ? baseCodes : [currentCode] + baseCodes
    }

    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
}
