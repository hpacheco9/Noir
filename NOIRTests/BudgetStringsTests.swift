//
//  BudgetStringsTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct BudgetStringsTests {
    nonisolated static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr", "nb", "da", "fi"]

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: "<missing>", table: nil)
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
}
