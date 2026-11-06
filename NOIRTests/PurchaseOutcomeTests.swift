//
//  PurchaseOutcomeTests.swift
//  NOIRTests
//

import Testing
import Foundation
import RevenueCat
@testable import NOIR

struct PurchaseOutcomeTests {
    // MARK: Purchase returned

    @Test func cancelledWinsWhateverTheAccess() {
        #expect(PurchaseOutcome(userCancelled: true, hasAccess: false) == .cancelled)
        #expect(PurchaseOutcome(userCancelled: true, hasAccess: true) == .cancelled)
    }

    @Test func purchaseSucceedsOnlyWithAnActiveEntitlement() {
        #expect(PurchaseOutcome(userCancelled: false, hasAccess: true) == .success)
        #expect(PurchaseOutcome(userCancelled: false, hasAccess: false) == .failed)
    }

    // MARK: Restore returned

    @Test func restoreSucceedsOnlyWithAnActiveEntitlement() {
        #expect(PurchaseOutcome(restoredWithAccess: true) == .success)
        #expect(PurchaseOutcome(restoredWithAccess: false) == .nothingToRestore)
    }

    // MARK: Purchase threw

    @Test func userCancelledErrorIsCancelled() {
        #expect(PurchaseOutcome(error: ErrorCode.purchaseCancelledError) == .cancelled)
    }

    @Test func paymentPendingErrorIsPending() {
        #expect(PurchaseOutcome(error: ErrorCode.paymentPendingError) == .pending)
    }

    @Test func otherRevenueCatErrorsFail() {
        #expect(PurchaseOutcome(error: ErrorCode.networkError) == .failed)
        #expect(PurchaseOutcome(error: ErrorCode.storeProblemError) == .failed)
    }

    @Test func unrelatedErrorsFail() {
        #expect(PurchaseOutcome(error: URLError(.notConnectedToInternet)) == .failed)
        #expect(PurchaseOutcome(error: NSError(domain: "other", code: ErrorCode.paymentPendingError.rawValue)) == .failed)
    }

    // RevenueCat throws its errors as NSError, so the mapping must survive that bridge.
    @Test func mappingSurvivesTheNSErrorBridge() {
        #expect(PurchaseOutcome(error: ErrorCode.purchaseCancelledError as NSError) == .cancelled)
        #expect(PurchaseOutcome(error: ErrorCode.paymentPendingError as NSError) == .pending)
        #expect(PurchaseOutcome(error: ErrorCode.networkError as NSError) == .failed)
    }
}
