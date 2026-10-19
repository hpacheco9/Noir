//
//  SpendingBuckets.swift
//  NOIR
//

import Foundation

/// How one period's expenses are split into chart buckets. This is the ONLY place that maps a date to a bucket,
/// used by the full recompute, by memo deltas and by memo edit/delete adjustments, so they cannot drift apart.
nonisolated struct BucketLayout: Sendable {
    let period: SpendingPeriod
    /// The range covered; dates outside it belong to no bucket.
    let window: DateInterval
    /// Ascending bucket start dates (one per bucket).
    let starts: [Date]
    /// Date and label of each chart point.
    let pointDates: [Date]
    let labels: [String]

    /// Bucket for `date`, or nil when it falls outside the window.
    func index(for date: Date) -> Int? {
        guard window.containsHalfOpen(date) else { return nil }
        var index = starts.count - 1
        while index >= 0 {
            if starts[index] <= date { return index }
            index -= 1
        }
        return nil
    }

    /// Chart points for per-bucket sums. Day drops empty hours; every other period keeps all buckets.
    func points(from sums: [Decimal]) -> [SpendingDataPoint] {
        guard sums.count == starts.count else { return [] }
        return sums.indices.compactMap { index in
            if period == .day, !(sums[index] > 0) { return nil }
            return SpendingDataPoint(label: labels[index], date: pointDates[index], amount: sums[index])
        }
    }
}

nonisolated enum SpendingBuckets {
    /// Layout for `period` around `now`. Same `now` => same layout, which is what lets a memo rebuild it from `computedAt`.
    static func layout(for period: SpendingPeriod, calendar: Calendar = .current, now: Date = .now) -> BucketLayout? {
        guard let window = period.chartWindow(calendar: calendar, now: now) else { return nil }

        switch period {
        case .day:
            // Step one hour at a time to the end of the day: 24 buckets normally, 23 or 25 on DST days.
            var hours: [Date] = []
            var hour = window.start
            while hour < window.end, hours.count < 26 {
                hours.append(hour)
                guard let next = calendar.date(byAdding: .hour, value: 1, to: hour), next > hour else { break }
                hour = next
            }
            // "HH:00", made unique when a DST fall-back repeats an hour (zero-width spaces: looks the same,
            // but Charts would otherwise stack both bars on one x value).
            var seen: [String: Int] = [:]
            let labels = hours.map { hour -> String in
                let base = hourFormatter.string(from: hour)
                let occurrence = seen[base, default: 0]
                seen[base] = occurrence + 1
                return base + String(repeating: "\u{200B}", count: occurrence)
            }
            return BucketLayout(period: period, window: window, starts: hours, pointDates: hours, labels: labels)

        case .week:
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: window.start) }
            return BucketLayout(
                period: period, window: window, starts: days, pointDates: days,
                labels: days.map(abbreviatedWeekdayLabel)
            )

        case .month:
            guard let range = calendar.range(of: .day, in: .month, for: now) else { return nil }
            let daysInMonth = range.count

            var buckets: [(startDay: Int, endDay: Int)] = []
            var start = 1
            while start <= daysInMonth {
                let end = min(start + 6, daysInMonth)
                buckets.append((start, end))
                start = end + 1
            }

            let starts = buckets.map {
                calendar.date(byAdding: .day, value: $0.startDay - 1, to: window.start) ?? window.start
            }
            let labels = buckets.map {
                $0.startDay == $0.endDay ? "\($0.startDay)" : "\($0.startDay)-\($0.endDay)"
            }
            return BucketLayout(period: period, window: window, starts: starts, pointDates: starts, labels: labels)

        case .allTime:
            let months = Array((0..<6).compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }.reversed())
            let intervals = months.compactMap { calendar.dateInterval(of: .month, for: $0) }
            guard intervals.count == months.count else { return nil }
            return BucketLayout(
                period: period, window: window, starts: intervals.map(\.start), pointDates: months,
                labels: months.map { monthFormatter.string(from: $0) }
            )
        }
    }

    /// Adds `entries` (any order) to per-bucket `sums`; entries outside the window are ignored.
    /// Returns how many were counted and their total.
    @discardableResult
    static func accumulate(_ entries: [SpendingEntry], into sums: inout [Decimal], layout: BucketLayout) -> (count: Int, sum: Decimal) {
        var count = 0
        var sum = Decimal(0)
        for entry in entries {
            if let index = layout.index(for: entry.date) {
                let amount = Decimal(entry.amount)
                sums[index] += amount
                sum += amount
                count += 1
            }
        }
        return (count, sum)
    }

    // Cached: creating a DateFormatter is expensive. DateFormatter is thread-safe.
    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static func abbreviatedWeekdayLabel(for date: Date) -> String {
        let localizedLabel = weekdayFormatter.string(from: date)
        let letters = String(localizedLabel.prefix(3))
        return letters.hasSuffix(".") ? letters : "\(letters)."
    }
}
