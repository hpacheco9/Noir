//
//  RecurrenceFrequencyTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct RecurrenceFrequencyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func occurrence(_ frequency: RecurrenceFrequency, _ n: Int, from anchor: Date) -> Date {
        frequency.occurrence(n, from: anchor, calendar: calendar)
    }

    private func first(_ frequency: RecurrenceFrequency, after date: Date, anchor: Date) -> Date {
        frequency.firstOccurrence(after: date, anchor: anchor, calendar: calendar)
    }

    // MARK: occurrence(n)

    @Test func occurrenceZeroIsTheAnchor() {
        for frequency in RecurrenceFrequency.allCases {
            #expect(occurrence(frequency, 0, from: day(2026, 3, 15)) == day(2026, 3, 15))
        }
    }

    @Test func weeklyAddsSevenDays() {
        let anchor = day(2026, 1, 5)
        #expect(occurrence(.weekly, 1, from: anchor) == day(2026, 1, 12))
        #expect(occurrence(.weekly, 5, from: anchor) == day(2026, 2, 9))
        #expect(occurrence(.weekly, 52, from: anchor) == day(2027, 1, 4))
    }

    @Test func monthlyOnThe31stClampsToTheLastDayOfEachMonth() {
        let anchor = day(2026, 1, 31)
        #expect(occurrence(.monthly, 1, from: anchor) == day(2026, 2, 28))
        #expect(occurrence(.monthly, 2, from: anchor) == day(2026, 3, 31))
        #expect(occurrence(.monthly, 3, from: anchor) == day(2026, 4, 30))
        #expect(occurrence(.monthly, 4, from: anchor) == day(2026, 5, 31))
        // A leap February keeps the 29th.
        #expect(occurrence(.monthly, 25, from: anchor) == day(2028, 2, 29))
    }

    @Test func yearlyOnFeb29IsFeb28InNonLeapYears() {
        let anchor = day(2024, 2, 29)
        #expect(occurrence(.yearly, 1, from: anchor) == day(2025, 2, 28))
        #expect(occurrence(.yearly, 2, from: anchor) == day(2026, 2, 28))
        #expect(occurrence(.yearly, 4, from: anchor) == day(2028, 2, 29))
    }

    // MARK: Counting from the anchor

    @Test func stepsFromTheAnchorDoNotDrift() {
        let anchor = day(2026, 1, 31)
        var dates: [Date] = []
        var current = anchor
        for _ in 0..<4 {
            current = first(.monthly, after: current, anchor: anchor)
            dates.append(current)
        }
        #expect(dates == [day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30), day(2026, 5, 31)])

        // What stepping from the previous date would do, which is what the anchor avoids.
        let drifted = occurrence(.monthly, 1, from: occurrence(.monthly, 1, from: anchor))
        #expect(drifted == day(2026, 3, 28))
        #expect(drifted != dates[1])
    }

    // MARK: firstOccurrence(after:)

    @Test func firstOccurrenceAfterABetweenDateIsTheNextOne() {
        let anchor = day(2026, 1, 5)
        #expect(first(.weekly, after: day(2026, 1, 8), anchor: anchor) == day(2026, 1, 12))
        #expect(first(.monthly, after: day(2026, 3, 20), anchor: anchor) == day(2026, 4, 5))
        #expect(first(.yearly, after: day(2028, 6, 1), anchor: anchor) == day(2029, 1, 5))
    }

    @Test func firstOccurrenceIsStrictlyAfter() {
        let anchor = day(2026, 1, 5)
        // On the anchor and on a later occurrence: the following one, never the same date.
        #expect(first(.weekly, after: anchor, anchor: anchor) == day(2026, 1, 12))
        #expect(first(.weekly, after: day(2026, 1, 19), anchor: anchor) == day(2026, 1, 26))
        #expect(first(.monthly, after: day(2026, 2, 5), anchor: anchor) == day(2026, 3, 5))
        // One second after an occurrence is already past it.
        let justAfter = day(2026, 2, 5).addingTimeInterval(1)
        #expect(first(.monthly, after: justAfter, anchor: anchor) == day(2026, 3, 5))
    }

    @Test func firstOccurrenceBeforeTheAnchorIsTheAnchor() {
        let anchor = day(2026, 6, 15)
        for frequency in RecurrenceFrequency.allCases {
            #expect(first(frequency, after: day(2026, 6, 14), anchor: anchor) == anchor)
        }
    }

    @Test func firstOccurrenceHandlesClampedMonthEnds() {
        let anchor = day(2026, 1, 31)
        #expect(first(.monthly, after: day(2026, 1, 31), anchor: anchor) == day(2026, 2, 28))
        #expect(first(.monthly, after: day(2026, 2, 27), anchor: anchor) == day(2026, 2, 28))
        #expect(first(.monthly, after: day(2026, 2, 28), anchor: anchor) == day(2026, 3, 31))
        #expect(first(.monthly, after: day(2026, 3, 31), anchor: anchor) == day(2026, 4, 30))
        let leap = day(2024, 2, 29)
        #expect(first(.yearly, after: day(2025, 2, 28), anchor: leap) == day(2026, 2, 28))
        #expect(first(.yearly, after: day(2027, 3, 1), anchor: leap) == day(2028, 2, 29))
    }

    @Test func firstOccurrenceMatchesALinearScanOnEveryDay() {
        let anchors = [day(2026, 1, 31), day(2024, 2, 29), day(2026, 1, 5), day(2025, 12, 31), day(2026, 3, 30)]
        for frequency in RecurrenceFrequency.allCases {
            for anchor in anchors {
                var date = day(2023, 12, 1)
                while date < day(2029, 3, 1) {
                    var n = 0
                    while occurrence(frequency, n, from: anchor) <= date { n += 1 }
                    let expected = occurrence(frequency, n, from: anchor)
                    let actual = first(frequency, after: date, anchor: anchor)
                    #expect(actual == expected, "\(frequency) from \(anchor) after \(date)")
                    // Step by a prime number of days so the dates land on every weekday and month position.
                    date = calendar.date(byAdding: .day, value: 11, to: date)!
                }
            }
        }
    }

    @Test func datesFarFromTheAnchorStillResolve() {
        let anchor = day(2026, 1, 5)
        // 5,218 weeks after the anchor is the first one past 2126-01-05.
        #expect(first(.weekly, after: day(2126, 1, 5), anchor: anchor) == day(2126, 1, 7))
        #expect(first(.monthly, after: day(2526, 1, 5), anchor: anchor) == day(2526, 2, 5))
        #expect(first(.yearly, after: day(2526, 1, 5), anchor: anchor) == day(2527, 1, 5))
    }
}
