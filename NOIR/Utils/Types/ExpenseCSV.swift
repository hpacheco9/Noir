//
//  ExpenseCSV.swift
//  NOIR
//

import Foundation

nonisolated enum ExpenseCSV {
    struct Headers: Sendable {
        var date: String
        var name: String
        var amount: String
        var currency: String
        var category: String
        var card: String
        var note: String

        var all: [String] { [date, name, amount, currency, category, card, note] }
    }

    struct Row: Sendable {
        var date: Date
        var name: String
        var amount: Double
        var category: String
        var card: String
        var note: String
    }

    // Excel reads UTF-8 without a BOM as the local code page and garbles accents.
    static let byteOrderMark = "\u{FEFF}"
    static let lineEnding = "\r\n"

    // A text cell starting with one of these is run as a formula by spreadsheets.
    private static let formulaTriggers: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]

    static func make(rows: [Row], headers: Headers, currencyCode: String, timeZone: TimeZone = .current) -> String {
        let dateStyle = dayStyle(timeZone)
        var lines = [headers.all.map(escape).joined(separator: ",")]
        for row in rows {
            let fields = [
                row.date.formatted(dateStyle),
                text(row.name),
                amountString(row.amount),
                currencyCode,
                text(row.category),
                text(row.card),
                text(row.note),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return byteOrderMark + lines.joined(separator: lineEnding) + lineEnding
    }

    static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        "NOIR Expenses \(date.formatted(dayStyle(timeZone))).csv"
    }

    // yyyy-MM-dd, always Gregorian and with "-", whatever the device calendar or locale.
    private static func dayStyle(_ timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
    }

    // Through the description, which is the shortest string that reads back as the same Double: 19.99 stays
    // 19.99 where `Decimal(19.99)` would carry binary noise. `Decimal` then writes it with "." and no grouping.
    static func amountString(_ amount: Double) -> String {
        guard amount.isFinite else { return "" }
        return (Decimal(string: amount.description) ?? Decimal(amount)).description
    }

    static func text(_ value: String) -> String {
        guard let first = value.unicodeScalars.first, formulaTriggers.contains(first) else { return value }
        return "'" + value
    }

    // Scalars, not Characters: "\r\n" is a single Character that equals neither "\r" nor "\n".
    static func escape(_ field: String) -> String {
        let needsQuotes = field.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" }
        guard needsQuotes else { return field }
        var escaped = String.UnicodeScalarView()
        for scalar in field.unicodeScalars {
            if scalar == "\"" { escaped.append("\"") }
            escaped.append(scalar)
        }
        return "\"" + String(escaped) + "\""
    }
}
