//
//  MonthTotalSnapshot.swift
//  NOIR
//

import Foundation

/// What the app publishes for the "Spent this month" widget, in the shared App Group defaults.
nonisolated struct MonthTotalSnapshot: Codable, Equatable, Sendable {
    static let appGroup = "group.henrique-dev.NOIR"
    static let storageKey = "widget.month_total.v2"

    var month: DateInterval
    var total: Decimal
    var currencyCode: String
    /// Running total at the end of each day of the month, for the line chart.
    var days: [Double] = []

    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults) -> MonthTotalSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(MonthTotalSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Outside the month it was published for, nothing was spent yet. Absolute instants, so a time-zone change
    /// on the device doesn't move the boundary.
    func total(asOf now: Date) -> Decimal {
        month.start <= now && now < month.end ? total : 0
    }

    static func cumulativeDays(_ rows: [(date: Date, amount: Double)], in month: DateInterval, calendar: Calendar) -> [Double] {
        let count = calendar.range(of: .day, in: .month, for: month.start)?.count ?? 0
        var daily = [Double](repeating: 0, count: count)
        for row in rows where month.start <= row.date && row.date < month.end {
            let index = calendar.component(.day, from: row.date) - 1
            if daily.indices.contains(index) { daily[index] += row.amount }
        }
        var running = 0.0
        return daily.map { running += $0; return running }
    }

    /// The days to draw at `now`: through today, or through a later day that already has spending.
    func visibleDays(asOf now: Date, calendar: Calendar) -> [Double] {
        guard month.start <= now && now < month.end else { return [] }
        let today = calendar.dateComponents([.day], from: month.start, to: now).day ?? 0
        let lastChange = days.indices.last { $0 == 0 ? days[0] > 0 : days[$0] > days[$0 - 1] } ?? 0
        return Array(days.prefix(max(today, lastChange) + 1))
    }
}
