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

    @Test func defaultCategoryIsFood() {
        #expect(ExpenseCategoryEntity.food.id == ExpenseCategory.food.rawValue)
        #expect(!ExpenseCategoryEntity.food.showsName)
    }
}
