//
//  TrialLengthTests.swift
//  NOIRTests
//

import Testing
import Foundation
import RevenueCat
@testable import NOIR

struct TrialLengthTests {
    private let english = Locale(identifier: "en_US")

    private func discount(
        _ mode: StoreProductDiscount.PaymentMode,
        _ value: Int,
        _ unit: SubscriptionPeriod.Unit,
        periods: Int = 1
    ) -> StoreProductDiscount {
        TestStoreProductDiscount(
            identifier: "intro", price: 0, localizedPriceString: "0 €", paymentMode: mode,
            subscriptionPeriod: .init(value: value, unit: unit), numberOfPeriods: periods, type: .introductory
        ).toStoreProductDiscount()
    }

    @Test func freeTrialReadsAsItsLength() {
        #expect(TrialLength.text(for: discount(.freeTrial, 3, .day), locale: english) == "3 days")
        #expect(TrialLength.text(for: discount(.freeTrial, 1, .week), locale: english) == "1 week")
        #expect(TrialLength.text(for: discount(.freeTrial, 1, .month), locale: english) == "1 month")
        #expect(TrialLength.text(for: discount(.freeTrial, 1, .year), locale: english) == "1 year")
    }

    @Test func periodsMultiplyTheLength() {
        #expect(TrialLength.text(for: discount(.freeTrial, 1, .week, periods: 2), locale: english) == "2 weeks")
        #expect(TrialLength.text(for: discount(.freeTrial, 3, .day, periods: 2), locale: english) == "6 days")
    }

    @Test func onlyAFreeTrialCounts() {
        #expect(TrialLength.text(for: discount(.payAsYouGo, 3, .day), locale: english) == nil)
        #expect(TrialLength.text(for: discount(.payUpFront, 3, .day), locale: english) == nil)
        #expect(TrialLength.text(for: nil, locale: english) == nil)
    }

    @Test func followsTheGivenLanguage() {
        let portuguese = TrialLength.text(for: discount(.freeTrial, 3, .day), locale: Locale(identifier: "pt_PT"))
        #expect(portuguese?.contains("3") == true)
        #expect(portuguese != "3 days")
    }
}
