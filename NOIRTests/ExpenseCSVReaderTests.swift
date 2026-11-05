//
//  ExpenseCSVReaderTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct ExpenseCSVReaderTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    private func parse(_ text: String, currency: String = "EUR") throws -> ExpenseCSVReader.Parsed {
        try ExpenseCSVReader.parse(text: text, currencyCode: currency, timeZone: utc)
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func amounts(_ parsed: ExpenseCSVReader.Parsed) -> [Double] { parsed.records.map(\.amount) }

    // MARK: Text

    @Test func utf8BOMIsStripped() throws {
        let body = "Date,Amount\n2026-03-05,3.5\n"
        let withBOM = Data([0xEF, 0xBB, 0xBF]) + Data(body.utf8)
        #expect(ExpenseCSVReader.decode(withBOM) == body)
        #expect(ExpenseCSVReader.decode(Data(body.utf8)) == body)
        // Without the strip the BOM would stick to the first header and Date would not be found.
        #expect(try ExpenseCSVReader.parse(withBOM, currencyCode: "EUR", timeZone: utc).records.count == 1)
    }

    @Test func aBOMOnTextIsStrippedToo() throws {
        let parsed = try parse("\u{FEFF}Date,Amount\n2026-03-05,3.5\n")
        #expect(parsed.records.count == 1)
    }

    @Test func utf16WithABOMIsDecoded() throws {
        let body = "Date,Name,Amount\n2026-03-05,Café,3.5\n"
        let littleEndian = Data([0xFF, 0xFE]) + body.data(using: .utf16LittleEndian)!
        let bigEndian = Data([0xFE, 0xFF]) + body.data(using: .utf16BigEndian)!
        #expect(ExpenseCSVReader.decode(littleEndian) == body)
        #expect(ExpenseCSVReader.decode(bigEndian) == body)
        #expect(try ExpenseCSVReader.parse(littleEndian, currencyCode: "EUR", timeZone: utc).records.first?.name == "Café")
    }

    @Test func windows1252IsTheFallbackWhenItIsNotUTF8() {
        let ansi = "Date,Name,Amount\n2026-03-05,Café,3.5\n".data(using: .windowsCP1252)!
        #expect(String(data: ansi, encoding: .utf8) == nil)
        #expect(ExpenseCSVReader.decode(ansi)?.contains("Café") == true)
    }

    @Test func emptyAndHeaderlessInputIsUnreadable() {
        #expect(throws: ExpenseCSVReader.ReadError.unreadable) { try parse("") }
        #expect(throws: ExpenseCSVReader.ReadError.unreadable) { try parse("\n\n  \n") }
        #expect(throws: ExpenseCSVReader.ReadError.unreadable) { try ExpenseCSVReader.parse(Data(), currencyCode: "EUR") }
    }

    // MARK: Structure

    @Test func crlfAndLfGiveTheSameRecords() throws {
        let lf = "Date,Name,Amount\n2026-03-05,Coffee,3.5\n2026-03-06,Tea,2\n"
        let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")
        let cr = lf.replacingOccurrences(of: "\n", with: "\r")
        let reference = try parse(lf).records
        #expect(reference.map(\.name) == ["Coffee", "Tea"])
        #expect(try parse(crlf).records == reference)
        #expect(try parse(cr).records == reference)
    }

    @Test func missingFinalNewlineAndBlankLinesAreFine() throws {
        let parsed = try parse("\nDate,Name,Amount\n\n2026-03-05,Coffee,3.5\n,,\n2026-03-06,Tea,2")
        #expect(parsed.records.map(\.name) == ["Coffee", "Tea"])
        #expect(parsed.invalid.isEmpty)
        // Control: the blank and the all-empty lines did not hide a real record.
        #expect(parsed.records.map(\.line) == [4, 6])
    }

    @Test func quotedFieldsHoldDelimitersNewlinesAndQuotes() throws {
        let text = "Date,Name,Amount,Note\r\n"
            + "2026-03-05,\"Dinner, \"\"Chez Paul\"\"\",19.99,\"Line one\r\nLine two\"\r\n"
            + "2026-03-06,Tea,2,\"a\nb\"\r\n"
        let records = try parse(text).records
        #expect(records.count == 2)
        #expect(records[0].name == "Dinner, \"Chez Paul\"")
        #expect(records[0].note == "Line one\r\nLine two")
        #expect(records[1].note == "a\nb")
        // Control: without the quotes the same text splits the name apart.
        let unquoted = try parse("Date,Name,Amount\n2026-03-05,Dinner, Chez Paul,19.99\n")
        #expect(unquoted.records.isEmpty)
        #expect(unquoted.invalid.map(\.reason) == [.columnCount])
    }

    @Test func lineNumbersCountQuotedNewlines() throws {
        let text = "Date,Name,Amount\n"          // 1
            + "2026-03-05,\"two\nlines\",3\n"   // 2-3
            + "2026-03-06,Tea,oops\n"           // 4
            + "2026-03-07,Short\n"              // 5
        let parsed = try parse(text)
        #expect(parsed.records.map(\.line) == [2])
        #expect(parsed.invalid == [
            .init(line: 4, reason: .amount),
            .init(line: 5, reason: .columnCount),
        ])
    }

    @Test(arguments: [(",", "Date,Name,Amount\n2026-03-05,Coffee,3.5\n"),
                      (";", "Date;Name;Amount\n2026-03-05;Coffee;3,5\n"),
                      ("\t", "Date\tName\tAmount\n2026-03-05\tCoffee\t3.5\n")])
    func theDelimiterComesFromTheHeader(delimiter: String, text: String) throws {
        #expect(String(Character(ExpenseCSVReader.delimiter(of: text))) == delimiter)
        let records = try parse(text).records
        #expect(records.map(\.name) == ["Coffee"])
        #expect(records.map(\.amount) == [3.5])
    }

    @Test func delimiterDetectionReadsTheHeaderOnlyAndIgnoresQuotedMarks() {
        #expect(ExpenseCSVReader.delimiter(of: "Date;Name;Amount\n1,2,3,4,5,6\n") == ";")
        #expect(ExpenseCSVReader.delimiter(of: "Date\tName\tAmount\n1,2,3,4,5,6\n") == "\t")
        #expect(ExpenseCSVReader.delimiter(of: "Date,Name,Amount\n1;2;3;4;5;6\n") == ",")
        #expect(ExpenseCSVReader.delimiter(of: "Date;\"Name, full\";Amount\n") == ";")
        #expect(ExpenseCSVReader.delimiter(of: "Date\n") == ",")
    }

    // MARK: Headers

    @Test func headersMatchInGerman() throws {
        let parsed = try parse("Datum;Name;Betrag;Währung;Kategorie;Karte;Notiz\n05.03.2026;Kaffee;3,50;EUR;Essen;Visa;lecker\n")
        let record = try #require(parsed.records.first)
        #expect(record.name == "Kaffee")
        #expect(record.amount == 3.5)
        #expect(record.category == "Essen")
        #expect(record.card == "Visa")
        #expect(record.note == "lecker")
        #expect(parsed.currencyCodes == ["EUR"])
    }

    @Test func headersMatchInPortugueseAndFinnish() throws {
        let pt = try parse("Data,Nome,Valor,Moeda,Categoria,Cartão,Nota\n2026-03-05,Café,3.5,EUR,Comida,Visa,x\n")
        #expect(pt.records.first?.name == "Café")
        #expect(pt.records.first?.category == "Comida")
        #expect(pt.records.first?.card == "Visa")
        let fi = try parse("Päivämäärä,Nimi,Summa,Valuutta,Kategoria,Kortti,Muistiinpano\n2026-03-05,Kahvi,3.5,EUR,Ruoka,Visa,x\n")
        #expect(fi.records.first?.name == "Kahvi")
        #expect(fi.records.first?.note == "x")
        #expect(fi.currencyCodes == ["EUR"])
    }

    @Test func headersIgnoreCaseAccentsAndPadding() throws {
        let parsed = try parse("  DATE ,NÀME,amount ,CÁTEGORY\n2026-03-05,Coffee,3.5,Food\n")
        #expect(parsed.records.first?.name == "Coffee")
        #expect(parsed.records.first?.category == "Food")
        // Control: a header that is none of the names does not match.
        #expect(throws: ExpenseCSVReader.ReadError.missingColumns) { try parse("Dates,Name,Amounts\n") }
    }

    @Test func englishSynonymsAreAccepted() throws {
        let title = try parse("Date,Title,Price,Memo\n2026-03-05,Coffee,3.5,note\n").records.first
        #expect(title?.name == "Coffee")
        #expect(title?.amount == 3.5)
        #expect(title?.note == "note")
        #expect(try parse("Date,Payee,Value,Notes\n2026-03-05,Cafe,3.5,n\n").records.first?.name == "Cafe")
        #expect(try parse("Date,Merchant,Amount\n2026-03-05,Cafe,3.5\n").records.first?.name == "Cafe")
        #expect(try parse("Date,Description,Amount\n2026-03-05,Cafe,3.5\n").records.first?.name == "Cafe")
    }

    @Test func aRealNameColumnBeatsASynonymAndEachColumnServesOneField() throws {
        let record = try #require(try parse("Date,Description,Name,Amount\n2026-03-05,From description,From name,3.5\n").records.first)
        #expect(record.name == "From name")
    }

    @Test func categoryIDIsMatchedOnItsOwn() throws {
        let record = try #require(try parse("Date,Category,Amount,Category ID\n2026-03-05,Shopping,3.5,clothing\n").records.first)
        #expect(record.category == "Shopping")
        #expect(record.categoryID == "clothing")
    }

    @Test func dateAndAmountAreRequiredNameIsNot() throws {
        #expect(throws: ExpenseCSVReader.ReadError.missingColumns) { try parse("Name,Amount\nCoffee,3.5\n") }
        #expect(throws: ExpenseCSVReader.ReadError.missingColumns) { try parse("Date,Name\n2026-03-05,Coffee\n") }
        let noName = try parse("Date,Amount\n2026-03-05,3.5\n")
        #expect(noName.records.count == 1)
        #expect(noName.records.first?.name == "")
    }

    @Test func headerOnlyFileHasNoRecords() throws {
        let parsed = try parse("Date,Name,Amount\n")
        #expect(parsed.records.isEmpty)
        #expect(parsed.invalid.isEmpty)
    }

    // MARK: Amounts

    @Test func amountsParseWithEitherSeparatorStyle() throws {
        let text = "Date,Amount\n" + [
            "12.50", "12,50", "1.234,56", "1,234.56", "1234.5", "€ 7,25", "$19.99", "5",
        ].map { "2026-03-05,\"\($0)\"\n" }.joined()
        #expect(amounts(try parse(text)) == [12.5, 12.5, 1234.56, 1234.56, 1234.5, 7.25, 19.99, 5])
    }

    @Test func negativeAmountsBecomePositive() throws {
        #expect(amounts(try parse("Date,Amount\n2026-03-05,-4.50\n2026-03-06,\"-4,50 €\"\n2026-03-07,4.50\n")) == [4.5, 4.5, 4.5])
    }

    @Test func badAmountsMakeTheRowInvalidWithItsLine() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,abc\n2026-03-06,0\n2026-03-07,\n2026-03-08,2.5\n")
        #expect(parsed.invalid == [.init(line: 2, reason: .amount), .init(line: 3, reason: .amount), .init(line: 4, reason: .amount)])
        #expect(amounts(parsed) == [2.5])
    }

    @Test func tooLargeAmountsAreInvalid() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,1000000000001\n2026-03-06,1000000000000\n")
        #expect(parsed.invalid.map(\.line) == [2])
        #expect(amounts(parsed) == [1_000_000_000_000])
    }

    // MARK: Text cells

    @Test(arguments: ["=SUM(1)", "+1", "-1", "@cmd"])
    func theExportsFormulaGuardIsUndone(value: String) {
        #expect(ExpenseCSVReader.cleaned("'" + value) == value)
    }

    @Test(arguments: ["'Coffee", "'", "''=x", "O'Brien", "Coffee"])
    func otherTextIsKept(value: String) {
        #expect(ExpenseCSVReader.cleaned(value) == value)
    }

    @Test func cellsAreTrimmed() {
        #expect(ExpenseCSVReader.cleaned("  Coffee \n") == "Coffee")
        #expect(ExpenseCSVReader.cleaned(" '=SUM(1) ") == "=SUM(1)")
    }

    @Test func guardedCellsAreUnguardedInRecords() throws {
        let record = try #require(try parse("Date,Name,Amount,Card,Note\n2026-03-05,'=1+1,3,'-x,'@y\n").records.first)
        #expect(record.name == "=1+1")
        #expect(record.card == "-x")
        #expect(record.note == "@y")
    }

    // MARK: Currency

    @Test func currencyCodesAreUppercasedAndOrderedByFrequency() throws {
        let parsed = try parse("Date,Amount,Currency\n2026-03-05,1,dkk\n2026-03-06,1,EUR\n2026-03-07,1,DKK\n2026-03-08,1,\n")
        #expect(parsed.currencyCodes == ["DKK", "EUR"])
        #expect(try parse("Date,Amount\n2026-03-05,1\n").currencyCodes.isEmpty)
    }

    // MARK: Dates

    @Test func datesAreNoonOfTheDayInTheGivenTimeZone() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,1\n")
        #expect(parsed.dated(using: parsed.dateFormats[0]).rows.first?.date == noon(2026, 3, 5))

        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        let local = try ExpenseCSVReader.parse(text: "Date,Amount\n2026-03-05,1\n", currencyCode: "EUR", timeZone: auckland)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = auckland
        let date = try #require(local.dated(using: local.dateFormats[0]).rows.first?.date)
        let read = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect([read.year, read.month, read.day, read.hour] == [2026, 3, 5, 12])
        #expect(date != noon(2026, 3, 5))
    }

    @Test func aDayAfterTwelveSettlesTheFormat() throws {
        let dayFirst = try parse("Date,Amount\n13/03/2026,1\n05/03/2026,1\n")
        #expect(dayFirst.dateFormats == [.dayMonthYear])
        #expect(!dayFirst.isAmbiguous)
        #expect(dayFirst.dated(using: .dayMonthYear).rows.map(\.date) == [noon(2026, 3, 13), noon(2026, 3, 5)])

        let monthFirst = try parse("Date,Amount\n03/13/2026,1\n03/05/2026,1\n")
        #expect(monthFirst.dateFormats == [.monthDayYear])
        #expect(monthFirst.dated(using: .monthDayYear).rows.map(\.date) == [noon(2026, 3, 13), noon(2026, 3, 5)])
    }

    @Test func slashDatesWithNoDayAfterTwelveAreAmbiguous() throws {
        let parsed = try parse("Date,Amount\n03/05/2026,1\n04/06/2026,1\n")
        #expect(parsed.isAmbiguous)
        #expect(parsed.dateFormats == [.dayMonthYear, .monthDayYear])
        #expect(parsed.dated(using: .dayMonthYear).rows.map(\.date) == [noon(2026, 5, 3), noon(2026, 6, 4)])
        #expect(parsed.dated(using: .monthDayYear).rows.map(\.date) == [noon(2026, 3, 5), noon(2026, 4, 6)])
    }

    @Test func slashDatesThatReadTheSameEitherWayAreNotAmbiguous() throws {
        let parsed = try parse("Date,Amount\n05/05/2026,1\n12/12/2026,1\n")
        #expect(!parsed.isAmbiguous)
        #expect(parsed.dateFormats == [.dayMonthYear])
    }

    @Test(arguments: [
        ("2026-03-05", ImportDateFormat.yearMonthDay),
        ("2026/03/05", .yearMonthDaySlashes),
        ("05.03.2026", .dayMonthYearDots),
        ("05-03-2026", .dayMonthYearDashes),
        ("2026-03-05 14:30", .yearMonthDay),
        ("2026-03-05T14:30:00Z", .yearMonthDay),
        ("05/03/2026 14:30:15", .dayMonthYear),
        ("5.3.2026", .dayMonthYearDots),
    ])
    func eachFormatIsDetectedFromTheColumn(text: String, format: ImportDateFormat) throws {
        let parsed = try parse("Date,Amount\n\(text),1\n")
        #expect(parsed.dateFormats.first == format)
        #expect(parsed.dated(using: format).rows.first?.date == noon(2026, 3, 5))
        #expect(parsed.invalid.isEmpty)
    }

    @Test func isoDatesWinOverEveryOtherFormat() throws {
        #expect(try parse("Date,Amount\n2026-03-05,1\n2026-12-31,1\n").dateFormats == [.yearMonthDay])
    }

    @Test func badDatesMakeTheRowInvalidWithItsLine() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,1\n2026-13-45,1\nyesterday,1\n,1\n2026-02-30,1\n2026-03-06,1\n")
        let dated = parsed.dated(using: parsed.dateFormats[0])
        #expect(dated.rows.map(\.date) == [noon(2026, 3, 5), noon(2026, 3, 6)])
        #expect(dated.invalid == [
            .init(line: 3, reason: .date), .init(line: 4, reason: .date),
            .init(line: 5, reason: .date), .init(line: 6, reason: .date),
        ])
    }

    @Test func aMixedColumnUsesTheBestFittingFormatAndFlagsTheRest() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,1\n2026-03-06,1\n06.03.2026,1\n")
        #expect(parsed.dateFormats == [.yearMonthDay])
        let dated = parsed.dated(using: .yearMonthDay)
        #expect(dated.rows.count == 2)
        #expect(dated.invalid == [.init(line: 4, reason: .date)])
    }

    @Test func invalidRowsFromAllCausesAreSortedByLine() throws {
        let parsed = try parse("Date,Amount\nbad,1\n2026-03-06,oops\n2026-03-07,1\n2026-03-08\n")
        #expect(parsed.dated(using: parsed.dateFormats[0]).invalid == [
            .init(line: 2, reason: .date), .init(line: 3, reason: .amount), .init(line: 5, reason: .columnCount),
        ])
    }

    // MARK: File

    @Test func readsAFileFromDisk() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "reader-test-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("\u{FEFF}Date,Name,Amount\r\n2026-03-05,Café,3.5\r\n".utf8).write(to: url)

        let parsed = try await ExpenseCSVReader.read(contentsOf: url, currencyCode: "EUR")
        #expect(parsed.records.map(\.name) == ["Café"])

        await #expect(throws: (any Error).self) {
            try await ExpenseCSVReader.read(contentsOf: url.appending(path: "missing"), currencyCode: "EUR")
        }
    }
}
