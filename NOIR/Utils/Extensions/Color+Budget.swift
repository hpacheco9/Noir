//
//  Color+Budget.swift
//  NOIR
//

import SwiftUI
import UIKit

// Text on the card stays above 4.5:1 in light and dark.
extension Color {
    static let overBudget = Color(light: 0xB3261E, dark: 0xFF8A80)

    private init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
