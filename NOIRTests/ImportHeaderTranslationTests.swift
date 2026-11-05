//
//  ImportHeaderTranslationTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

// The reader recognises the exported headers and the built-in category titles in every language, read from the
// bundle; these check them against the catalog file.
struct ImportHeaderTranslationTests {
    private static let languages = ["da", "de", "en", "es", "fi", "fr", "nb", "pt-BR", "pt-PT"]

    private static let headerKeys: [(key: String, field: ExpenseCSVReader.Field)] = [
        ("export.header_date", .date), ("export.header_name", .name), ("export.header_amount", .amount),
        ("export.header_currency", .currency), ("export.header_category", .category),
        ("export.header_card", .card), ("export.header_note", .note),
    ]

    private static func catalogValues(for key: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "NOIR/Utils/Localizable.xcstrings")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        let localizations = try #require(strings[key]?["localizations"] as? [String: [String: Any]])
        return localizations.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    @Test func theBundleHasEveryLanguage() {
        #expect(AllLanguages.strings(forKey: "export.header_amount").count == Self.languages.count)
        // Control: a key that is in no catalog gives nothing.
        #expect(AllLanguages.strings(forKey: "no.such.key").isEmpty)
    }

    @Test(arguments: headerKeys.map(\.key))
    func theBundleHoldsTheCatalogsTranslations(key: String) throws {
        let catalog = try Self.catalogValues(for: key)
        #expect(Set(AllLanguages.strings(forKey: key)) == Set(catalog.values))
        #expect(catalog.count == Self.languages.count)
    }

    @Test func everyTranslatedHeaderIsRecognisedAsItsField() throws {
        for (key, field) in Self.headerKeys {
            for (language, value) in try Self.catalogValues(for: key) {
                let columns = ExpenseCSVReader.columns(in: [value])
                #expect(columns[field] == 0, "\(key) \(language): \(value)")
            }
        }
        // Control: text that is no header matches nothing.
        #expect(ExpenseCSVReader.columns(in: ["Balance", "Zzz"]).isEmpty)
    }

    @Test func theCategoryIDHeaderIsRecognisedAndNotMistakenForCategory() {
        #expect(ExpenseCSVReader.columns(in: ["Category ID"])[.categoryID] == 0)
        #expect(ExpenseCSVReader.columns(in: ["Category ID"])[.category] == nil)
        #expect(ExpenseCSVReader.columns(in: ["Category"])[.categoryID] == nil)
    }

    @Test(arguments: ExpenseCategory.allCases)
    func builtInTitlesInAllLanguagesMatchTheCatalog(category: ExpenseCategory) throws {
        let catalog = try Self.catalogValues(for: category.titleKey)
        #expect(Set(category.titlesInAllLanguages) == Set(catalog.values))
        #expect(category.titlesInAllLanguages.count == Self.languages.count)
        #expect(category.titlesInAllLanguages.contains(category.title))
    }
}
