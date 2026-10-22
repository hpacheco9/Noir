//
//  TotalSpentTitleTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct TotalSpentTitleTests {
    private static let missing = "<missing>"

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    @Test func everyPeriodHasItsOwnKey() {
        let keys = SpendingPeriod.allCases.map { L10n.SpendingOverview.totalSpent(for: $0).key }
        #expect(Set(keys).count == SpendingPeriod.allCases.count)
    }

    @Test(arguments: ["en", "pt-PT", "pt-BR", "es", "de", "fr"])
    func everyPeriodIsTranslated(language: String) throws {
        #expect(try localized("not.a.real.key", language: language) == Self.missing)
        for period in SpendingPeriod.allCases {
            let value = try localized(L10n.SpendingOverview.totalSpent(for: period).key, language: language)
            #expect(value != Self.missing, "\(period) in \(language)")
            #expect(!value.contains("%"), "\(period) in \(language)")
        }
    }

    @Test(arguments: ["en", "pt-PT", "pt-BR", "es", "de", "fr"])
    func everyPeriodReadsDifferently(language: String) throws {
        let values = try SpendingPeriod.allCases.map {
            try localized(L10n.SpendingOverview.totalSpent(for: $0).key, language: language)
        }
        #expect(Set(values).count == SpendingPeriod.allCases.count)
    }

    @Test func spanishTitlesAreNounHeadings() throws {
        #expect(try localized(L10n.SpendingOverview.totalSpent(for: .day).key, language: "es") == "Gasto de hoy")
        #expect(try localized(L10n.SpendingOverview.totalSpent(for: .allTime).key, language: "es") == "Gasto total")
    }
}
