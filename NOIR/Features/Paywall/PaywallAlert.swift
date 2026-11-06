//
//  PaywallAlert.swift
//  NOIR
//

import SwiftUI

enum PaywallAlert: Identifiable, Equatable {
    case pending, purchaseFailed, restored, restoreFailed, nothingToRestore

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .pending: L10n.Paywall.Alert.pendingTitle
        case .purchaseFailed: L10n.Paywall.Alert.failedTitle
        case .restored: L10n.Paywall.Alert.restoredTitle
        case .restoreFailed: L10n.Paywall.Alert.restoreFailedTitle
        case .nothingToRestore: L10n.Paywall.Alert.nothingToRestoreTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .pending: L10n.Paywall.Alert.pendingMessage
        case .purchaseFailed: L10n.Paywall.Alert.failedMessage
        case .restored: L10n.Paywall.Alert.restoredMessage
        case .restoreFailed: L10n.Paywall.Alert.restoreFailedMessage
        case .nothingToRestore: L10n.Paywall.Alert.nothingToRestoreMessage
        }
    }

    // A purchase that succeeds just unlocks the app; a restore also says so, since Settings stays on screen.
    static func alert(for outcome: PurchaseOutcome, restoring: Bool) -> PaywallAlert? {
        switch outcome {
        case .success: restoring ? .restored : nil
        case .cancelled: nil
        case .pending: .pending
        case .failed: restoring ? .restoreFailed : .purchaseFailed
        case .nothingToRestore: .nothingToRestore
        }
    }

    static func haptic(for outcome: PurchaseOutcome) -> HapticFeedback? {
        switch outcome {
        case .success: .success
        case .failed: .error
        case .pending, .cancelled, .nothingToRestore: nil
        }
    }

    // Plays the outcome's haptic and returns the alert to show.
    static func report(_ outcome: PurchaseOutcome, restoring: Bool) -> PaywallAlert? {
        if let haptic = haptic(for: outcome) { Haptics.play(haptic) }
        return alert(for: outcome, restoring: restoring)
    }
}

extension View {
    func paywallAlert(_ alert: Binding<PaywallAlert?>) -> some View {
        modifier(PaywallAlertModifier(alert: alert))
    }
}

private struct PaywallAlertModifier: ViewModifier {
    @Binding var alert: PaywallAlert?
    // Kept while the alert animates away, so its title doesn't flash the fallback.
    @State private var shown: PaywallAlert?

    func body(content: Content) -> some View {
        content
            .onChange(of: alert) { _, new in
                if let new { shown = new }
            }
            .alert(Text((alert ?? shown)?.title ?? L10n.Shared.unexpectedError), isPresented: .init(
                get: { alert != nil },
                set: { if !$0 { alert = nil } }
            )) {
                Button(String(localized: L10n.Shared.ok), role: .cancel) { alert = nil }
            } message: {
                if let current = alert ?? shown { Text(current.message) }
            }
    }
}
