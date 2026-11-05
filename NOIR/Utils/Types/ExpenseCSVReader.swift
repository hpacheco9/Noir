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

    struct DatedRecord: Sendable, Equatable {
        let record: Record
        let date: Date
    }

    struct Parsed: Sendable {
        let records: [Record]
        let invalid: [InvalidRow]
        let dateFormats: [ImportDateFormat]
        let currencyCodes: [String]
        let timeZone: TimeZone

        var isAmbiguous: Bool { dateFormats.count > 1 }

        func dated(using format: ImportDateFormat) -> (rows: [DatedRecord], invalid: [InvalidRow]) {
            var rows: [DatedRecord] = []
            var invalid = self.invalid
            for record in records {
                if let date = format.date(from: record.dateText, timeZone: timeZone) {
                    rows.append(DatedRecord(record: record, date: date))
                } else {
                    invalid.append(InvalidRow(line: record.line, reason: .date))
                }
            }
            return (rows, invalid.sorted { $0.line < $1.line })
        }
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

        let amountStyle = CurrencyPreference.amountInputStyle(for: currencyCode).parseStrategy
        var records: [Record] = []
        var invalid: [InvalidRow] = []
        var currencies: [String: Int] = [:]

        for line in lines {
            let fields = line.fields
            guard fields.count == header.fields.count else {
                invalid.append(InvalidRow(line: line.number, reason: .columnCount))
                continue
            }
            func cell(_ field: Field) -> String {
                columns[field].map { cleaned(fields[$0]) } ?? ""
            }
            guard let value = try? amountStyle.parse(fields[amountIndex]),
                  case let amount = ExpenseForm(amount: value.magnitude).amountValue,
                  Expense.isValidAmount(amount)
            else {
                invalid.append(InvalidRow(line: line.number, reason: .amount))
                continue
            }
            let currency = cell(.currency).uppercased()
            if !currency.isEmpty { currencies[currency, default: 0] += 1 }
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
            // Excel's "CSV (comma delimited)" is Windows-1252, not UTF-8.
            text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252)
                ?? String(data: data, encoding: .isoLatin1)
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
            } else if scalar == "\"" && field.isEmpty {
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
}
