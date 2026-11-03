//
//  NordicCurrencyTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct NordicCurrencyTests {
    nonisolated static let nordic = ["SEK", "NOK", "DKK"]
    nonisolated static let baseCodes = ["EUR", "USD", "GBP", "BRL", "JPY", "CAD"] + nordic
    // Existing currencies ride along as controls: whatever fails for the Nordic ones must pass for these.
    nonisolated static let codes = ["EUR", "USD"] + nordic
    // Dot and comma decimal devices.
    nonisolated static let devices = ["en_US", "en_GB", "pt_PT", "sv_SE", "nb_NO", "da_DK", "fi_FI"]

    nonisolated static func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    nonisolated static func style(_ code: String, device: String = "en_US") -> AmountInputFormatStyle {
        AmountInputFormatStyle(
            code: code, currencyLocale: CurrencyPreference.locale(for: code), deviceLocale: Locale(identifier: device)
        )
    }

    // MARK: Picker

    @Test func nordicCodesComeAfterTheOriginalSix() {
        #expect(Array(CurrencyPreference.availableCodes.suffix(Self.baseCodes.count)) == Self.baseCodes)
    }

    // MARK: Formatting

    // Measured: sv_SE and nb_NO group with U+00A0 and put "kr" after a U+00A0; da_DK groups with "." and writes "kr.".
    @Test(arguments: [
        ("SEK", "1\u{00A0}234,50\u{00A0}kr"),
        ("NOK", "1\u{00A0}234,50\u{00A0}kr"),
        ("DKK", "1.234,50\u{00A0}kr."),
        ("EUR", "1234,50\u{00A0}\u{20AC}"),
        ("USD", "$1,234.50"),
    ])
    func formatsInTheCurrencyLocale(code: String, expected: String) {
        let amount = Self.decimal("1234.5")
        #expect(CurrencyPreference.string(for: amount, code: code) == expected)
        #expect(CurrencyPreference.string(for: 1234.5, code: code) == expected)
        #expect(CurrencyPreference.amountInputStyle(for: code).format(amount) == expected)
    }

    // MARK: Round trips

    nonisolated static let amounts = ["0.01", "12.5", "999", "1234", "1234.5", "1234567.89"].map { decimal($0) }
    nonisolated static let wholeAmounts = ["1", "12", "999", "1234", "1234567"].map { decimal($0) }

    @Test(arguments: baseCodes, devices)
    func formattedAmountsParseBack(code: String, device: String) throws {
        let style = Self.style(code, device: device)
        // JPY has no minor units, so it only formats whole amounts back to themselves.
        for value in code == "JPY" ? Self.wholeAmounts : Self.amounts {
            let text = style.format(value)
            #expect(try style.parseStrategy.parse(text) == value, "\(text) on \(device)")
        }
    }

    @Test(arguments: codes, devices)
    func typedDecimalMarkWorksOnAnyDevice(code: String, device: String) throws {
        let strategy = Self.style(code, device: device).parseStrategy
        #expect(try strategy.parse("12,5") == Self.decimal("12.5"), "comma on \(device)")
        #expect(try strategy.parse("12.5") == Self.decimal("12.5"), "dot on \(device)")
        #expect(try strategy.parse("0,05") == Self.decimal("0.05"), "comma on \(device)")
    }

    // MARK: Currencies without minor units

    @Test func fractionDigitsComeFromTheCurrency() {
        #expect(Self.style("JPY").parseStrategy.fractionDigits == 0)
        for code in Self.baseCodes where code != "JPY" {
            #expect(Self.style(code).parseStrategy.fractionDigits == 2, "\(code)")
        }
    }

    // "¥1,234" used to read as 1.234 on a device whose decimal separator is ",". Positive control: USD keeps its marks.
    @Test(arguments: devices)
    func everyMarkIsGroupingForYen(device: String) throws {
        let yen = Self.style("JPY", device: device).parseStrategy
        #expect(try yen.parse("¥1,234") == Self.decimal("1234"), "comma on \(device)")
        #expect(try yen.parse("¥1.234") == Self.decimal("1234"), "dot on \(device)")
        #expect(try yen.parse("¥1,234,567") == Self.decimal("1234567"), "\(device)")
        #expect(try yen.parse("12,5") == Self.decimal("125"), "\(device)")
        #expect(try yen.parse("12.5") == Self.decimal("125"), "\(device)")

        let dollar = Self.style("USD", device: device).parseStrategy
        #expect(try dollar.parse("12,5") == Self.decimal("12.5"), "\(device)")
        #expect(try dollar.parse("12.5") == Self.decimal("12.5"), "\(device)")
    }

    // MARK: Grouping, spaces and abbreviations

    @Test(arguments: [
        "1 234,50 kr",
        "1\u{00A0}234,50\u{00A0}kr",
        "1\u{202F}234,50\u{202F}kr",
        "1.234,50 kr",
        "1.234,50 kr.",
        "1,234.50 kr",
        "kr 1 234,50",
        "kr. 1.234,50",
        "1\u{00A0}234,50",
    ])
    func groupedTextParses(text: String) throws {
        for code in Self.nordic {
            let strategy = Self.style(code).parseStrategy
            #expect(try strategy.parse(text) == Self.decimal("1234.5"), "\(text) as \(code)")
        }
    }

    // "kr." ends in a dot that is not a decimal mark. Positive controls: a dot right after a digit still counts.
    @Test(arguments: [
        ("12,50 kr.", "12.5"), ("12.5 kr.", "12.5"), ("kr.12,5", "12.5"), ("1.234,50 kr.", "1234.5"),
        ("12.5 kr", "12.5"), ("12.50", "12.5"), ("1,234.5 kr", "1234.5"),
    ])
    func abbreviationDotIsNotADecimalMark(text: String, expected: String) throws {
        for code in Self.nordic {
            let strategy = Self.style(code).parseStrategy
            #expect(try strategy.parse(text) == Self.decimal(expected), "\(text) as \(code)")
        }
    }

    // Same rule for abbreviations of other currencies. The last two are controls: no dot after the letters.
    @Test(arguments: [
        ("Rs.1,234.00", "1234"), ("Fr. 12.50", "12.5"), ("12,50 \u{043B}\u{0432}.", "12.5"),
        ("Rs 12.5", "12.5"), ("12.5 \u{043B}\u{0432}", "12.5"),
    ])
    func otherAbbreviationDotsAreIgnored(text: String, expected: String) throws {
        for code in ["USD", "EUR"] {
            let strategy = Self.style(code).parseStrategy
            #expect(try strategy.parse(text) == Self.decimal(expected), "\(text) as \(code)")
        }
    }

    @Test func textWithoutDigitsIsRejected() throws {
        let strategy = Self.style("DKK").parseStrategy
        for text in ["", "kr", "kr.", "-", ".", ",", "\u{00A0}"] {
            #expect(throws: AmountInputParseStrategy.ParseError.self) { try strategy.parse(text) }
        }
        #expect(try strategy.parse("1 kr.") == 1)
    }

    // MARK: Apple Pay automation

    @Test(arguments: nordic)
    func walletTextBecomesAPositiveNumber(code: String) {
        let cases: [(String, Double)] = [
            ("-45,50 kr", 45.5), ("-45,50 kr.", 45.5), ("45,50 kr.", 45.5), ("\u{2212}45,50 kr", 45.5),
            ("-1.234,50 kr.", 1234.5), ("-1\u{00A0}234,50\u{00A0}kr", 1234.5), ("-1\u{202F}234,50\u{202F}kr", 1234.5),
            ("kr 45.50", 45.5), ("-12 kr.", 12),
        ]
        for (text, expected) in cases {
            #expect(AddApplePayExpenseIntent.parsedAmount(text, code: code) == expected, "\(text) as \(code)")
        }
    }

    @Test(arguments: nordic)
    func unusableWalletTextIsRejected(code: String) {
        for text in ["", "kr", "kr.", "-", "0 kr", "-0,00 kr.", "99999999999999 kr"] {
            #expect(AddApplePayExpenseIntent.parsedAmount(text, code: code) == nil, "\(text) as \(code)")
        }
        #expect(AddApplePayExpenseIntent.parsedAmount("1 kr", code: code) == 1)
    }
}
