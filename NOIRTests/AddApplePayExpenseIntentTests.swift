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

    @Test(arguments: [nil, "", "  \n"] as [String?])
    func blankCardMeansNoCard(card: String?) {
        #expect(AddApplePayExpenseIntent.resolvedCard(card) == "")
    }

    // Positive control: the blank handling above does not swallow a real card name.
    @Test func cardTextIsTrimmedAndKept() {
        #expect(AddApplePayExpenseIntent.resolvedCard(" Visa \n") == "Visa")
    }
}
