//
//  PurchaseStoreTests.swift
//  NOIRTests
//

import Testing
import Foundation
import RevenueCat
@testable import NOIR

struct PurchaseStoreTests {
    private func withIsolatedDefaults<T>(cached: Bool? = nil, _ body: (UserDefaults) throws -> T) rethrows -> T {
        let suite = "NOIRTests.purchaseStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        if let cached { ProAccess.cache(cached, in: defaults) }
        return try body(defaults)
    }

    // MARK: Cache against the live answer

    @Test func startsFromTheCachedGrant() {
        withIsolatedDefaults(cached: true) { defaults in
            let store = PurchaseStore(defaults: defaults)
            #expect(store.hasAccess)
            #expect(store.isAccessKnown)
        }
    }

    @Test func withoutCacheItDeniesAndIsNotKnown() {
        withIsolatedDefaults { defaults in
            let store = PurchaseStore(defaults: defaults)
            #expect(!store.hasAccess)
            #expect(!store.isAccessKnown)
            store.apply(hasAccess: true)
            #expect(store.hasAccess)
            #expect(store.isAccessKnown)
            #expect(ProAccess.cached(in: defaults) == true)
        }
    }

    @Test func aLiveDenialReplacesACachedGrant() {
        withIsolatedDefaults(cached: true) { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.apply(hasAccess: false)
            #expect(!store.hasAccess)
            #expect(ProAccess.cached(in: defaults) == false)
        }
    }

    @Test func aLiveGrantReplacesACachedDenial() {
        withIsolatedDefaults(cached: false) { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.apply(hasAccess: true)
            #expect(store.hasAccess)
            #expect(ProAccess.cached(in: defaults) == true)
        }
    }

    // MARK: Stale answers

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aStaleDenialKeepsAccess() {
        withIsolatedDefaults(cached: true) { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.receive(hasAccess: false, requestDate: now.addingTimeInterval(-3_600), now: now)
            #expect(store.hasAccess)
            #expect(ProAccess.cached(in: defaults) == true)
        }
    }

    @Test func aFreshDenialRevokesAccess() {
        withIsolatedDefaults(cached: true) { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.receive(hasAccess: false, requestDate: now.addingTimeInterval(-5), now: now)
            #expect(!store.hasAccess)
            #expect(ProAccess.cached(in: defaults) == false)
        }
    }

    @Test func aStaleGrantStillGrants() {
        withIsolatedDefaults(cached: false) { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.receive(hasAccess: true, ownedPlans: [.lifetime], requestDate: now.addingTimeInterval(-3_600), now: now)
            #expect(store.hasAccess)
            #expect(store.isLifetime)
        }
    }

    @Test func aStaleDenialIsIgnoredAfterALiveGrantToo() {
        withIsolatedDefaults { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.apply(hasAccess: true)
            store.receive(hasAccess: false, requestDate: now.addingTimeInterval(-300), now: now)
            #expect(store.hasAccess)
        }
    }

    // MARK: Owned plans

    @Test func lifetimeAndSubscriptionAreIndependent() {
        withIsolatedDefaults { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.apply(hasAccess: true, ownedPlans: [.lifetime])
            #expect(store.isLifetime && !store.isSubscriber)
            store.apply(hasAccess: true, ownedPlans: [.yearly])
            #expect(store.isSubscriber && !store.isLifetime)
            store.apply(hasAccess: true, ownedPlans: [.monthly, .lifetime])
            #expect(store.isSubscriber && store.isLifetime)
        }
    }

    @Test func noOwnedPlansWithoutAccess() {
        withIsolatedDefaults { defaults in
            let store = PurchaseStore(defaults: defaults)
            store.apply(hasAccess: false, ownedPlans: [.yearly])
            #expect(!store.isSubscriber && !store.isLifetime)
        }
    }

    // MARK: Packages

    private func package(_ plan: PaywallPlan, price: String, perMonth: String? = nil, trial: StoreProductDiscount? = nil) -> Package {
        var product = TestStoreProduct(
            localizedTitle: "NOIR Pro",
            price: Decimal(string: price.filter { $0.isNumber || $0 == "," }.replacingOccurrences(of: ",", with: ".")) ?? 1,
            currencyCode: "EUR",
            localizedPriceString: price,
            productIdentifier: plan.productID,
            productType: plan.isSubscription ? .autoRenewableSubscription : .nonConsumable,
            localizedDescription: "",
            subscriptionPeriod: plan == .monthly ? .init(value: 1, unit: .month) : plan == .yearly ? .init(value: 1, unit: .year) : nil,
            locale: Locale(identifier: "pt_PT")
        )
        product.localizedPricePerMonth = perMonth
        product.introductoryDiscount = trial
        return Package(identifier: plan.productID, packageType: .custom, storeProduct: product.toStoreProduct(), offeringIdentifier: "default", webCheckoutUrl: nil)
    }

    private func freeTrial(days: Int) -> StoreProductDiscount {
        TestStoreProductDiscount(
            identifier: "trial", price: 0, localizedPriceString: "0 €", paymentMode: .freeTrial,
            subscriptionPeriod: .init(value: days, unit: .day), numberOfPeriods: 1, type: .introductory
        ).toStoreProductDiscount()
    }

    @Test func packagesAreMatchedByProductIDWhateverTheirOrder() {
        let store = PurchaseStore(defaults: nil)
        store.apply(packages: [package(.lifetime, price: "49,99 €"), package(.yearly, price: "19,99 €"), package(.monthly, price: "2,99 €")], trialEligible: false)
        #expect(store.availablePlans == [.monthly, .yearly, .lifetime])
        #expect(store.price(for: .monthly)?.total == "2,99 €")
        #expect(store.price(for: .yearly)?.total == "19,99 €")
        #expect(store.price(for: .lifetime)?.total == "49,99 €")
        #expect(!store.productsFailed)
    }

    @Test func unknownProductsAreIgnoredAndNothingLoadedFails() {
        let store = PurchaseStore(defaults: nil)
        store.apply(packages: [package(.yearly, price: "19,99 €")], trialEligible: false)
        #expect(store.availablePlans == [.yearly])
        #expect(!store.productsFailed)
        store.apply(packages: [], trialEligible: false)
        #expect(store.availablePlans.isEmpty)
        #expect(store.productsFailed)
    }

    @Test func onlyYearlyCarriesAMonthlyEquivalent() {
        let store = PurchaseStore(defaults: nil)
        store.apply(packages: [
            package(.monthly, price: "2,99 €", perMonth: "2,99 €"),
            package(.yearly, price: "19,99 €", perMonth: "1,67 €"),
            package(.lifetime, price: "49,99 €", perMonth: "4,16 €"),
        ], trialEligible: false)
        // RevenueCat derives it from the price and rounds down (19,99 / 12 = 1,6658), with pt_PT's no-break space.
        #expect(store.price(for: .yearly)?.perMonth == "1,66\u{00A0}€")
        #expect(store.price(for: .monthly)?.perMonth == nil)
        #expect(store.price(for: .lifetime)?.perMonth == nil)
    }

    @Test func noPriceForAPlanThatDidNotLoad() {
        let store = PurchaseStore(defaults: nil)
        #expect(store.price(for: .monthly) == nil)
    }

    // MARK: Trial

    @Test func trialShowsOnlyWhenEligibleAndFree() {
        let store = PurchaseStore(defaults: nil)
        let monthly = package(.monthly, price: "2,99 €", trial: freeTrial(days: 3))
        store.apply(packages: [monthly], trialEligible: true)
        #expect(store.trialLength != nil)
        store.apply(packages: [monthly], trialEligible: false)
        #expect(store.trialLength == nil)
    }

    @Test func noTrialWithoutAFreeIntroOffer() {
        let store = PurchaseStore(defaults: nil)
        store.apply(packages: [package(.monthly, price: "2,99 €")], trialEligible: true)
        #expect(store.trialLength == nil)
        let paid = TestStoreProductDiscount(
            identifier: "intro", price: 1, localizedPriceString: "1 €", paymentMode: .payAsYouGo,
            subscriptionPeriod: .init(value: 1, unit: .month), numberOfPeriods: 1, type: .introductory
        ).toStoreProductDiscount()
        store.apply(packages: [package(.monthly, price: "2,99 €", trial: paid)], trialEligible: true)
        #expect(store.trialLength == nil)
    }

    // MARK: Unconfigured

    // Under test RevenueCat is never configured, which is also what a SwiftUI preview sees.
    @Test func unconfiguredStoreFailsInsteadOfCrashing() async {
        let store = PurchaseStore(defaults: nil)
        #expect(await store.purchase(.monthly) == .failed)
        #expect(await store.restore() == .failed)
        await store.refresh()
        await store.refreshAccess()
        store.start()
        #expect(!store.hasAccess)
    }
}
