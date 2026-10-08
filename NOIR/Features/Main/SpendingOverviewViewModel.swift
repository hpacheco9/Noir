//
//  SpendingOverviewViewModel.swift
//  NOIR
//
//  Created by Henrique Pacheco on 22/08/2026.
//

import Foundation

@Observable
@MainActor
final class SpendingOverviewViewModel {
    private(set) var dataPoints: [SpendingDataPoint] = []
    private(set) var totalSpent: Decimal = 0
    private(set) var isComputing = false

    private var computeTask: Task<Void, Never>?

    func update(expenses: [ExpenseDTO], period: SpendingPeriod) {
        computeTask?.cancel()
        isComputing = true

        computeTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.filterAndGroup(expenses, by: period)

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.dataPoints = result.points
                self.totalSpent = result.total
                self.isComputing = false
            }
        }
    }

    // MARK: - Pure, nonisolated computation — everything below runs off the main actor
    nonisolated private static func filterAndGroup(
        _ expenses: [ExpenseDTO],
        by period: SpendingPeriod
    ) -> (points: [SpendingDataPoint], total: Decimal) {
        let calendar = Calendar.current
        let now = Date()
        let scoped = expenses.filter { period.contains($0.date, calendar: calendar, now: now) }

        let points = group(scoped, by: period, calendar: calendar, now: now)
        let total = points.reduce(Decimal(0)) { $0 + $1.amount }
        return (points, total)
    }

    nonisolated private static func group(
        _ expenses: [ExpenseDTO],
        by period: SpendingPeriod,
        calendar: Calendar,
        now: Date
    ) -> [SpendingDataPoint] {
        switch period {
        case .day:
            return groupByHour(expenses, calendar: calendar, now: now)
        case .week:
            return groupByWeekday(expenses, calendar: calendar, now: now)
        case .month:
            return groupByMonthIntervals(expenses, calendar: calendar, now: now)
        case .allTime:
            return groupByMonth(expenses, calendar: calendar, now: now)
        }
    }

    // MARK: - Day: by hour (00:00 → 23:00)
    nonisolated private static func groupByHour(_ expenses: [ExpenseDTO], calendar: Calendar, now: Date) -> [SpendingDataPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"

        let startOfDay = calendar.startOfDay(for: now)
        let hours = (0..<24).compactMap { calendar.date(byAdding: .hour, value: $0, to: startOfDay) }

        let sums = Dictionary(grouping: expenses) { expense in
            calendar.dateComponents([.year, .month, .day, .hour], from: expense.date)
        }.mapValues { group in group.reduce(Decimal(0)) { $0 + Decimal($1.amount) } }

        return hours.compactMap { hour in
            let key = calendar.dateComponents([.year, .month, .day, .hour], from: hour)
            guard let amount = sums[key], amount > 0 else { return nil }
            return SpendingDataPoint(label: formatter.string(from: hour), date: hour, amount: amount)
        }
    }

    // MARK: - Week: current week, Sun → Sat

    nonisolated private static func groupByWeekday(_ expenses: [ExpenseDTO], calendar: Calendar, now: Date) -> [SpendingDataPoint] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }

        let sums = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
            .mapValues { group in group.reduce(Decimal(0)) { $0 + Decimal($1.amount) } }

        return days.map { day in
            SpendingDataPoint(
                label: abbreviatedWeekdayLabel(for: day, calendar: calendar),
                date: day,
                amount: sums[calendar.startOfDay(for: day)] ?? 0
            )
        }
    }

    nonisolated private static func abbreviatedWeekdayLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEE")

        let localizedLabel = formatter.string(from: date)
        let letters = String(localizedLabel.prefix(3))
        return letters.hasSuffix(".") ? letters : "\(letters)."
    }

    // MARK: - Month: 7-day intervals (1–7, 8–14, 15–21, 22–28, 29–end)

    nonisolated private static func groupByMonthIntervals(_ expenses: [ExpenseDTO], calendar: Calendar, now: Date) -> [SpendingDataPoint] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: now),
            let range = calendar.range(of: .day, in: .month, for: now)
        else { return [] }

        let daysInMonth = range.count

        var buckets: [(startDay: Int, endDay: Int)] = []
        var start = 1
        while start <= daysInMonth {
            let end = min(start + 6, daysInMonth)
            buckets.append((start, end))
            start = end + 1
        }

        let sums = Dictionary(grouping: expenses) { expense -> Int in
            calendar.component(.day, from: expense.date)
        }

        return buckets.map { bucket in
            let daysInBucket = (bucket.startDay...bucket.endDay)
            let total = daysInBucket.reduce(Decimal(0)) { partial, day in
                let dayExpenses = sums[day] ?? []
                return partial + dayExpenses.reduce(Decimal(0)) { $0 + Decimal($1.amount) }
            }
            let label = bucket.startDay == bucket.endDay
                ? "\(bucket.startDay)"
                : "\(bucket.startDay)-\(bucket.endDay)"
            let bucketDate = calendar.date(byAdding: .day, value: bucket.startDay - 1, to: monthInterval.start) ?? monthInterval.start
            return SpendingDataPoint(label: label, date: bucketDate, amount: total)
        }
    }

    // MARK: - All Time:
    nonisolated private static func groupByMonth(_ expenses: [ExpenseDTO], calendar: Calendar, now: Date) -> [SpendingDataPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        let months = (0..<6).compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }.reversed()

        let sums = Dictionary(grouping: expenses) { expense in
            calendar.dateComponents([.year, .month], from: expense.date)
        }.mapValues { group in group.reduce(Decimal(0)) { $0 + Decimal($1.amount) } }

        return months.map { month in
            let key = calendar.dateComponents([.year, .month], from: month)
            return SpendingDataPoint(label: formatter.string(from: month), date: month, amount: sums[key] ?? 0)
        }
    }
}
