//
//  AssetName.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import Foundation

nonisolated enum AssetName {
    enum System {
        static let add = "plus"
        static let checkmark = "checkmark"
        static let categories = "tag.fill"
        static let close = "xmark"
        static let currency = "dollarsign.circle.fill"
        static let dashboard = "chart.pie"
        static let delete = "trash"
        static let disclosure = "chevron.right"
        static let filter = "line.3.horizontal.decrease"
        static let haptics = "iphone.radiowaves.left.and.right"
        static let home = "text.rectangle.page"
        static let legal = "doc.text.fill"
        static let privacy = "hand.raised.fill"
        static let reset = "arrow.counterclockwise"
        static let review = "star.bubble"
        static let rest = "ellipsis.circle"
        static let search = "magnifyingglass"
        static let shortcuts = "command"
        static let transactions = "creditcard.fill"
        static let warning = "exclamationmark.triangle"
    }

    enum ExpenseCategory {
        static let food = "fork.knife"
        static let transport = "car.fill"
        static let home = "house.fill"
        static let leisure = "ticket.fill"
        static let health = "cross.case.fill"
        static let shopping = "cart.fill"
        static let other = "square.grid.2x2.fill"
    }

    /// Symbols a custom category can use (all verified in SF Symbols for iOS 26). Starts with the built-in icons.
    enum CategorySymbols {
        static let all: [String] = [
            ExpenseCategory.food, ExpenseCategory.transport, ExpenseCategory.home, ExpenseCategory.leisure,
            ExpenseCategory.health, ExpenseCategory.shopping, ExpenseCategory.other,
            "tshirt.fill", "bag.fill", "gift.fill", "cup.and.saucer.fill", "pawprint.fill", "airplane",
            "bus.fill", "fuelpump.fill", "gamecontroller.fill", "book.fill", "graduationcap.fill",
            "dumbbell.fill", "heart.fill", "wrench.and.screwdriver.fill", "bolt.fill", "phone.fill",
            "creditcard.fill", "music.note", "film.fill", "leaf.fill", "star.fill", "briefcase.fill",
            "banknote.fill"
        ]
    }
}
