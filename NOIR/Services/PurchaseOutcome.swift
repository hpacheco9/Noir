//
//  PurchaseOutcome.swift
//  NOIR
//

import Foundation
import RevenueCat

nonisolated enum PurchaseOutcome: Equatable, Sendable {
    case success
    case pending
    case cancelled
    case failed
    case nothingToRestore

    // A purchase only counts once the entitlement is active.
    init(userCancelled: Bool, hasAccess: Bool) {
        self = userCancelled ? .cancelled : (hasAccess ? .success : .failed)
    }

    init(restoredWithAccess hasAccess: Bool) {
        self = hasAccess ? .success : .nothingToRestore
    }

    init(error: Error) {
        switch error as? ErrorCode {
        case .purchaseCancelledError: self = .cancelled
        case .paymentPendingError: self = .pending
        default: self = .failed
        }
    }
}
