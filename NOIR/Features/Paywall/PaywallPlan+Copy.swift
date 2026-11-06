//
//  PaywallPlan+Copy.swift
//  NOIR
//

import Foundation

// `spoken` is what VoiceOver reads, where the visible "/month" would be read as "slash month".
struct PaywallLine {
    let text: LocalizedStringResource
    let spoken: LocalizedStringResource
}

@MainActor
extension PaywallPlan {
    var title: LocalizedStringResource {
        switch self {
        case .monthly: L10n.Paywall.Plan.monthly
        case .yearly: L10n.Paywall.Plan.yearly
        case .lifetime: L10n.Paywall.Plan.lifetime
        }
    }

    var disclosure: LocalizedStringResource {
        isSubscription ? L10n.Paywall.Disclosure.subscription : L10n.Paywall.Disclosure.lifetime
    }

    func callToAction(hasTrial: Bool) -> LocalizedStringResource {
        switch self {
        case .monthly: hasTrial ? L10n.Paywall.CallToAction.startTrial : L10n.Paywall.CallToAction.subscribe
        case .yearly: L10n.Paywall.CallToAction.subscribe
        case .lifetime: L10n.Paywall.CallToAction.buyLifetime
        }
    }

    // What the plan bills, always the most prominent line of its row.
    func priceLine(_ price: String) -> PaywallLine {
        switch self {
        case .monthly: PaywallLine(text: L10n.Paywall.Plan.monthlyPrice(price), spoken: L10n.Paywall.Plan.monthlyPriceSpoken(price))
        case .yearly: PaywallLine(text: L10n.Paywall.Plan.yearlyPrice(price), spoken: L10n.Paywall.Plan.yearlyPriceSpoken(price))
        case .lifetime: PaywallLine(text: L10n.Paywall.Plan.lifetimePrice(price), spoken: L10n.Paywall.Plan.lifetimePrice(price))
        }
    }

    // The trial for monthly, the monthly equivalent for yearly.
    func secondaryLine(price: PurchaseStore.Price, trialLength: String?) -> PaywallLine? {
        switch self {
        case .monthly:
            trialLength.map {
                let text = L10n.Paywall.Plan.trialFree($0)
                return PaywallLine(text: text, spoken: text)
            }
        case .yearly:
            price.perMonth.map {
                PaywallLine(text: L10n.Paywall.Plan.monthlyPrice($0), spoken: L10n.Paywall.Plan.monthlyPriceSpoken($0))
            }
        case .lifetime:
            nil
        }
    }

    // Under the button while the trial is selected: how long it lasts and what follows.
    static func trialCaption(trialLength: String, price: String) -> PaywallLine {
        PaywallLine(
            text: L10n.Paywall.Plan.monthlyTrial(trial: trialLength, price: price),
            spoken: L10n.Paywall.Plan.monthlyTrialSpoken(trial: trialLength, price: price)
        )
    }
}
