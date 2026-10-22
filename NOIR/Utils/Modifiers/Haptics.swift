//
//  Haptics.swift
//  NOIR
//

import UIKit

/// For action closures and async completions, where there is no state to attach `.hapticFeedback` to.
enum Haptics {
    static func play(_ kind: HapticFeedback) {
        // No foreground window (background, App Intent): nothing to attach the generator to.
        guard let view = foregroundKeyWindow else { return }
        play(kind, in: view, defaults: .standard)
    }

    // `init(view:)` installs a UIInteraction on the view that nothing removes, so generators are cached (one per
    // type) and rebuilt only when the view changes, removing the old interactions first.
    private static weak var attachedView: UIView?
    private static var impact: UIImpactFeedbackGenerator?
    private static var selection: UISelectionFeedbackGenerator?
    private static var notification: UINotificationFeedbackGenerator?

    /// Core of `play(_:)`, with the view and defaults injected so it can be tested.
    static func play(_ kind: HapticFeedback, in view: UIView, defaults: UserDefaults) {
        guard HapticFeedback.resolve(kind, isEnabled: HapticsPreference.isEnabled(in: defaults)) != nil else { return }
        attach(to: view)
        let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)

        switch kind {
        case .tap:
            impact?.impactOccurred(at: point)
        case .selection:
            selection?.selectionChanged(at: point)
        case .success:
            notification?.notificationOccurred(.success, at: point)
        case .error:
            notification?.notificationOccurred(.error, at: point)
        }
    }

    private static func attach(to view: UIView) {
        guard attachedView !== view || impact == nil else { return }
        for interaction in [impact as UIInteraction?, selection, notification].compactMap({ $0 }) {
            interaction.view?.removeInteraction(interaction)
        }
        impact = UIImpactFeedbackGenerator(style: .light, view: view)
        selection = UISelectionFeedbackGenerator(view: view)
        notification = UINotificationFeedbackGenerator(view: view)
        attachedView = view
    }

    private static var foregroundKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }
}
