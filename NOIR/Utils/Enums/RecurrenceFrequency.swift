//
//  RecurrenceFrequency.swift
//  NOIR
//

import Foundation

nonisolated enum RecurrenceFrequency: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    @MainActor var title: LocalizedStringResource {
        switch self {
        case .weekly: L10n.Recurring.weekly
        case .monthly: L10n.Recurring.monthly
        case .yearly: L10n.Recurring.yearly
        }
    }

    private var step: (component: Calendar.Component, value: Int) {
        switch self {
        case .weekly: (.day, 7)
        case .monthly: (.month, 1)
        case .yearly: (.year, 1)
        }
    }

    /// Occurrence `n` (0 is the anchor itself). Always counted from the anchor, never from the previous
    /// occurrence, so a monthly expense on the 31st goes 28th, 31st, 30th instead of drifting to the 28th.
    func occurrence(_ n: Int, from anchor: Date, calendar: Calendar = .current) -> Date {
        let (component, value) = step
        return calendar.date(byAdding: component, value: value * n, to: anchor) ?? .distantFuture
    }

    /// The first occurrence strictly after `date` (the anchor itself when it is already later).
    func firstOccurrence(after date: Date, anchor: Date, calendar: Calendar = .current) -> Date {
        let (component, value) = step
        // Whole units from the anchor to `date`: jump close to the answer, then walk the last steps.
        let elapsed = calendar.dateComponents([component], from: anchor, to: date).value(for: component) ?? 0
        var n = max(elapsed / value - 1, 0)
        while occurrence(n, from: anchor, calendar: calendar) <= date { n += 1 }
        return occurrence(n, from: anchor, calendar: calendar)
    }
}
