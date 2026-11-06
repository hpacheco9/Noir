//
//  AddApplePayExpenseIntentTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct AddApplePayExpenseIntentTests {
    @Test(arguments: [nil, "", "   ", "\n\t "] as [String?])
    func blankMerchantBecomesUntitled(name: String?) {
        #expect(AddApplePayExpenseIntent.resolvedName(name, untitled: "Untitled") == "Untitled")
    }

    // Positive control: the fallback above is not what every input gets.
    @Test func merchantIsTrimmedAndKept() {
        #expect(AddApplePayExpenseIntent.resolvedName("  Starbucks \n", untitled: "Untitled") == "Starbucks")
        #expect(AddApplePayExpenseIntent.resolvedName("Untitled Cafe", untitled: "Other") == "Untitled Cafe")
    }

    @Test func untitledIsLocalized() {
        let text = String(localized: L10n.AppIntent.untitled)
        #expect(!text.isEmpty)
        #expect(text != "app_intent.untitled")
    }

    @Test(arguments: ["EUR", "USD"])
    func walletAmountTextBecomesAPositiveNumber(code: String) {
        let cases: [(String, Double)] = [
            ("-4,50 €", 4.5), ("€4.50", 4.5), ("4.50", 4.5), ("-$1,234.56", 1234.56),
            ("1.234,56 €", 1234.56), ("12", 12), ("-19,99 €", 19.99), ("-€0.01", 0.01),
        ]
        for (text, expected) in cases {
            #expect(AddApplePayExpenseIntent.parsedAmount(text, code: code) == expected, "\(text)")
        }
    }

    // Letters before the symbol ("US$", "CA$") and a currency without minor units ("¥1,234" is 1234, not 1.234).
    @Test(arguments: [
        ("US$1,234.56", "USD", 1234.56), ("-US$4.50", "USD", 4.5), ("R$ 1.234,56", "BRL", 1234.56),
        ("-R$ 4,50", "BRL", 4.5), ("CA$12.50", "CAD", 12.5), ("-¥1,234", "JPY", 1234), ("¥1,234", "JPY", 1234),
        ("-¥12", "JPY", 12),
    ])
    func walletTextWithLetterPrefixedOrWholeCurrencies(text: String, code: String, expected: Double) {
        #expect(AddApplePayExpenseIntent.parsedAmount(text, code: code) == expected, "\(text)")
    }

    @Test(arguments: ["EUR", "USD"])
    func unusableWalletAmountTextIsRejected(code: String) {
        for text in ["", "abc", "0", "-0,00 €", "-", ",", "€", "99999999999999"] {
            #expect(AddApplePayExpenseIntent.parsedAmount(text, code: code) == nil, "\(text)")
        }
    }

    @Test(arguments: ["abc", "0", "-0,00 €"])
    @MainActor func unusableAmountStopsTheIntent(text: String) async {
        let intent = AddApplePayExpenseIntent()
        intent.amount = text
        await withIntentAccess {
            await #expect(throws: AddExpenseIntentError.invalidAmount) { _ = try await intent.perform() }
        }
    }

    @Test(arguments: [nil, "", "  \n"] as [String?])
    func blankCardMeansNoCard(card: String?) {
        #expect(AddApplePayExpenseIntent.resolvedCard(card) == "")
    }

    // Positive control: the blank handling above does not swallow a real card name.
    @Test func cardTextIsTrimmedAndKept() {
        #expect(AddApplePayExpenseIntent.resolvedCard(" Visa \n") == "Visa")
    }
}
