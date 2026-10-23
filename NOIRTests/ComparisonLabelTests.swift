//
//  ComparisonLabelTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

// Every key the code asks for must exist in the compiled catalog: StringCatalogCompletenessTests only checks keys
// that are already there, so a mistyped key in `L10n` would show up as raw text in the app.
struct ComparisonLabelTests {
    private static let missing = "<missing>"
    private static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr"]
    private static let periods: [SpendingPeriod] = [.day, .week, .month, .year]
    private static let comparisons = [PeriodComparison(percent: 5), PeriodComparison(percent: -5), PeriodComparison(percent: 0)]

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    @Test func allTimeHasNoLabel() {
        for comparison in Self.comparisons {
            #expect(L10n.SpendingOverview.comparison(comparison, for: .allTime) == nil)
        }
    }

    @Test(arguments: languages)
    func everyComparisonLabelResolvesAndKeepsItsPercent(language: String) throws {
        #expect(try localized("not.a.real.key", language: language) == Self.missing)
        var keys = Set<String>()
        for comparison in Self.comparisons {
            for period in Self.periods {
                let key = try #require(L10n.SpendingOverview.comparison(comparison, for: period)).key
                keys.insert(key)
                let value = try localized(key, language: language)
                #expect(value != Self.missing, "\(key) in \(language)")
                #expect(value.contains("%@") == (comparison.trend != .same), "\(key) in \(language): \(value)")
            }
        }
        #expect(keys.count == Self.comparisons.count * Self.periods.count)
    }

    @Test(arguments: languages)
    func budgetMessagesResolveAndKeepTheirAmounts(language: String) throws {
        let left = try localized(L10n.BudgetSummary.left("%@", of: "%@").key, language: language)
        let over = try localized(L10n.BudgetSummary.over("%@").key, language: language)
        #expect(left != Self.missing && over != Self.missing)
        #expect(left.contains("%1$@") && left.contains("%2$@"), "\(language): \(left)")
        #expect(over.contains("%@"), "\(language): \(over)")
    }
}
