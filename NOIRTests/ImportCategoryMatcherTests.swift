//
//  ImportCategoryMatcherTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct ImportCategoryMatcherTests {
    private let petsID = "custom:5E4F888E-D8BD-4798-9D2C-4EBD856B8B6E"

    // English titles, Health renamed "Doctor", one custom category.
    private var matcher: ImportCategoryMatcher {
        ImportCategoryMatcher(
            current: [
                ("food", "Food"), ("transport", "Transport"), ("home", "Home"), ("leisure", "Leisure"),
                ("health", "Doctor"), ("clothing", "Shopping"), (petsID, "Café Pets"),
            ],
            builtIns: ExpenseCategory.allCases.map { ($0.rawValue, $0.titlesInAllLanguages) }
        )
    }

    private func existing(_ key: String) -> ImportCategory { .existing(key: key) }

    @Test func aBuiltInIDIsUsedAsIs() {
        #expect(matcher.resolve(id: "transport", name: "") == existing("transport"))
        #expect(matcher.resolve(id: "clothing", name: "") == existing("clothing"))
        #expect(matcher.resolve(id: " health ", name: "") == existing("health"))
    }

    @Test func anExistingCustomIDIsUsedAsIs() {
        #expect(matcher.resolve(id: petsID, name: "") == existing(petsID))
    }

    @Test func theIDWinsOverTheName() {
        #expect(matcher.resolve(id: "transport", name: "Food") == existing("transport"))
        // Control: with no ID the same name does decide.
        #expect(matcher.resolve(id: "", name: "Food") == existing("food"))
    }

    @Test func aMissingCustomIDFallsBackToTheName() {
        let gone = "custom:00000000-0000-0000-0000-000000000000"
        #expect(matcher.resolve(id: gone, name: "Café Pets") == existing(petsID))
        #expect(matcher.resolve(id: gone, name: "Hobbies") == .new(name: "Hobbies"))
        #expect(matcher.resolve(id: gone, name: "") == existing("food"))
    }

    @Test func theLegacyOtherIDIsFood() {
        #expect(matcher.resolve(id: "other", name: "") == existing("food"))
        #expect(matcher.resolve(id: "other", name: "Hobbies") == existing("food"))
    }

    @Test func aGermanBuiltInNameFindsTheBuiltIn() {
        #expect(matcher.resolve(id: "", name: "Essen") == existing("food"))
        #expect(matcher.resolve(id: "", name: "Mobilität") == existing("transport"))
        #expect(matcher.resolve(id: "", name: "Einkaufen") == existing("clothing"))
        #expect(matcher.resolve(id: "", name: "Alimentação") == existing("food"))
        #expect(matcher.resolve(id: "", name: "Lazer") == existing("leisure"))
    }

    @Test func namesIgnoreCaseAndAccents() {
        #expect(matcher.resolve(id: "", name: "ESSEN") == existing("food"))
        #expect(matcher.resolve(id: "", name: "mobilitat") == existing("transport"))
        #expect(matcher.resolve(id: "", name: "alimentacao") == existing("food"))
        #expect(matcher.resolve(id: "", name: "  cafe pets ") == existing(petsID))
    }

    @Test func anOverrideNameIsMatchedAndTheDefaultStillWorks() {
        #expect(matcher.resolve(id: "", name: "doctor") == existing("health"))
        // The built-in's default titles (English and German) still find it.
        #expect(matcher.resolve(id: "", name: "Health") == existing("health"))
        #expect(matcher.resolve(id: "", name: "Gesundheit") == existing("health"))
    }

    @Test func aCustomNameIsMatched() {
        #expect(matcher.resolve(id: "", name: "Café Pets") == existing(petsID))
    }

    @Test func aCurrentTitleBeatsAnotherLanguagesBuiltInTitle() {
        // A custom "Casa" next to the built-in Home, whose Portuguese title is also "Casa".
        let custom = ImportCategoryMatcher(
            current: [("home", "Home"), ("custom:A", "Casa")],
            builtIns: [("home", ExpenseCategory.home.titlesInAllLanguages)]
        )
        #expect(custom.resolve(id: "", name: "casa") == existing("custom:A"))
        #expect(matcher.resolve(id: "", name: "casa") == existing("home"))
    }

    @Test func anUnknownNameIsANewCategory() {
        #expect(matcher.resolve(id: "", name: "Hobbies") == .new(name: "Hobbies"))
        #expect(matcher.resolve(id: "nonsense", name: " Hobbies ") == .new(name: "Hobbies"))
    }

    @Test func newNamesAreCutToTheCategoryLimit() {
        let long = String(repeating: "x", count: 40)
        #expect(matcher.resolve(id: "", name: long) == .new(name: String(repeating: "x", count: ImportCategoryMatcher.maxNameLength)))
        #expect(ImportCategoryMatcher.maxNameLength == CategoryFormViewModel.maxNameLength)
    }

    @Test func aBlankCategoryIsFood() {
        #expect(matcher.resolve(id: "", name: "") == existing("food"))
        #expect(matcher.resolve(id: "", name: "   \n") == existing("food"))
    }

    @Test func theMainActorFactoryUsesTheShownTitlesAndEveryLanguage() {
        var categories = CategoryInfo.builtIns
        categories.append(CategoryInfo(custom: CustomCategory(name: "Pets", symbol: "pawprint.fill", colorRawValue: "orange")))
        let made = ImportCategoryMatcher.make(categories: categories)
        #expect(made.resolve(id: "", name: ExpenseCategory.transport.title) == existing("transport"))
        #expect(made.resolve(id: "", name: "Mobilität") == existing("transport"))
        #expect(made.resolve(id: "", name: "pets") == existing(categories.last!.key))
        #expect(made.resolve(id: "", name: "Hobbies") == .new(name: "Hobbies"))
    }
}
