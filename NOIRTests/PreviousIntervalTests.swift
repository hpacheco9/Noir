//
//  PreviousIntervalTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct PreviousIntervalTests {
    private static let comparablePeriods: [SpendingPeriod] = [.day, .week, .month, .year]

    private func calendar(_ identifier: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: Plain calendar

    @Test func eachPeriodIsTheWholeOneBefore() throws {
        let calendar = calendar()
        let now = date(calendar, 2026, 10, 15, 12)    // a Thursday

        let day = try #require(SpendingPeriod.day.previousInterval(calendar: calendar, now: now))
        #expect(day == DateInterval(start: date(calendar, 2026, 10, 14), end: date(calendar, 2026, 10, 15)))

        let week = try #require(SpendingPeriod.week.previousInterval(calendar: calendar, now: now))
        #expect(week == DateInterval(start: date(calendar, 2026, 10, 5), end: date(calendar, 2026, 10, 12)))

        let month = try #require(SpendingPeriod.month.previousInterval(calendar: calendar, now: now))
        #expect(month == DateInterval(start: date(calendar, 2026, 9, 1), end: date(calendar, 2026, 10, 1)))

        let year = try #require(SpendingPeriod.year.previousInterval(calendar: calendar, now: now))
        #expect(year == DateInterval(start: date(calendar, 2025, 1, 1), end: date(calendar, 2026, 1, 1)))
    }

    @Test func allTimeHasNoPreviousPeriod() {
        #expect(SpendingPeriod.allTime.previousInterval(calendar: calendar(), now: .now) == nil)
    }

    @Test func weekFollowsTheCalendarsFirstWeekday() throws {
        var sundayStart = calendar()
        sundayStart.firstWeekday = 1
        let now = date(sundayStart, 2026, 10, 15, 12)
        let week = try #require(SpendingPeriod.week.previousInterval(calendar: sundayStart, now: now))
        #expect(week == DateInterval(start: date(sundayStart, 2026, 10, 4), end: date(sundayStart, 2026, 10, 11)))
    }

    // MARK: Boundaries

    @Test func newYearsDayLooksBackAtTheYearBefore() throws {
        let calendar = calendar()
        let now = date(calendar, 2026, 1, 1)    // a Thursday, first instant of the year

        let day = try #require(SpendingPeriod.day.previousInterval(calendar: calendar, now: now))
        #expect(day == DateInterval(start: date(calendar, 2025, 12, 31), end: date(calendar, 2026, 1, 1)))

        let week = try #require(SpendingPeriod.week.previousInterval(calendar: calendar, now: now))
        #expect(week == DateInterval(start: date(calendar, 2025, 12, 22), end: date(calendar, 2025, 12, 29)))

        let month = try #require(SpendingPeriod.month.previousInterval(calendar: calendar, now: now))
        #expect(month == DateInterval(start: date(calendar, 2025, 12, 1), end: date(calendar, 2026, 1, 1)))

        let year = try #require(SpendingPeriod.year.previousInterval(calendar: calendar, now: now))
        #expect(year == DateInterval(start: date(calendar, 2025, 1, 1), end: date(calendar, 2026, 1, 1)))
    }

    @Test func lastSecondOfTheYearStillLooksBack() throws {
        let calendar = calendar()
        let now = date(calendar, 2026, 12, 31, 23, 59, 59)
        let year = try #require(SpendingPeriod.year.previousInterval(calendar: calendar, now: now))
        #expect(year == DateInterval(start: date(calendar, 2025, 1, 1), end: date(calendar, 2026, 1, 1)))
        let month = try #require(SpendingPeriod.month.previousInterval(calendar: calendar, now: now))
        #expect(month == DateInterval(start: date(calendar, 2026, 11, 1), end: date(calendar, 2026, 12, 1)))
    }

    @Test func previousMonthHasItsOwnLength() throws {
        let calendar = calendar()
        let february = try #require(SpendingPeriod.month.previousInterval(calendar: calendar, now: date(calendar, 2026, 3, 31)))
        #expect(february.duration == 28 * 86_400)
        let leapFebruary = try #require(SpendingPeriod.month.previousInterval(calendar: calendar, now: date(calendar, 2028, 3, 1)))
        #expect(leapFebruary.duration == 29 * 86_400)
    }

    /// The previous period must end exactly where the current one starts: nothing in between, nothing counted twice.
    @Test(arguments: comparablePeriods, [
        (2026, 1, 1, 0, 0, 0), (2026, 12, 31, 23, 59, 59), (2026, 3, 8, 12, 0, 0), (2026, 11, 1, 1, 30, 0),
        (2026, 10, 12, 0, 0, 0), (2028, 2, 29, 12, 0, 0),
    ])
    func previousEndsWhereTheCurrentStarts(period: SpendingPeriod, parts: (Int, Int, Int, Int, Int, Int)) throws {
        let calendar = calendar("America/New_York")
        let now = date(calendar, parts.0, parts.1, parts.2, parts.3, parts.4, parts.5)
        let current = try #require(period.dateInterval(calendar: calendar, now: now))
        let previous = try #require(period.previousInterval(calendar: calendar, now: now))
        #expect(previous.end == current.start)
        #expect(previous.start < previous.end)
    }

    // MARK: Daylight saving

    @Test func theWeekAcrossSpringForwardIsOneHourShort() throws {
        let calendar = calendar("America/New_York")    // clocks skip an hour on Sunday 8 March 2026
        let now = date(calendar, 2026, 3, 11, 12)
        let week = try #require(SpendingPeriod.week.previousInterval(calendar: calendar, now: now))
        #expect(week.start == date(calendar, 2026, 3, 2))
        #expect(week.end == date(calendar, 2026, 3, 9))
        #expect(week.duration == 167 * 3600)
    }

    @Test func theWeekAcrossFallBackIsOneHourLong() throws {
        let calendar = calendar("America/New_York")    // clocks repeat an hour on Sunday 1 November 2026
        let now = date(calendar, 2026, 11, 4, 12)
        let week = try #require(SpendingPeriod.week.previousInterval(calendar: calendar, now: now))
        #expect(week.start == date(calendar, 2026, 10, 26))
        #expect(week.end == date(calendar, 2026, 11, 2))
        #expect(week.duration == 169 * 3600)
    }

    @Test func yesterdayCanBeA23HourDay() throws {
        let calendar = calendar("America/New_York")
        let day = try #require(SpendingPeriod.day.previousInterval(calendar: calendar, now: date(calendar, 2026, 3, 9, 8)))
        #expect(day == DateInterval(start: date(calendar, 2026, 3, 8), end: date(calendar, 2026, 3, 9)))
        #expect(day.duration == 23 * 3600)
    }

    @Test func yesterdayCanBeA25HourDay() throws {
        let calendar = calendar("America/New_York")
        let day = try #require(SpendingPeriod.day.previousInterval(calendar: calendar, now: date(calendar, 2026, 11, 2, 8)))
        #expect(day == DateInterval(start: date(calendar, 2026, 11, 1), end: date(calendar, 2026, 11, 2)))
        #expect(day.duration == 25 * 3600)
    }

    /// Sao Paulo skipped midnight when summer time began (4 November 2018): yesterday starts at 01:00.
    @Test func yesterdayStartsLateWhenMidnightDoesNotExist() throws {
        let calendar = calendar("America/Sao_Paulo")
        let now = date(calendar, 2018, 11, 5, 9)
        let day = try #require(SpendingPeriod.day.previousInterval(calendar: calendar, now: now))
        #expect(day.start == date(calendar, 2018, 11, 4, 1))
        #expect(day.end == date(calendar, 2018, 11, 5))
        #expect(day.duration == 23 * 3600)
    }

    @Test func previousYearAcrossDaylightSavingKeepsLocalMidnights() throws {
        let calendar = calendar("Europe/Lisbon")
        let year = try #require(SpendingPeriod.year.previousInterval(calendar: calendar, now: date(calendar, 2026, 6, 1)))
        #expect(year == DateInterval(start: date(calendar, 2025, 1, 1), end: date(calendar, 2026, 1, 1)))
        #expect(year.duration == 365 * 86_400)
    }
}
