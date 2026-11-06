//
//  PaywallStringsTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PaywallStringsTests {
    private static let missing = "<missing>"
    nonisolated static let languages = ["en", "pt-PT", "pt-BR", "es", "de", "fr", "nb", "da", "fi"]

    private static let resources: [LocalizedStringResource] = [
        L10n.Paywall.title,
        L10n.Paywall.subtitle,
        L10n.Paywall.restore,
        L10n.Paywall.productsFailed,
        L10n.Paywall.Plan.monthly, L10n.Paywall.Plan.yearly, L10n.Paywall.Plan.lifetime,
        L10n.Paywall.Plan.trialFree(""),
        L10n.Paywall.Plan.monthlyTrial(trial: "", price: ""),
        L10n.Paywall.Plan.monthlyTrialSpoken(trial: "", price: ""),
        L10n.Paywall.Plan.monthlyPrice(""), L10n.Paywall.Plan.monthlyPriceSpoken(""),
        L10n.Paywall.Plan.yearlyPrice(""), L10n.Paywall.Plan.yearlyPriceSpoken(""),
        L10n.Paywall.Plan.lifetimePrice(""),
        L10n.Paywall.CallToAction.startTrial, L10n.Paywall.CallToAction.subscribe, L10n.Paywall.CallToAction.buyLifetime,
        L10n.Paywall.Disclosure.subscription, L10n.Paywall.Disclosure.lifetime,
        L10n.Paywall.Alert.pendingTitle, L10n.Paywall.Alert.pendingMessage,
        L10n.Paywall.Alert.failedTitle, L10n.Paywall.Alert.failedMessage,
        L10n.Paywall.Alert.restoredTitle, L10n.Paywall.Alert.restoredMessage,
        L10n.Paywall.Alert.restoreFailedTitle, L10n.Paywall.Alert.restoreFailedMessage,
        L10n.Paywall.Alert.nothingToRestoreTitle, L10n.Paywall.Alert.nothingToRestoreMessage,
        L10n.Paywall.Feature.insightsTitle, L10n.Paywall.Feature.insightsDescription,
        L10n.Paywall.Feature.widgetsTitle, L10n.Paywall.Feature.widgetsDescription,
        L10n.Paywall.Feature.shortcutsTitle, L10n.Paywall.Feature.shortcutsDescription,
        L10n.Paywall.Feature.categoriesTitle, L10n.Paywall.Feature.categoriesDescription,
        L10n.Paywall.Feature.privacyTitle, L10n.Paywall.Feature.privacyDescription,
        L10n.Subscription.title, L10n.Subscription.manage, L10n.Subscription.lifetime,
        L10n.Legal.termsOfUse,
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

    // Every price line keeps the store's own text, in the right order, in every language.
    @Test(arguments: languages)
    func priceLinesCarryTheStoreText(language: String) throws {
        let lines: [(LocalizedStringResource, [String])] = [
            (L10n.Paywall.Plan.trialFree(""), ["3 days"]),
            (L10n.Paywall.Plan.monthlyTrial(trial: "", price: ""), ["3 days", "2,99 €"]),
            (L10n.Paywall.Plan.monthlyTrialSpoken(trial: "", price: ""), ["3 days", "2,99 €"]),
            (L10n.Paywall.Plan.monthlyPrice(""), ["2,99 €"]),
            (L10n.Paywall.Plan.monthlyPriceSpoken(""), ["2,99 €"]),
            (L10n.Paywall.Plan.yearlyPrice(""), ["19,99 €"]),
            (L10n.Paywall.Plan.yearlyPriceSpoken(""), ["19,99 €"]),
            (L10n.Paywall.Plan.lifetimePrice(""), ["49,99 €"]),
        ]
        for (resource, arguments) in lines {
            let format = try localized(resource.key, language: language)
            let text = String(format: format, arguments: arguments)
            for argument in arguments {
                #expect(text.contains(argument), "\(resource.key) in \(language): \(text)")
            }
            if arguments.count == 2 {
                #expect(text.range(of: arguments[0])!.lowerBound < text.range(of: arguments[1])!.lowerBound, "\(language): \(text)")
            }
        }
    }

    // The visible "/month" would be read as "slash month"; the spoken lines must spell the period out.
    @Test(arguments: languages)
    func spokenLinesHaveNoSlash(language: String) throws {
        let spoken: [LocalizedStringResource] = [
            L10n.Paywall.Plan.monthlyPriceSpoken(""), L10n.Paywall.Plan.yearlyPriceSpoken(""),
            L10n.Paywall.Plan.monthlyTrialSpoken(trial: "", price: ""),
        ]
        for resource in spoken {
            #expect(!(try localized(resource.key, language: language)).contains("/"), "\(resource.key) in \(language)")
        }
        #expect(try localized(L10n.Paywall.Plan.monthlyPrice("").key, language: language).contains("/"))
    }

    @Test func priceCheckFiresOnAFormatWithoutThePrice() {
        #expect(!String(format: "no placeholder", arguments: ["2,99 €"]).contains("2,99 €"))
        #expect(String(format: "%@/month", arguments: ["2,99 €"]).contains("2,99 €"))
    }
}
