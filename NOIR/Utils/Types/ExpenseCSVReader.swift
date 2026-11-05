//
//  ExpenseCSVReader.swift
//  NOIR
//

import Foundation

nonisolated enum ExpenseCSVReader {
    enum Field: CaseIterable, Sendable {
        case date, name, amount, category, card, note, currency, categoryID
    }

    enum ReadError: Error, Equatable {
        case unreadable
        case missingColumns
    }

    enum InvalidReason: Sendable, Equatable {
        case date, amount, columnCount
    }

    struct InvalidRow: Sendable, Equatable {
        let line: Int
        let reason: InvalidReason
    }

    struct Record: Sendable, Equatable {
        let line: Int
        let dateText: String
        let name: String
        let amount: Double
        let category: String
        let categoryID: String
        let card: String
        let note: String
    }

    struct Parsed: Sendable {
        let records: [Record]
        let invalid: [InvalidRow]
        let dateFormats: [ImportDateFormat]
        let currencyCodes: [String]
        let timeZone: TimeZone

        var isAmbiguous: Bool { dateFormats.count > 1 }
    }

    @concurrent
    static func read(contentsOf url: URL, currencyCode: String) async throws -> Parsed {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try parse(try Data(contentsOf: url), currencyCode: currencyCode)
    }

    static func parse(_ data: Data, currencyCode: String, timeZone: TimeZone = .current) throws -> Parsed {
        guard let text = decode(data) else { throw ReadError.unreadable }
        return try parse(text: text, currencyCode: currencyCode, timeZone: timeZone)
    }

    static func parse(text: String, currencyCode: String, timeZone: TimeZone = .current) throws -> Parsed {
        let text = text.hasPrefix("\u{FEFF}") ? String(text.unicodeScalars.dropFirst()) : text
        var lines = records(in: text, delimiter: delimiter(of: text))[...]
        guard let header = lines.popFirst() else { throw ReadError.unreadable }
        let columns = columns(in: header.fields)
        guard let dateIndex = columns[.date], let amountIndex = columns[.amount] else { throw ReadError.missingColumns }

        var amounts = AmountParser(appCurrency: currencyCode)
        var records: [Record] = []
        var invalid: [InvalidRow] = []
        var currencies: [String: Int] = [:]

        for line in lines {
            var fields = line.fields
            if fields.count < header.fields.count, dateIndex < fields.count, amountIndex < fields.count {
                fields += Array(repeating: "", count: header.fields.count - fields.count)
            } else if fields.count > header.fields.count, fields[header.fields.count...].allSatisfy({ cleaned($0).isEmpty }) {
                fields.removeLast(fields.count - header.fields.count)
            }
            guard fields.count == header.fields.count else {
                invalid.append(InvalidRow(line: line.number, reason: .columnCount))
                continue
            }
            func cell(_ field: Field) -> String {
                columns[field].map { cleaned(fields[$0]) } ?? ""
            }
            let currency = cell(.currency).uppercased()
            guard let amount = amounts.parse(fields[amountIndex], currency: currency) else {
                invalid.append(InvalidRow(line: line.number, reason: .amount))
                continue
            }
            if AmountParser.isCode(currency) { currencies[currency, default: 0] += 1 }
            records.append(Record(
                line: line.number,
                dateText: cleaned(fields[dateIndex]),
                name: cell(.name),
                amount: amount,
                category: cell(.category),
                categoryID: cell(.categoryID),
                card: cell(.card),
                note: cell(.note)
            ))
        }

        return Parsed(
            records: records,
            invalid: invalid,
            dateFormats: ImportDateFormat.candidates(for: records.map(\.dateText), timeZone: timeZone),
            currencyCodes: currencies.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key),
            timeZone: timeZone
        )
    }

    // MARK: Text

    static func decode(_ data: Data) -> String? {
        var text: String?
        if data.starts(with: [0xFF, 0xFE]) {
            text = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        } else if data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        } else {
            // Mostly valid UTF-8 with a stray bad byte stays UTF-8. If the bad bytes are about half of the non-ASCII
            // characters or more, it is Excel's Windows-1252 (a pair like "É–" even happens to be valid UTF-8).
            let utf8 = String(decoding: data, as: UTF8.self)
            let nonASCII = utf8.unicodeScalars.filter { $0.value > 127 }.count
            let bad = utf8.unicodeScalars.filter { $0 == "\u{FFFD}" }.count
            text = bad == 0 || bad * 2 < nonASCII
                ? utf8
                : String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1)
        }
        if text?.unicodeScalars.first == "\u{FEFF}" { text?.unicodeScalars.removeFirst() }
        return text
    }

    // A text cell the export protected from formulas ('=SUM(1)) is stored without the quote again.
    static func cleaned(_ cell: String) -> String {
        let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
        var scalars = Array(trimmed.unicodeScalars)
        if scalars.count > 1, scalars[0] == "'", ExpenseCSV.formulaTriggers.contains(scalars[1]) {
            scalars.removeFirst()
        }
        var result = String.UnicodeScalarView()
        result.append(contentsOf: scalars)
        return String(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Structure

    // The header line decides: the one of , ; and tab that occurs most outside quotes (comma on a tie).
    static func delimiter(of text: String) -> Unicode.Scalar {
        let candidates: [Unicode.Scalar] = [",", ";", "\t"]
        var counts: [Unicode.Scalar: Int] = [:]
        var inQuotes = false
        var sawContent = false
        for scalar in text.unicodeScalars {
            if scalar == "\"" {
                inQuotes.toggle()
                sawContent = true
            } else if scalar == "\n" || scalar == "\r" {
                if !inQuotes && sawContent { break }
            } else {
                sawContent = true
                if !inQuotes, candidates.contains(scalar) { counts[scalar, default: 0] += 1 }
            }
        }
        return candidates.max { counts[$0, default: 0] < counts[$1, default: 0] } ?? ","
    }

    // RFC 4180: quoted fields may hold the delimiter, CR, LF and doubled quotes. `number` is the 1-based line the
    // record starts on. Records with only empty fields are dropped.
    static func records(in text: String, delimiter: Unicode.Scalar) -> [(number: Int, fields: [String])] {
        let scalars = Array(text.unicodeScalars)
        var result: [(number: Int, fields: [String])] = []
        var fields: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var line = 1
        var recordLine = 1

        func endField() {
            fields.append(String(field))
            field = String.UnicodeScalarView()
        }
        func endRecord() {
            endField()
            if fields.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                result.append((recordLine, fields))
            }
            fields = []
            recordLine = line
        }

        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            let next = index + 1 < scalars.count ? scalars[index + 1] : nil
            if inQuotes {
                if scalar == "\"" {
                    if next == "\"" {
                        field.append(scalar)
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                    if scalar == "\n" || (scalar == "\r" && next != "\n") { line += 1 }
                }
            } else if scalar == "\"" && field.allSatisfy({ $0 == " " || $0 == "\t" }) {
                field = String.UnicodeScalarView()
                inQuotes = true
            } else if scalar == delimiter {
                endField()
            } else if scalar == "\r" || scalar == "\n" {
                if scalar == "\r" && next == "\n" { index += 1 }
                line += 1
                endRecord()
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if !field.isEmpty || !fields.isEmpty { endRecord() }
        return result
    }

    // MARK: Headers

    private static let headerNames: [Field: Set<String>] = [
        .date: names("export.header_date", "date"),
        .name: names("export.header_name", "name"),
        .amount: names("export.header_amount", "amount"),
        .category: names("export.header_category", "category"),
        .card: names("export.header_card", "card"),
        .note: names("export.header_note", "note"),
        .currency: names("export.header_currency", "currency"),
        .categoryID: Set([ExpenseCSV.categoryIDHeader, "category_id", "categoryid"].map(\.searchKey)),
    ]

    private static let synonyms: [Field: Set<String>] = [
        .date: ["transaction date", "booking date", "posted date"],
        .name: ["title", "description", "payee", "merchant"],
        .amount: ["value", "price"],
        .note: ["memo", "notes"],
    ]

    private static func names(_ key: String, _ english: String) -> Set<String> {
        Set((AllLanguages.strings(forKey: key) + [english]).map(\.searchKey))
    }

    // The names of every language first, then the synonyms for what is still missing. A column serves one field.
    static func columns(in header: [String]) -> [Field: Int] {
        let keys = header.map(\.searchKey)
        var columns: [Field: Int] = [:]
        var used = Set<Int>()
        for table in [headerNames, synonyms] {
            for field in Field.allCases where columns[field] == nil {
                guard let names = table[field],
                      let index = keys.indices.first(where: { !used.contains($0) && names.contains(keys[$0]) })
                else { continue }
                columns[field] = index
                used.insert(index)
            }
        }
        return columns
    }

    // "1234.5" with no more decimals than the currency has is a "." decimal, as NOIR's own export writes it.
    // Anything else follows the row's currency, else the app's, with the lenient reader: "1.234" in EUR is 1234.
    private struct AmountParser {
        let appCurrency: String
        private var strategies: [String: AmountInputParseStrategy] = [:]
        private var places: [String: Int] = [:]

        init(appCurrency: String) { self.appCurrency = appCurrency }

        mutating func parse(_ text: String, currency: String) -> Double? {
            let code = Self.isCode(currency) ? currency : appCurrency
            let digits = places[code] ?? ExpenseCSV.fractionDigits(for: code)
            places[code] = digits

            let value: Decimal
            if let plain = Self.plain(text, maxDecimals: digits) {
                value = plain
            } else {
                // A file is not typed on this device's keyboard, so only the currency's own separators are decimals.
                let locale = CurrencyPreference.locale(for: code)
                let strategy = strategies[code] ?? AmountInputFormatStyle(code: code, currencyLocale: locale, deviceLocale: locale).parseStrategy
                strategies[code] = strategy
                guard let parsed = try? strategy.parse(text) else { return nil }
                value = parsed
            }
            let amount = ExpenseForm(amount: ExpenseCSV.rounded(value.magnitude, fractionDigits: digits)).amountValue
            return Expense.isValidAmount(amount) ? amount : nil
        }

        static func isCode(_ text: String) -> Bool {
            text.count == 3 && text.allSatisfy { $0.isASCII && $0.isLetter }
        }

        private static func plain(_ text: String, maxDecimals: Int) -> Decimal? {
            var body = Substring(text.trimmingCharacters(in: .whitespaces))
            if body.hasPrefix("-") { body = body.dropFirst() }
            let parts = body.split(separator: ".", omittingEmptySubsequences: false)
            guard (1...2).contains(parts.count),
                  parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
                  parts.count == 1 || parts[1].count <= maxDecimals
            else { return nil }
            return Decimal(string: String(body), locale: Locale(identifier: "en_US_POSIX"))
        }
    }
}
