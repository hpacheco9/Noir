//
//  ComparisonLabelTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct ComparisonLabelTests {
    private static let missing = "<missing>"
    private static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr"]
    private static let periods: [SpendingPeriod] = [.day, .week, .month, .year]
    private static let trends: [PeriodComparison.Trend] = [.higher, .lower, .same]

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    private func resource(_ trend: PeriodComparison.Trend, _ period: SpendingPeriod) throws -> LocalizedStringResource {
        try #require(L10n.SpendingOverview.comparison(trend, percent: "%@", for: period))
    }

    @Test func allTimeHasNoLabel() {
        for trend in Self.trends {
            #expect(L10n.SpendingOverview.comparison(trend, percent: "5%", for: .allTime) == nil)
        }
    }

    @Test func everyTrendAndPeriodHasItsOwnKey() throws {
        var keys = Set<String>()
        for trend in Self.trends {
            for period in Self.periods {
                keys.insert(try resource(trend, period).key)
            }
        }
        #expect(keys.count == Self.trends.count * Self.periods.count)
    }

    @Test(arguments: languages)
    func everyLabelIsTranslatedAndKeepsItsPercent(language: String) throws {
        #expect(try localized("not.a.real.key", language: language) == Self.missing)
        for trend in Self.trends {
            for period in Self.periods {
                let key = try resource(trend, period).key
                let value = try localized(key, language: language)
                #expect(value != Self.missing, "\(key) in \(language)")
                #expect(value.contains("%@") == (trend != .same), "\(key) in \(language): \(value)")
            }
        }
    }

    @Test(arguments: languages)
    func theFourPeriodsReadDifferently(language: String) throws {
        for trend in Self.trends {
            let values = try Self.periods.map { try localized(try resource(trend, $0).key, language: language) }
            #expect(Set(values).count == Self.periods.count, "\(trend) in \(language)")
        }
    }

    @Test(arguments: languages)
    func budgetMessagesAreTranslated(language: String) throws {
        let left = try localized(L10n.BudgetSummary.left("%@", of: "%@").key, language: language)
        let over = try localized(L10n.BudgetSummary.over("%@").key, language: language)
        #expect(left != Self.missing && over != Self.missing)
        #expect(left.contains("%1$@") && left.contains("%2$@"), "\(language): \(left)")
        #expect(over.contains("%@"), "\(language): \(over)")
    }
}
