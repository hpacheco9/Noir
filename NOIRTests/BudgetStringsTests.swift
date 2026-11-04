//
//  BudgetStringsTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct BudgetStringsTests {
    private static let missing = "<missing>"
    nonisolated static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr", "nb", "da", "fi"]

    private static let resources: [LocalizedStringResource] = [
        L10n.Profile.budget, L10n.Profile.budgetFooter,
        L10n.Onboarding.setBudget, L10n.Onboarding.budgetTitle, L10n.Onboarding.budgetSubtitle,
        L10n.Notification.budgetNearTitle, L10n.Notification.budgetOverTitle,
        L10n.BudgetSummary.left("%@", of: "%@"), L10n.BudgetSummary.over("%@"),
        L10n.Notification.budgetBody(spent: "%@", budget: "%@"),
    ]

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    @Test(arguments: languages)
    func everyBudgetStringIsTranslated(language: String) throws {
        #expect(try localized("budget.not_a_real_key", language: language) == Self.missing)
        for resource in Self.resources {
            let value = try localized(resource.key, language: language)
            #expect(value != Self.missing && !value.isEmpty, "\(resource.key) in \(language)")
        }
    }

    @Test(arguments: languages)
    func amountMessagesKeepTheirAmounts(language: String) throws {
        let left = try localized(L10n.BudgetSummary.left("%@", of: "%@").key, language: language)
        let over = try localized(L10n.BudgetSummary.over("%@").key, language: language)
        let body = try localized(L10n.Notification.budgetBody(spent: "%@", budget: "%@").key, language: language)
        #expect(left.contains("%1$@") && left.contains("%2$@"), "\(language): \(left)")
        #expect(over.contains("%@"), "\(language): \(over)")
        #expect(body.contains("%1$@") && body.contains("%2$@"), "\(language): \(body)")
    }

    @Test func budgetKeysAreUnique() {
        let keys = Self.resources.map(\.key)
        #expect(Set(keys).count == keys.count)
    }
}
