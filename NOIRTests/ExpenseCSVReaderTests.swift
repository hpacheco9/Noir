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

    private func dates(_ parsed: ExpenseCSVReader.Parsed, _ format: ImportDateFormat) -> [Date?] {
        parsed.records.map { format.date(from: $0.dateText, timeZone: parsed.timeZone) }
    }

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
        #expect(dates(parsed, parsed.dateFormats[0]) == [noon(2026, 3, 5)])

        let auckland = TimeZone(identifier: "Pacific/Auckland")!
        let local = try ExpenseCSVReader.parse(text: "Date,Amount\n2026-03-05,1\n", currencyCode: "EUR", timeZone: auckland)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = auckland
        let date = try #require(dates(local, local.dateFormats[0]).first ?? nil)
        let read = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect([read.year, read.month, read.day, read.hour] == [2026, 3, 5, 12])
        #expect(date != noon(2026, 3, 5))
    }

    @Test func aDayAfterTwelveSettlesTheFormat() throws {
        let dayFirst = try parse("Date,Amount\n13/03/2026,1\n05/03/2026,1\n")
        #expect(dayFirst.dateFormats == [.dayMonthYear])
        #expect(!dayFirst.isAmbiguous)
        #expect(dates(dayFirst, .dayMonthYear) == [noon(2026, 3, 13), noon(2026, 3, 5)])

        let monthFirst = try parse("Date,Amount\n03/13/2026,1\n03/05/2026,1\n")
        #expect(monthFirst.dateFormats == [.monthDayYear])
        #expect(dates(monthFirst, .monthDayYear) == [noon(2026, 3, 13), noon(2026, 3, 5)])
    }

    @Test func slashDatesWithNoDayAfterTwelveAreAmbiguous() throws {
        let parsed = try parse("Date,Amount\n03/05/2026,1\n04/06/2026,1\n")
        #expect(parsed.isAmbiguous)
        #expect(parsed.dateFormats == [.dayMonthYear, .monthDayYear])
        #expect(dates(parsed, .dayMonthYear) == [noon(2026, 5, 3), noon(2026, 6, 4)])
        #expect(dates(parsed, .monthDayYear) == [noon(2026, 3, 5), noon(2026, 4, 6)])
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
        #expect(dates(parsed, format) == [noon(2026, 3, 5)])
        #expect(parsed.invalid.isEmpty)
    }

    @Test func isoDatesWinOverEveryOtherFormat() throws {
        #expect(try parse("Date,Amount\n2026-03-05,1\n2026-12-31,1\n").dateFormats == [.yearMonthDay])
    }

    @Test func aMixedColumnUsesTheBestFittingFormat() throws {
        let parsed = try parse("Date,Amount\n2026-03-05,1\n2026-03-06,1\n06.03.2026,1\n")
        #expect(parsed.dateFormats == [.yearMonthDay])
        #expect(dates(parsed, .yearMonthDay) == [noon(2026, 3, 5), noon(2026, 3, 6), nil])
    }

    @Test func aJunkRowDoesNotHideAnAmbiguousColumn() throws {
        let clean = try parse("Date,Amount\n03/05/2026,1\n04/06/2026,1\n")
        let junk = try parse("Date,Amount\n03/05/2026,1\n04/06/2026,1\nTotal,2\n")
        // Control: the clean file asks, and so does the same file with a junk row.
        #expect(clean.dateFormats == [.dayMonthYear, .monthDayYear])
        #expect(junk.dateFormats == [.dayMonthYear, .monthDayYear])
        #expect(junk.isAmbiguous)
        #expect(dates(junk, .monthDayYear) == [noon(2026, 3, 5), noon(2026, 4, 6), nil])
    }

    @Test func aJunkRowDoesNotUnsettleAClearColumn() throws {
        #expect(try parse("Date,Amount\n13/03/2026,1\n05/03/2026,1\nTotal,2\n").dateFormats == [.dayMonthYear])
        #expect(try parse("Date,Amount\nnope,1\nnever,1\n").dateFormats.count == 1)
    }

    @Test func twoDigitYearsAreNotDates() throws {
        #expect(ImportDateFormat.dayMonthYear.date(from: "05/03/26", timeZone: utc) == nil)
        #expect(ImportDateFormat.dayMonthYear.date(from: "05/03/2026", timeZone: utc) == noon(2026, 3, 5))
    }

    @Test func dateColumnSynonymsAreAccepted() throws {
        for header in ["Transaction Date", "Booking date", "posted date"] {
            let parsed = try parse("\(header),Amount\n2026-03-05,1\n")
            #expect(parsed.records.count == 1, "\(header)")
        }
    }

    // MARK: Amount currency

    @Test func aDotDecimalIsTakenWhenItFitsTheCurrencysMinorUnits() throws {
        // NOIR's own export never writes more decimals than the currency has.
        #expect(amounts(try parse("Date,Amount\n2026-03-05,12.5\n2026-03-06,12.50\n", currency: "EUR")) == [12.5, 12.5])
        #expect(amounts(try parse("Date,Amount\n2026-03-05,12.345\n", currency: "KWD")) == [12.345])
        #expect(amounts(try parse("Date,Amount\n2026-03-05,1234\n", currency: "JPY")) == [1234])
    }

    @Test func moreDecimalsThanTheCurrencyHasAreGroupingNotADecimal() throws {
        // Control first: EUR "12.5" is plain, so it stays 12.5.
        #expect(amounts(try parse("Date,Amount\n2026-03-05,12.5\n", currency: "EUR")) == [12.5])
        #expect(amounts(try parse("Date,Amount\n2026-03-05,1.234\n", currency: "EUR")) == [1234])
        // KWD has three, so the same text there is a decimal.
        #expect(amounts(try parse("Date,Amount\n2026-03-05,12.345\n", currency: "KWD")) == [12.345])
        // JPY has none: "1.234" and "12.50" are grouped.
        #expect(amounts(try parse("Date,Amount\n2026-03-05,1.234\n2026-03-06,12.50\n", currency: "JPY")) == [1234, 1250])
        // The row's currency decides, not the app's.
        #expect(amounts(try parse("Date,Amount,Currency\n2026-03-05,12.345,KWD\n2026-03-06,1.234,EUR\n", currency: "JPY")) == [12.345, 1234])
    }

    @Test func aDotAmountTheLenientReaderCannotReadIsInvalid() throws {
        #expect(try parse("Date,Amount\n2026-03-05,...\n2026-03-06,-.\n2026-03-07,1.234\n", currency: "EUR").invalid
                == [.init(line: 2, reason: .amount), .init(line: 3, reason: .amount)])
    }

    @Test func otherTextFollowsTheRowsCurrencyThenTheAppsCurrency() throws {
        let grouped = "Date,Amount\n2026-03-05,\"1,234\"\n"
        // JPY has no minor units, so the comma is grouping; EUR reads it as a decimal comma.
        #expect(amounts(try parse(grouped, currency: "JPY")) == [1234])
        #expect(amounts(try parse(grouped, currency: "EUR")) == [1.23])
        // The row's own currency wins over the app's.
        #expect(amounts(try parse("Date,Amount,Currency\n2026-03-05,\"1,234\",JPY\n", currency: "EUR")) == [1234])
    }

    @Test func valuesAreRoundedToTheirCurrencysMinorUnits() throws {
        // A decimal comma has no limit on its digits, so these are rounded: EUR to cents, KWD kept, JPY to the yen.
        let text = "Date,Amount,Currency\n2026-03-05,\"12,345\",EUR\n2026-03-06,\"12,3456\",KWD\n2026-03-07,\"1,235\",JPY\n"
        #expect(amounts(try parse(text, currency: "EUR")) == [12.35, 12.346, 1235])
        // Without a currency column the app's currency decides.
        #expect(amounts(try parse("Date,Amount\n2026-03-05,\"12,345\"\n", currency: "EUR")) == [12.35])
        // An amount that rounds to nothing is no amount.
        #expect(try parse("Date,Amount\n2026-03-05,\"0,004\"\n", currency: "EUR").invalid == [.init(line: 2, reason: .amount)])
    }

    @Test func aCurrencyCellThatIsNotACodeIsIgnored() throws {
        #expect(amounts(try parse("Date,Amount,Currency\n2026-03-05,\"1,234\",euros\n", currency: "JPY")) == [1234])
    }

    @Test(arguments: [
        ("JPY", [1235.0, 80, 5000]),
        ("KWD", [12.345, 0.5, 1000.001]),
        ("EUR", [19.99, 1234.5, 0.05]),
        ("USD", [3.5, 100, 1_000_000.25]),
    ])
    func exportedAmountsComeBackInEveryCurrency(code: String, values: [Double]) throws {
        let rows = values.map {
            ExpenseCSV.Row(date: noon(2026, 3, 5), name: "x", amount: $0, category: "Food", card: "", note: "", categoryKey: "food")
        }
        let headers = ExpenseCSV.Headers(
            date: "Date", name: "Name", amount: "Amount", currency: "Currency", category: "Category", card: "Card", note: "Note"
        )
        let csv = ExpenseCSV.make(rows: rows, headers: headers, currencyCode: code, timeZone: utc)
        // Whatever the app's currency is, the file's own column decides.
        for appCurrency in ["EUR", "JPY", "DKK", code] {
            #expect(amounts(try parse(csv, currency: appCurrency)) == values, "\(code) read as \(appCurrency)")
        }
    }

    // MARK: Row shapes

    @Test func shortRowsArePaddedWhenOnlyOptionalColumnsAreMissing() throws {
        let parsed = try parse("Date,Name,Amount,Card,Note\n2026-03-05,Tea,2\n2026-03-06,Coffee,3,Visa\n")
        #expect(parsed.invalid.isEmpty)
        #expect(parsed.records.map(\.card) == ["", "Visa"])
        #expect(parsed.records.map(\.note) == ["", ""])
        // Control: a row missing the Amount cell is still invalid.
        #expect(try parse("Date,Name,Amount\n2026-03-05,Tea\n").invalid == [.init(line: 2, reason: .columnCount)])
        #expect(try parse("Date,Name,Amount\n2026-03-05\n").invalid == [.init(line: 2, reason: .columnCount)])
    }

    @Test func extraEmptyColumnsAreIgnoredButExtraValuesAreNot() throws {
        let parsed = try parse("Date,Name,Amount\n2026-03-05,Tea,2,,\n2026-03-06,Tea,2, \n2026-03-07,Tea,2,x\n")
        #expect(parsed.records.map(\.line) == [2, 3])
        #expect(parsed.invalid == [.init(line: 4, reason: .columnCount)])
    }

    @Test func spacesBeforeAnOpeningQuoteStillOpenIt() throws {
        let parsed = try parse("Date,Name,Amount\n2026-03-05, \"Coffee, large\",3.5\n2026-03-06,\t\"Tea, big\" ,2\n")
        #expect(parsed.invalid.isEmpty)
        #expect(parsed.records.map(\.name) == ["Coffee, large", "Tea, big"])
        // Control: a quote inside text is just text.
        #expect(try parse("Date,Name,Amount\n2026-03-05,5\" pipe,3.5\n").records.first?.name == "5\" pipe")
    }

    // MARK: Bad bytes

    @Test func oneBadByteInUTF8TextDoesNotTurnTheFileIntoWindows1252() throws {
        var data = Data("Date,Name,Amount\n2026-03-05,Crème brûlée ç,3\n2026-03-06,Caf".utf8)
        data.append(0xE9)
        data.append(contentsOf: "\n".utf8)
        let text = try #require(ExpenseCSVReader.decode(data))
        #expect(text.contains("Crème brûlée ç"))
        #expect(text.contains("\u{FFFD}"))
        // Control: with no valid UTF-8 text at all, high bytes are Windows-1252.
        let ansi = try #require(ExpenseCSVReader.decode("Date,Name,Amount\n2026-03-05,Café ñ,3\n".data(using: .windowsCP1252)!))
        #expect(ansi.contains("Café ñ"))
        #expect(!ansi.contains("\u{FFFD}"))
    }

    @Test func aWindows1252FileWithAnAccidentalUTF8PairIsStillWindows1252() throws {
        let data = try #require("Date,Name,Amount\n2026-03-05,CAFÉ–BAR,3\n2026-03-06,Crème,2\n".data(using: .windowsCP1252))
        // Control: "É–" (C9 96) happens to be a valid UTF-8 character, so a "has valid non-ASCII text" check is fooled.
        #expect(String(decoding: data, as: UTF8.self).contains("\u{256}"))
        let text = try #require(ExpenseCSVReader.decode(data))
        #expect(text.contains("CAFÉ–BAR"))
        #expect(text.contains("Crème"))
        #expect(!text.contains("\u{FFFD}"))
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
