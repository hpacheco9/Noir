//
//  DeviceCutout.swift
//  NOIR
//

import UIKit

enum DeviceCutout: Equatable {
    case dynamicIsland
    case notch
    case none

    nonisolated static func make(topInset: CGFloat, isPad: Bool) -> DeviceCutout {
        if isPad { return .none }
        if topInset > 51 { return .dynamicIsland }
        if topInset > 24 { return .notch }
        return .none
    }

    // In landscape the cutout moves to the sides, so the top inset is 0 there and the larger side inset stands in for it.
    static var current: DeviceCutout {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return .none }
        let insets = window.safeAreaInsets
        return make(
            topInset: max(insets.top, insets.left, insets.right),
            isPad: window.traitCollection.userInterfaceIdiom == .pad
        )
    }
}
