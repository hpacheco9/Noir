//
//  AmountInputFormatStyle.swift
//  NOIR
//

import Foundation

extension CurrencyPreference {
    /// For amount TextFields: same output as `formatStyle(for:)`, but parsing accepts "." or "," as the decimal mark.
    static func amountInputStyle(for code: String) -> AmountInputFormatStyle {
        AmountInputFormatStyle(code: code, currencyLocale: locale(for: code))
    }
}

/// Format style for amount TextFields. It formats exactly like `Decimal.FormatStyle.Currency` in the currency's own
/// locale, but parses leniently: the decimal pad shows the DEVICE's decimal separator, which can differ from the
/// currency locale's (EUR on an en_US device offers "."), so either mark is accepted.
///
/// It intentionally does not implement `locale(_:)`: SwiftUI calls that to inject the environment locale, which would
/// replace the currency's locale and bring back the wrong symbol position and separators.
nonisolated struct AmountInputFormatStyle: ParseableFormatStyle {
    var code: String
    var currencyLocaleIdentifier: String
    /// The decimal separator of the device locale (what the decimal pad types).
    var deviceDecimalSeparator: String

    init(code: String, currencyLocale: Locale, deviceLocale: Locale = .current) {
        self.code = code
        self.currencyLocaleIdentifier = currencyLocale.identifier
        self.deviceDecimalSeparator = deviceLocale.decimalSeparator ?? "."
    }

    private var currencyLocale: Locale { Locale(identifier: currencyLocaleIdentifier) }

    private var base: Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency(code: code, locale: currencyLocale).presentation(.narrow)
    }

    func format(_ value: Decimal) -> String {
        base.format(value)
    }

    var parseStrategy: AmountInputParseStrategy {
        AmountInputParseStrategy(
            currencyDecimalSeparator: currencyLocale.decimalSeparator ?? ".",
            deviceDecimalSeparator: deviceDecimalSeparator
        )
    }
}

nonisolated struct AmountInputParseStrategy: ParseStrategy {
    var currencyDecimalSeparator: String
    var deviceDecimalSeparator: String

    struct ParseError: Error {}

    /// Keeps digits, a leading minus and the "." / "," marks (currency symbols, letters and every kind of space
    /// go), then decides which mark is the decimal one:
    /// - both marks present: the last one is the decimal mark, the other is grouping;
    /// - one mark repeated: grouping;
    /// - one mark once: decimal if it is the device's or the currency's decimal separator, or if it isn't followed
    ///   by exactly three digits; otherwise grouping.
    func parse(_ value: String) throws -> Decimal {
        var negative = false
        var cleaned = ""
        for character in value {
            if character.isASCII, character.isNumber {
                cleaned.append(character)
            } else if character == "." || character == "," {
                cleaned.append(character)
            } else if character == "-" || character == "\u{2212}" {
                negative = true
            }
        }
        guard cleaned.contains(where: \.isNumber) else { throw ParseError() }

        let decimalMark: Character?
        let dot = cleaned.filter { $0 == "." }.count
        let comma = cleaned.filter { $0 == "," }.count
        if dot > 0, comma > 0 {
            decimalMark = cleaned.last { $0 == "." || $0 == "," }
        } else if dot + comma == 1 {
            let mark: Character = dot == 1 ? "." : ","
            let isKnownDecimal = String(mark) == deviceDecimalSeparator || String(mark) == currencyDecimalSeparator
            let digitsAfter = cleaned.drop { $0 != mark }.dropFirst().count
            // A mark that is nobody's decimal separator followed by exactly three digits reads as grouping ("1,234");
            // anything else is a decimal mark typed on a keyboard that doesn't match the currency ("12,50").
            decimalMark = (isKnownDecimal || digitsAfter != 3) ? mark : nil
        } else {
            decimalMark = nil
        }

        var normalized = ""
        for character in cleaned {
            if character.isNumber {
                normalized.append(character)
            } else if character == decimalMark {
                normalized.append(".")
            }
        }
        if normalized.hasPrefix(".") { normalized = "0" + normalized }
        if normalized.hasSuffix(".") { normalized.removeLast() }
        guard let number = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { throw ParseError() }
        return negative ? -number : number
    }
}
