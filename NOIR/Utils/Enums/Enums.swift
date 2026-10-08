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

    func contains(_ date: Date, calendar: Calendar = .current, now: Date = .now) -> Bool {
        switch self {
        case .day:
            calendar.isDate(date, inSameDayAs: now)
        case .week:
            calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .allTime:
            true
        }
    }
}
