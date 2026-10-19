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

    /// The locale whose conventions match the currency, so EUR reads "12,50 €" and USD "$12.50" whatever the
    /// device region is. JPY uses en_US because ja_JP writes a full-width "￥" that its own parser rejects, which
    /// breaks editing in a TextField. Other codes follow the device locale.
    static func locale(for code: String) -> Locale {
        switch code {
        case "EUR": Locale(identifier: "pt_PT")
        case "USD": Locale(identifier: "en_US")
        case "GBP": Locale(identifier: "en_GB")
        case "BRL": Locale(identifier: "pt_BR")
        case "JPY": Locale(identifier: "en_US")
        case "CAD": Locale(identifier: "en_CA")
        default: .current
        }
    }

    /// Format and parse style for amounts: the currency's own locale, narrow symbol ("$" for USD and CAD).
    static func formatStyle(for code: String) -> Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency(code: code, locale: locale(for: code)).presentation(.narrow)
    }

    /// For amount TextFields: same output as `formatStyle(for:)`, but parsing accepts "." or "," as the decimal mark.
    static func amountInputStyle(for code: String) -> AmountInputFormatStyle {
        AmountInputFormatStyle(code: code, currencyLocale: locale(for: code))
    }

    static func doubleFormatStyle(for code: String) -> FloatingPointFormatStyle<Double>.Currency {
        FloatingPointFormatStyle<Double>.Currency(code: code, locale: locale(for: code)).presentation(.narrow)
    }

    /// Rendered to a String on purpose: `Text(_, format:)` swaps the style's locale for the environment's, which
    /// would put the euro sign back on the left on a non-Portuguese device.
    static func string(for amount: Decimal, code: String) -> String {
        amount.formatted(formatStyle(for: code))
    }

    /// Whole units only (budget picker).
    static func wholeString(for amount: Double, code: String) -> String {
        amount.formatted(doubleFormatStyle(for: code).precision(.fractionLength(0)))
    }

    static func string(for amount: Double, code: String) -> String {
        amount.formatted(doubleFormatStyle(for: code))
    }

    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }
}
