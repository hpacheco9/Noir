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

    private var component: Calendar.Component? {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .allTime: nil
        }
    }

    /// The half-open range `[start, end)` this period covers around `now`; `nil` for `.allTime` (unbounded).
    func dateInterval(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        guard let component else { return nil }
        return calendar.dateInterval(of: component, for: now)
    }

    /// The whole period right before `dateInterval` (yesterday, last week, last month, last year); `nil` for `.allTime`.
    /// Found from the instant just before the current period starts, so DST and year boundaries need no arithmetic.
    func previousInterval(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        guard let component, let current = calendar.dateInterval(of: component, for: now) else { return nil }
        return calendar.dateInterval(of: component, for: current.start.addingTimeInterval(-1))
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
