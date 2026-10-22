//
//  SpendingPeriod.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation

nonisolated enum SpendingPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year
    case allTime

    var id: Self { self }

    @MainActor var title: String {
        switch self {
        case .day: String(localized: L10n.SpendingPeriod.today)
        case .week: String(localized: L10n.SpendingPeriod.week)
        case .month: String(localized: L10n.SpendingPeriod.month)
        case .year: String(localized: L10n.SpendingPeriod.year)
        case .allTime: String(localized: L10n.SpendingPeriod.allTime)
        }
    }

    /// The half-open range `[start, end)` this period covers around `now`; `nil` for `.allTime` (unbounded).
    func dateInterval(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        switch self {
        case .day: calendar.dateInterval(of: .day, for: now)
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: calendar.dateInterval(of: .month, for: now)
        case .year: calendar.dateInterval(of: .year, for: now)
        case .allTime: nil
        }
    }

    /// The range the overview chart covers: the period interval, or for `.allTime` the calendar years from the one
    /// holding `earliest` through the one holding `latest` (the oldest and newest expense dates; `nil` when there is
    /// none), always including the current year.
    func chartWindow(calendar: Calendar = .current, now: Date = .now, earliest: Date? = nil, latest: Date? = nil) -> DateInterval? {
        if let interval = dateInterval(calendar: calendar, now: now) { return interval }
        guard
            let first = calendar.dateInterval(of: .year, for: min(earliest ?? now, now)),
            let last = calendar.dateInterval(of: .year, for: max(latest ?? now, now))
        else { return nil }
        return DateInterval(start: first.start, end: last.end)
    }
}
