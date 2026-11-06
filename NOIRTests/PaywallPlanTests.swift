//
//  PaywallPlanTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PaywallPlanTests {
    // MARK: Preselected plan

    @Test func trialLeadsWhileItIsOnOffer() {
        #expect(PaywallPlan.initialSelection(hasTrial: true, available: PaywallPlan.allCases) == .monthly)
        #expect(PaywallPlan.initialSelection(hasTrial: false, available: PaywallPlan.allCases) == .yearly)
    }

    @Test func missingPreferredPlanFallsBackToTheFirstAvailable() {
        #expect(PaywallPlan.initialSelection(hasTrial: true, available: [.yearly, .lifetime]) == .yearly)
        #expect(PaywallPlan.initialSelection(hasTrial: false, available: [.monthly, .lifetime]) == .monthly)
        #expect(PaywallPlan.initialSelection(hasTrial: true, available: [.lifetime]) == .lifetime)
        #expect(PaywallPlan.initialSelection(hasTrial: true, available: []) == nil)
    }

    // MARK: Button

    @Test func trialButtonOnlyForMonthlyWhileOnOffer() {
        #expect(PaywallPlan.monthly.callToAction(hasTrial: true).key == L10n.Paywall.CallToAction.startTrial.key)
        #expect(PaywallPlan.monthly.callToAction(hasTrial: false).key == L10n.Paywall.CallToAction.subscribe.key)
        for hasTrial in [true, false] {
            #expect(PaywallPlan.yearly.callToAction(hasTrial: hasTrial).key == L10n.Paywall.CallToAction.subscribe.key)
            #expect(PaywallPlan.lifetime.callToAction(hasTrial: hasTrial).key == L10n.Paywall.CallToAction.buyLifetime.key)
        }
    }

    // MARK: Plan rows

    private let price = PurchaseStore.Price(total: "19,99 €", perMonth: "1,67 €")

    @Test func billedPriceIsTheLeadLineOfEveryPlan() {
        for plan in PaywallPlan.allCases {
            let line = plan.priceLine("49,99 €")
            #expect(String(localized: line.text).contains("49,99 €"), "\(plan)")
            #expect(String(localized: line.spoken).contains("49,99 €"), "\(plan)")
        }
    }

    @Test func spokenPriceNeverReadsSlash() {
        for plan in [PaywallPlan.monthly, .yearly] {
            let line = plan.priceLine("2,99 €")
            #expect(String(localized: line.text).contains("/"), "\(plan)")
            #expect(!String(localized: line.spoken).contains("/"), "\(plan)")
        }
    }

    @Test func monthlyShowsItsTrialOnTheSecondLine() {
        let withTrial = PaywallPlan.monthly.secondaryLine(price: price, trialLength: "3 days")
        #expect(withTrial.map { String(localized: $0.text).contains("3 days") } == true)
        #expect(PaywallPlan.monthly.secondaryLine(price: price, trialLength: nil) == nil)
    }

    @Test func yearlyShowsTheMonthlyEquivalentOnTheSecondLine() {
        let line = PaywallPlan.yearly.secondaryLine(price: price, trialLength: "3 days")
        #expect(line.map { String(localized: $0.text).contains("1,67 €") } == true)
        #expect(PaywallPlan.yearly.secondaryLine(price: PurchaseStore.Price(total: "19,99 €", perMonth: nil), trialLength: nil) == nil)
        #expect(PaywallPlan.lifetime.secondaryLine(price: price, trialLength: "3 days") == nil)
    }

    @Test func trialCaptionStatesTheLengthAndWhatFollows() {
        let caption = PaywallPlan.trialCaption(trialLength: "3 days", price: "2,99 €")
        for text in [String(localized: caption.text), String(localized: caption.spoken)] {
            #expect(text.contains("3 days") && text.contains("2,99 €"), Comment(rawValue: text))
        }
        #expect(!String(localized: caption.spoken).contains("/"))
    }

    // MARK: Product ids

    @Test func productIDsRoundTrip() {
        for plan in PaywallPlan.allCases {
            #expect(PaywallPlan(productID: plan.productID) == plan)
        }
        #expect(PaywallPlan(productID: "henrique-dev.NOIR.pro.weekly") == nil)
    }

    // MARK: Owned plans

    private let monthlyID = PaywallPlan.monthly.productID
    private let yearlyID = PaywallPlan.yearly.productID
    private let lifetimeID = PaywallPlan.lifetime.productID

    @Test func ownedPlansComeFromTheRightPurchaseKind() {
        #expect(PaywallPlan.owned(activeSubscriptions: [monthlyID], nonSubscriptions: []) == [.monthly])
        #expect(PaywallPlan.owned(activeSubscriptions: [], nonSubscriptions: [lifetimeID]) == [.lifetime])
        #expect(PaywallPlan.owned(activeSubscriptions: [yearlyID], nonSubscriptions: [lifetimeID]) == [.yearly, .lifetime])
    }

    @Test func aLifetimeIdIsNotASubscriptionAndViceVersa() {
        #expect(PaywallPlan.owned(activeSubscriptions: [lifetimeID], nonSubscriptions: [monthlyID]).isEmpty)
        #expect(PaywallPlan.owned(activeSubscriptions: ["other"], nonSubscriptions: []).isEmpty)
    }

    // MARK: Disclosure

    @Test func subscriptionsAndLifetimeGetTheirOwnDisclosure() {
        #expect(PaywallPlan.monthly.disclosure.key == PaywallPlan.yearly.disclosure.key)
        #expect(PaywallPlan.lifetime.disclosure.key != PaywallPlan.yearly.disclosure.key)
    }
}
