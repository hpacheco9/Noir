//
//  SpendingBucketsTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct SpendingBucketsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: Year

    /// Last second of 2026 and first instant of 2027: the window jumps to the next calendar year.
    @Test(arguments: [(2026, 12, 31, 23, 59, 59), (2027, 1, 1, 0, 0, 0)])
    func yearHasTwelveMonthBucketsForTheCurrentYear(now: (Int, Int, Int, Int, Int, Int)) throws {
        let now = date(now.0, now.1, now.2, now.3, now.4, now.5)
        let year = calendar.component(.year, from: now)
        let layout = try #require(SpendingBuckets.layout(for: .year, calendar: calendar, now: now))

        #expect(layout.window == DateInterval(start: date(year, 1, 1), end: date(year + 1, 1, 1)))
        #expect(layout.starts == (1...12).map { date(year, $0, 1) })
        #expect(layout.labels == calendar.shortMonthSymbols)

        #expect(layout.index(for: date(year, 1, 1)) == 0)
        #expect(layout.index(for: date(year, 2, 1).addingTimeInterval(-1)) == 0)
        #expect(layout.index(for: date(year, 2, 1)) == 1)
        #expect(layout.index(for: date(year + 1, 1, 1).addingTimeInterval(-1)) == 11)
        #expect(layout.index(for: date(year + 1, 1, 1)) == nil)
        #expect(layout.index(for: date(year, 1, 1).addingTimeInterval(-1)) == nil)
    }

    @Test func yearChartWindowMatchesItsDateInterval() {
        let now = date(2026, 10, 15, 12)
        #expect(SpendingPeriod.year.chartWindow(calendar: calendar, now: now)
                == SpendingPeriod.year.dateInterval(calendar: calendar, now: now))
    }

    // MARK: All time

    @Test func allTimeHasOneBucketPerYearFromTheEarliestExpense() throws {
        let now = date(2026, 10, 15, 12)
        let layout = try #require(
            SpendingBuckets.layout(for: .allTime, calendar: calendar, now: now, earliest: date(2023, 6, 10, 9))
        )

        #expect(layout.window == DateInterval(start: date(2023, 1, 1), end: date(2027, 1, 1)))
        #expect(layout.starts == [date(2023, 1, 1), date(2024, 1, 1), date(2025, 1, 1), date(2026, 1, 1)])
        #expect(layout.index(for: date(2023, 1, 1)) == 0)
        #expect(layout.index(for: date(2024, 1, 1).addingTimeInterval(-1)) == 0)
        #expect(layout.index(for: date(2025, 7, 1)) == 2)
        #expect(layout.index(for: date(2027, 1, 1).addingTimeInterval(-1)) == 3)
        // Positive controls: the window really is bounded on both sides.
        #expect(layout.index(for: date(2023, 1, 1).addingTimeInterval(-1)) == nil)
        #expect(layout.index(for: date(2027, 1, 1)) == nil)
    }

    /// Earliest in the current year, no expenses at all, or only future ones: just the current year.
    /// 1_767_225_600 = 2026-01-01 00:00 UTC, 1_861_920_000 = 2029-01-01 00:00 UTC.
    @Test(arguments: [Date(timeIntervalSince1970: 1_767_225_600), nil, Date(timeIntervalSince1970: 1_861_920_000)] as [Date?])
    func allTimeIsTheCurrentYearWithoutOlderExpenses(earliest: Date?) throws {
        let now = date(2026, 10, 15, 12)
        let layout = try #require(
            SpendingBuckets.layout(for: .allTime, calendar: calendar, now: now, earliest: earliest)
        )
        #expect(layout.window == DateInterval(start: date(2026, 1, 1), end: date(2027, 1, 1)))
        #expect(layout.starts == [date(2026, 1, 1)])
    }

    @Test func allTimeLabelsAreTheYears() throws {
        let layout = try #require(
            SpendingBuckets.layout(for: .allTime, calendar: calendar, now: date(2026, 10, 15, 12), earliest: date(2024, 3, 2))
        )
        #expect(layout.labels == ["2024", "2025", "2026"])
    }

    @Test func allTimeHasNoDateInterval() {
        #expect(SpendingPeriod.allTime.dateInterval(calendar: calendar, now: date(2026, 10, 15)) == nil)
    }
}
