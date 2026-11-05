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
        var categoryID = ExpenseCSV.categoryIDHeader

        var all: [String] { [date, name, amount, currency, category, card, note, categoryID] }
    }

    struct Row: Sendable {
        var date: Date
        var name: String
        var amount: Double
        var category: String
        var card: String
        var note: String
        var categoryKey: String
    }

    static let categoryIDHeader = "Category ID"
    static let byteOrderMark = "\u{FEFF}"
    static let lineEnding = "\r\n"

    static let formulaTriggers: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]

    static func make(rows: [Row], headers: Headers, currencyCode: String, timeZone: TimeZone = .current) -> String {
        let dateStyle = dayStyle(timeZone)
        let fractionDigits = fractionDigits(for: currencyCode)
        var lines = [headers.all.map(escape).joined(separator: ",")]
        for row in rows {
            let fields = [
                row.date.formatted(dateStyle),
                text(row.name),
                amountString(row.amount, fractionDigits: fractionDigits),
                currencyCode,
                text(row.category),
                text(row.card),
                text(row.note),
                row.categoryKey,
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return byteOrderMark + lines.joined(separator: lineEnding) + lineEnding
    }

    static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        "NOIR Expenses \(date.formatted(dayStyle(timeZone))).csv"
    }

    private static func dayStyle(_ timeZone: TimeZone) -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
    }

    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = CurrencyPreference.locale(for: currencyCode)
        return formatter.maximumFractionDigits
    }

    static func roundedAmount(_ amount: Double, fractionDigits: Int) -> Decimal {
        var value = Decimal(string: amount.description) ?? 0
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, fractionDigits, .plain)
        return rounded
    }

    static func amountString(_ amount: Double, fractionDigits: Int) -> String {
        roundedAmount(amount, fractionDigits: fractionDigits).description
    }

    static func text(_ value: String) -> String {
        guard let first = value.unicodeScalars.first, formulaTriggers.contains(first) else { return value }
        return "'" + value
    }

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
