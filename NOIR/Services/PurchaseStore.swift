//
//  PurchaseStore.swift
//  NOIR
//

import Foundation
import Observation
import RevenueCat
import WidgetKit

@Observable
final class PurchaseStore {
    static let shared = PurchaseStore()

    // The payment sheet makes the scene inactive and active again, and a customer info fetched before the
    // purchase can land after it, so an answer this old never takes access away.
    static let freshness: TimeInterval = 60

    struct Price: Equatable {
        let total: String
        let perMonth: String?
    }

    private(set) var monthly: Package?
    private(set) var yearly: Package?
    private(set) var lifetime: Package?
    // Set only while monthly's free trial is on offer for this Apple Account.
    private(set) var trialLength: String?
    private(set) var productsFailed = false
    private(set) var ownedPlans: Set<PaywallPlan> = []

    private var liveAccess: Bool?
    @ObservationIgnored private let cachedAccess: Bool?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults? = MonthTotalSnapshot.sharedDefaults) {
        self.defaults = defaults
        cachedAccess = defaults.flatMap(ProAccess.cached(in:))
    }

    var hasAccess: Bool { (liveAccess ?? cachedAccess) ?? false }

    // False only on a first run with no cache and no answer yet.
    var isAccessKnown: Bool { (liveAccess ?? cachedAccess) != nil }

    var isLifetime: Bool { ownedPlans.contains(.lifetime) }

    var isSubscriber: Bool { ownedPlans.contains(.monthly) || ownedPlans.contains(.yearly) }

    var availablePlans: [PaywallPlan] { PaywallPlan.allCases.filter { package(for: $0) != nil } }

    func price(for plan: PaywallPlan) -> Price? {
        guard let product = package(for: plan)?.storeProduct else { return nil }
        return Price(total: product.localizedPriceString, perMonth: plan == .yearly ? product.localizedPricePerMonth : nil)
    }

    func start() {
        guard Purchases.isConfigured, updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
    }

    // Products only: RevenueCat refreshes customer info on launch and foreground by itself and the stream delivers it.
    func refresh() async {
        guard Purchases.isConfigured else { return }
        do {
            let packages = try await Purchases.shared.offerings().current?.availablePackages ?? []
            var trialEligible = false
            if let monthly = Self.package(for: .monthly, in: packages) {
                trialEligible = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: monthly.storeProduct) == .eligible
            }
            apply(packages: packages, trialEligible: trialEligible)
        } catch {
            productsFailed = availablePlans.isEmpty
        }
    }

    // For intents, which have no UI to keep the stream alive: a fresh answer, kept on error.
    func refreshAccess() async {
        guard Purchases.isConfigured,
              let info = try? await Purchases.shared.customerInfo(fetchPolicy: .notStaleCachedOrFetched) else { return }
        apply(info)
    }

    func purchase(_ plan: PaywallPlan) async -> PurchaseOutcome {
        guard Purchases.isConfigured, let package = package(for: plan) else { return .failed }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            return PurchaseOutcome(userCancelled: result.userCancelled, hasAccess: Self.isPro(result.customerInfo))
        } catch {
            return PurchaseOutcome(error: error)
        }
    }

    func restore() async -> PurchaseOutcome {
        guard Purchases.isConfigured else { return .failed }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return PurchaseOutcome(restoredWithAccess: Self.isPro(info))
        } catch {
            return PurchaseOutcome(error: error)
        }
    }

    // Packages, their trial and the failure flag change together, so the paywall never shows half an update.
    func apply(packages: [Package], trialEligible: Bool) {
        monthly = Self.package(for: .monthly, in: packages)
        yearly = Self.package(for: .yearly, in: packages)
        lifetime = Self.package(for: .lifetime, in: packages)
        trialLength = trialEligible ? TrialLength.text(for: monthly?.storeProduct.introductoryDiscount) : nil
        productsFailed = availablePlans.isEmpty
    }

    // An old "no access" can't revoke a current "access"; only a fresh answer does.
    func receive(hasAccess: Bool, ownedPlans: Set<PaywallPlan> = [], requestDate: Date, now: Date = .now) {
        if !hasAccess, self.hasAccess, now.timeIntervalSince(requestDate) > Self.freshness { return }
        apply(hasAccess: hasAccess, ownedPlans: ownedPlans)
    }

    func apply(hasAccess: Bool, ownedPlans: Set<PaywallPlan> = []) {
        liveAccess = hasAccess
        self.ownedPlans = hasAccess ? ownedPlans : []
        // The widget reads the cache, so it only needs a reload when the cached value actually changed.
        if let defaults, ProAccess.cache(hasAccess, in: defaults) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func apply(_ info: CustomerInfo) {
        receive(
            hasAccess: Self.isPro(info),
            ownedPlans: PaywallPlan.owned(
                activeSubscriptions: info.activeSubscriptions,
                nonSubscriptions: Set(info.nonSubscriptions.map(\.productIdentifier))
            ),
            requestDate: info.requestDate
        )
    }

    private func package(for plan: PaywallPlan) -> Package? {
        switch plan {
        case .monthly: monthly
        case .yearly: yearly
        case .lifetime: lifetime
        }
    }

    private static func package(for plan: PaywallPlan, in packages: [Package]) -> Package? {
        packages.first { $0.storeProduct.productIdentifier == plan.productID }
    }

    private static func isPro(_ info: CustomerInfo) -> Bool {
        info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
    }
}
