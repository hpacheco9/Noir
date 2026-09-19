//
//  AssetName.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import Foundation

enum AssetName {
    enum System {
        static let add = "plus"
        static let checkmark = "checkmark"
        static let close = "xmark"
        static let currency = "dollarsign.circle.fill"
        static let delete = "trash"
        static let disclosure = "chevron.right"
        static let filter = "line.3.horizontal.decrease"
        static let legal = "doc.text.fill"
        static let privacy = "hand.raised.fill"
        static let pro = "sparkles"
        static let search = "magnifyingglass"
        static let shortcuts = "command"
        static let transactions = "creditcard.fill"
    }

    enum ExpenseCategory {
        static let food = "fork.knife"
        static let transport = "car.fill"
        static let home = "house.fill"
        static let leisure = "ticket.fill"
        static let health = "cross.case.fill"
        static let clothing = "tshirt.fill"
        static let other = "square.grid.2x2.fill"
    }
}
