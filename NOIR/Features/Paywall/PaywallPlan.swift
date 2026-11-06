//
//  PaywallPlan.swift
//  NOIR
//

import Foundation

nonisolated enum PaywallPlan: CaseIterable, Identifiable, Sendable {
    case monthly, yearly, lifetime

    var id: Self { self }

    var isSubscription: Bool { self != .lifetime }

    var productID: String {
        switch self {
        case .monthly: RevenueCatConfig.monthlyProductID
        case .yearly: RevenueCatConfig.yearlyProductID
        case .lifetime: RevenueCatConfig.lifetimeProductID
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    // Monthly leads while its free trial is on offer (the button then reads "Start Free Trial"), otherwise yearly.
    static func initialSelection(hasTrial: Bool, available: [PaywallPlan]) -> PaywallPlan? {
        let preferred: PaywallPlan = hasTrial ? .monthly : .yearly
        return available.contains(preferred) ? preferred : allCases.first { available.contains($0) }
    }

    // Subscriptions come from the active ones, lifetime from the purchases that never expire.
    static func owned(activeSubscriptions: Set<String>, nonSubscriptions: Set<String>) -> Set<PaywallPlan> {
        Set(allCases.filter { ($0.isSubscription ? activeSubscriptions : nonSubscriptions).contains($0.productID) })
    }
}
