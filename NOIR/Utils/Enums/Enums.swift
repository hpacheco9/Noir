//
//  Enums.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation

nonisolated enum SpendingPeriod: CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case allTime

    var id: Self { self }

    @MainActor var title: String {
        switch self {
        case .day: String(localized: L10n.SpendingPeriod.today)
        case .week: String(localized: L10n.SpendingPeriod.week)
        case .month: String(localized: L10n.SpendingPeriod.month)
        case .allTime: String(localized: L10n.SpendingPeriod.allTime)
        }
    }

    /// Initial-style label for tight segmented controls ("D", "W", "M", "All"). Pair it with `title` as the
    /// accessibility label.
    @MainActor var shortTitle: String {
        switch self {
        case .day: String(localized: L10n.SpendingPeriod.shortDay)
        case .week: String(localized: L10n.SpendingPeriod.shortWeek)
        case .month: String(localized: L10n.SpendingPeriod.shortMonth)
        case .allTime: String(localized: L10n.SpendingPeriod.shortAllTime)
        }
    }

    /// The half-open range `[start, end)` this period covers around `now`; `nil` for `.allTime` (unbounded).
    func dateInterval(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        switch self {
        case .day: calendar.dateInterval(of: .day, for: now)
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: calendar.dateInterval(of: .month, for: now)
        case .allTime: nil
        }
    }

    /// The range the overview chart covers: the period interval, or for `.allTime` the last six calendar months
    /// (this month and the five before it).
    func chartWindow(calendar: Calendar = .current, now: Date = .now) -> DateInterval? {
        if let interval = dateInterval(calendar: calendar, now: now) { return interval }
        guard
            let oldest = calendar.date(byAdding: .month, value: -5, to: now),
            let first = calendar.dateInterval(of: .month, for: oldest),
            let current = calendar.dateInterval(of: .month, for: now)
        else { return nil }
        return DateInterval(start: first.start, end: current.end)
    }
}

extension DateInterval {
    /// `start <= date < end`. (`DateInterval.contains` also accepts `end`, which belongs to the next period.)
    nonisolated func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
