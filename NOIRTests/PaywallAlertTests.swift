//
//  PaywallAlertTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PaywallAlertTests {
    @Test func aPurchaseSuccessAndACancelAreSilent() {
        #expect(PaywallAlert.alert(for: .success, restoring: false) == nil)
        for restoring in [true, false] {
            #expect(PaywallAlert.alert(for: .cancelled, restoring: restoring) == nil)
        }
    }

    @Test func aSuccessfulRestoreConfirms() {
        #expect(PaywallAlert.alert(for: .success, restoring: true) == .restored)
    }

    @Test func pendingExplainsTheWait() {
        #expect(PaywallAlert.alert(for: .pending, restoring: false) == .pending)
    }

    @Test func nothingToRestoreIsItsOwnMessage() {
        #expect(PaywallAlert.alert(for: .nothingToRestore, restoring: true) == .nothingToRestore)
        #expect(PaywallAlert.alert(for: .failed, restoring: true) == .restoreFailed)
    }

    @Test func failureNamesWhatFailed() {
        #expect(PaywallAlert.alert(for: .failed, restoring: false) == .purchaseFailed)
        #expect(PaywallAlert.alert(for: .failed, restoring: true) == .restoreFailed)
    }

    @Test func hapticsFollowTheOutcome() {
        #expect(PaywallAlert.haptic(for: .success) == .success)
        #expect(PaywallAlert.haptic(for: .failed) == .error)
        #expect(PaywallAlert.haptic(for: .pending) == nil)
        #expect(PaywallAlert.haptic(for: .cancelled) == nil)
        #expect(PaywallAlert.haptic(for: .nothingToRestore) == nil)
    }}
