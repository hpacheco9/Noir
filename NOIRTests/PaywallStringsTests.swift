//
//  PaywallStringsTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PaywallStringsTests {
    private static let missing = "<missing>"
    nonisolated static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr"]

    private static let resources: [LocalizedStringResource] = [
        L10n.Paywall.title,
        L10n.Paywall.unlock(price: "9.99"),
        L10n.Paywall.restore,
        L10n.Paywall.continueFree,
        L10n.Paywall.Feature.syncTitle, L10n.Paywall.Feature.syncDescription,
        L10n.Paywall.Feature.categoriesTitle, L10n.Paywall.Feature.categoriesDescription,
        L10n.Paywall.Feature.widgetsTitle, L10n.Paywall.Feature.widgetsDescription,
        L10n.Paywall.Feature.insightsTitle, L10n.Paywall.Feature.insightsDescription,
        L10n.Paywall.Feature.exportTitle, L10n.Paywall.Feature.exportDescription,
        L10n.NoirPro.description,
        L10n.Legal.termsOfService,
        L10n.Legal.privacyPolicy,
    ]

    private func localized(_ key: String, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: Self.missing, table: nil)
    }

    @Test(arguments: languages)
    func everyPaywallStringIsTranslated(language: String) throws {
        #expect(try localized("paywall.not_a_real_key", language: language) == Self.missing)
        for resource in Self.resources {
            let value = try localized(resource.key, language: language)
            #expect(value != Self.missing && !value.isEmpty, "\(resource.key) in \(language)")
        }
    }

    @Test func paywallKeysAreUnique() {
        let keys = Self.resources.map(\.key)
        #expect(Set(keys).count == keys.count)
    }

    @Test(arguments: languages)
    func unlockButtonCarriesThePrice(language: String) throws {
        let format = try localized(L10n.Paywall.unlock(price: "").key, language: language)
        #expect(format.contains("%@"), "\(language): \(format)")
        #expect(String(format: format, "9,99 €").contains("9,99 €"))
    }

    @Test func unlockButtonUsesTheUsersCurrency() {
        let price = CurrencyPreference.string(for: 9.99, code: "USD")
        #expect(price == "$9.99")
        #expect(String(localized: L10n.Paywall.unlock(price: price)).contains(price))
    }
}
