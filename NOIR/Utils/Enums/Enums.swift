//
//  Enums.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation

enum SpendingPeriod: CaseIterable, Identifiable {
    case day
    case week
    case month
    case allTime

    var id: Self { self }

    var title: String {
        switch self {
        case .day: String(localized: L10n.SpendingPeriod.today)
        case .week: String(localized: L10n.SpendingPeriod.week)
        case .month: String(localized: L10n.SpendingPeriod.month)
        case .allTime: String(localized: L10n.SpendingPeriod.allTime)
        }
    }
}
