//
//  ImportDateFormat.swift
//  NOIR
//

import Foundation

nonisolated enum ImportDateFormat: CaseIterable, Sendable, Hashable {
    case yearMonthDay
    case dayMonthYear
    case monthDayYear
    case dayMonthYearDots
    case yearMonthDaySlashes
    case dayMonthYearDashes

    private var separator: Character {
        switch self {
        case .yearMonthDay, .dayMonthYearDashes: "-"
        case .dayMonthYear, .monthDayYear, .yearMonthDaySlashes: "/"
        case .dayMonthYearDots: "."
        }
    }

    // Positions of year, month and day in the text.
    private var order: (year: Int, month: Int, day: Int) {
        switch self {
        case .yearMonthDay, .yearMonthDaySlashes: (0, 1, 2)
        case .dayMonthYear, .dayMonthYearDots, .dayMonthYearDashes: (2, 1, 0)
        case .monthDayYear: (2, 0, 1)
        }
    }

    // Noon of the day in `timeZone`, so DST and small time zone changes can't move it to another day. A time after
    // the date ("2026-03-05 14:30", "2026-03-05T14:30:00Z") is accepted and ignored.
    func date(from text: String, timeZone: TimeZone = .current) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let end = trimmed.firstIndex { $0 == " " || $0 == "T" } ?? trimmed.endIndex
        let time = trimmed[end...].dropFirst().trimmingCharacters(in: .whitespaces)
        guard end == trimmed.endIndex || Self.looksLikeTime(time) else { return nil }

        let parts = trimmed[..<end].split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts[order.year].count == 4, parts[order.month].count <= 2, parts[order.day].count <= 2,
              let year = Int(parts[order.year]), let month = Int(parts[order.month]), let day = Int(parts[order.day])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return nil }
        let read = calendar.dateComponents([.year, .month, .day], from: date)
        return read.year == year && read.month == month && read.day == day ? date : nil
    }

    private static func looksLikeTime(_ text: String) -> Bool {
        let pieces = text.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count >= 2, (1...2).contains(pieces[0].count), pieces[0].allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        return pieces[1].prefix(2).count == 2 && pieces[1].prefix(2).allSatisfy { $0.isASCII && $0.isNumber }
    }

    // The formats that read the most dates (all of them when some read every row, so a junk row can't pick a format
    // for the rest). Day-first and month-first both stay only when some date reads differently in the two.
    static func candidates(for texts: [String], timeZone: TimeZone = .current) -> [ImportDateFormat] {
        let texts = texts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let counts = allCases.map { format in texts.filter { format.date(from: $0, timeZone: timeZone) != nil }.count }
        let best = counts.max() ?? 0
        let tied = zip(allCases, counts).filter { $0.1 == best }.map(\.0)
        let first = tied[0]
        let others = tied.dropFirst().filter { other in
            texts.contains { first.date(from: $0, timeZone: timeZone) != other.date(from: $0, timeZone: timeZone) }
        }
        return [first] + others
    }
}
