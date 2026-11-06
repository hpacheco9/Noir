//
//  ExpenseCSVTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct ExpenseCSVTests {
    private let headers = ExpenseCSV.Headers(
        date: "Date", name: "Name", amount: "Amount", currency: "Currency",
        category: "Category", card: "Card", note: "Note", categoryID: "Category ID"
    )
    private let headerLine = "Date,Name,Amount,Currency,Category,Card,Note,Category ID"
    private let utc = TimeZone(secondsFromGMT: 0)!

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func row(
        name: String = "Coffee", amount: Double = 3.5, category: String = "Food",
        card: String = "", note: String = "", date: Date? = nil, categoryKey: String = "food"
    ) -> ExpenseCSV.Row {
        ExpenseCSV.Row(
            date: date ?? self.date(2026, 3, 5), name: name, amount: amount,
            category: category, card: card, note: note, categoryKey: categoryKey
        )
    }

    private func make(_ rows: [ExpenseCSV.Row], currency: String = "EUR") -> String {
        ExpenseCSV.make(rows: rows, headers: headers, currencyCode: currency, timeZone: utc)
    }

    // The data line of a one-row file (the BOM sits on the header line).
    private func dataLine(_ row: ExpenseCSV.Row, currency: String = "EUR") -> String {
        let lines = make([row], currency: currency).components(separatedBy: "\r\n")
        return lines[1]
    }

    // MARK: Layout

    @Test func emptyListIsTheHeaderOnly() {
        #expect(make([]) == "\u{FEFF}\(headerLine)\r\n")
    }

    @Test func startsWithAUTF8ByteOrderMark() {
        #expect(Array(make([row()]).utf8.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(Array(make([]).utf8.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test func linesEndWithCRLFAndNeverBareLF() {
        let text = make([row(), row(name: "Tea")])
        #expect(text.hasSuffix("\r\n"))
        #expect(text.components(separatedBy: "\r\n").count == 4) // header, 2 rows, empty tail
        let withoutCRLF = text.replacingOccurrences(of: "\r\n", with: "")
        #expect(!withoutCRLF.contains("\n"))
        #expect(!withoutCRLF.contains("\r"))

        // Control: a note with a bare LF is kept as is (quoted), so the same check does fire on it.
        let withNote = make([row(note: "a\nb")]).replacingOccurrences(of: "\r\n", with: "")
        #expect(withNote.contains("\n"))
    }

    @Test func rowsKeepTheOrderTheyAreGiven() {
        let text = make([row(name: "first"), row(name: "second"), row(name: "third")])
        let names = text.components(separatedBy: "\r\n").dropFirst().prefix(3).map { $0.split(separator: ",")[1] }
        #expect(names == ["first", "second", "third"])
    }

    @Test func columnsAreInTheDocumentedOrder() {
        let line = dataLine(row(name: "Coffee", amount: 3.5, category: "Food", card: "Visa", note: "Morning"))
        #expect(line == "2026-03-05,Coffee,3.5,EUR,Food,Visa,Morning,food")
    }

    @Test func theLastColumnIsTheRawCategoryKey() {
        let id = "custom:5E4F888E-D8BD-4798-9D2C-4EBD856B8B6E"
        #expect(dataLine(row(category: "Pets", categoryKey: id)).hasSuffix(",Pets,,,\(id)"))
        #expect(dataLine(row(category: "Shopping", categoryKey: "clothing")).hasSuffix(",Shopping,,,clothing"))
        #expect(make([]).contains(",Note,Category ID\r\n"))
    }

    @Test func theCategoryIDHeaderIsEnglishWhateverTheLocalizedHeaders() {
        let german = ExpenseCSV.Headers(
            date: "Datum", name: "Name", amount: "Betrag", currency: "Währung",
            category: "Kategorie", card: "Karte", note: "Notiz"
        )
        #expect(ExpenseCSV.make(rows: [], headers: german, currencyCode: "EUR", timeZone: utc)
                == "\u{FEFF}Datum,Name,Betrag,Währung,Kategorie,Karte,Notiz,Category ID\r\n")
    }

    @Test func sampleFile() {
        let text = make([
            row(name: "Coffee", amount: 3.5, card: "Visa", date: date(2026, 3, 5)),
            row(name: "Dinner, \"Chez Paul\"", amount: 19.99, category: "Leisure", note: "Line one\nLine two", date: date(2026, 3, 6)),
            row(name: "=SUM(1)", amount: 1234.5, category: "Home", date: date(2026, 3, 7)),
        ], currency: "USD")
        let expected = [
            headerLine,
            "2026-03-05,Coffee,3.5,USD,Food,Visa,,food",
            "2026-03-06,\"Dinner, \"\"Chez Paul\"\"\",19.99,USD,Leisure,,\"Line one\nLine two\",food",
            "2026-03-07,'=SUM(1),1234.5,USD,Home,,,food",
        ].joined(separator: "\r\n") + "\r\n"
        #expect(text == "\u{FEFF}" + expected)
    }

    @Test func currencyCodeIsOnEveryRow() {
        let lines = make([row(), row()], currency: "BRL").components(separatedBy: "\r\n")
        #expect(lines[1].contains(",BRL,"))
        #expect(lines[2].contains(",BRL,"))
    }

    // MARK: Escaping

    @Test func fieldsWithSpecialCharactersAreQuoted() {
        #expect(ExpenseCSV.escape("a,b") == "\"a,b\"")
        #expect(ExpenseCSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(ExpenseCSV.escape("one\ntwo") == "\"one\ntwo\"")
        #expect(ExpenseCSV.escape("one\rtwo") == "\"one\rtwo\"")
    }

    // "\r\n" is one Character that is neither "\r" nor "\n": a Character-based check would miss it.
    @Test func crlfInsideAFieldIsQuoted() {
        #expect(ExpenseCSV.escape("one\r\ntwo") == "\"one\r\ntwo\"")
    }

    @Test func plainFieldsAreLeftAlone() {
        #expect(ExpenseCSV.escape("Coffee") == "Coffee")
        #expect(ExpenseCSV.escape("Café São Paulo 'x'") == "Café São Paulo 'x'")
        #expect(ExpenseCSV.escape("") == "")
    }

    @Test func commasAndQuotesInSeveralFieldsAreEscapedTogether() {
        let line = dataLine(row(name: "a,\"b\",c", note: "x,y"))
        #expect(line == "2026-03-05,\"a,\"\"b\"\",c\",3.5,EUR,Food,,\"x,y\",food")
    }

    @Test func headersAreEscapedToo() {
        var custom = headers
        custom.amount = "Amount, total"
        let text = ExpenseCSV.make(rows: [], headers: custom, currencyCode: "EUR", timeZone: utc)
        #expect(text.contains("Name,\"Amount, total\",Currency"))
    }

    // MARK: Formula guard

    @Test(arguments: ["=SUM(1)", "+1", "-1", "@cmd", "\tx", "\rx"])
    func textStartingWithATriggerGetsAQuote(value: String) {
        #expect(ExpenseCSV.text(value) == "'" + value)
    }

    @Test(arguments: ["Coffee", "a=b", "1+1", "x-y", "me@home", " =space first", "'=already", "", "Ünïcode"])
    func ordinaryTextIsNotTouched(value: String) {
        #expect(ExpenseCSV.text(value) == value)
    }

    @Test func guardAppliesToNameCategoryCardAndNote() {
        let line = dataLine(row(name: "=A", category: "+B", card: "-C", note: "@D"))
        #expect(line == "2026-03-05,'=A,3.5,EUR,'+B,'-C,'@D,food")
    }

    @Test func guardAndQuotingCombine() {
        #expect(dataLine(row(name: "=1,2")).hasPrefix("2026-03-05,\"'=1,2\","))
        // A leading CR is both a trigger and a reason to quote.
        #expect(ExpenseCSV.escape(ExpenseCSV.text("\rx")) == "\"'\rx\"")
    }

    @Test func guardDoesNotTouchDateAmountOrCurrency() {
        let line = dataLine(row(amount: 5))
        #expect(line == "2026-03-05,Coffee,5,EUR,Food,,,food")
    }

    // MARK: Amounts

    @Test func amountsKeepTheirShortestForm() {
        #expect(ExpenseCSV.amountString(19.99, fractionDigits: 2) == "19.99")
        #expect(ExpenseCSV.amountString(1234.5, fractionDigits: 2) == "1234.5")
        #expect(ExpenseCSV.amountString(0.1, fractionDigits: 2) == "0.1")
        #expect(ExpenseCSV.amountString(0.01, fractionDigits: 2) == "0.01")
        #expect(ExpenseCSV.amountString(5, fractionDigits: 2) == "5")
        #expect(ExpenseCSV.amountString(100, fractionDigits: 2) == "100")
    }

    @Test func largeAmountsHaveNoGroupingOrExponent() {
        #expect(ExpenseCSV.amountString(1_234_567.89, fractionDigits: 2) == "1234567.89")
        #expect(ExpenseCSV.amountString(123_456_789_012.34, fractionDigits: 2) == "123456789012.34")
        #expect(ExpenseCSV.amountString(Expense.maxAmount, fractionDigits: 2) == "1000000000000")
    }

    @Test func floatNoiseIsRoundedAway() {
        // Control: the raw Double really carries the noise.
        #expect((0.1 + 0.2).description == "0.30000000000000004")
        #expect(ExpenseCSV.amountString(0.1 + 0.2, fractionDigits: 2) == "0.3")
        #expect(ExpenseCSV.amountString(15.129, fractionDigits: 2) == "15.13")
        #expect(ExpenseCSV.amountString(12.3 * 1.23, fractionDigits: 2) == "15.13")
    }

    @Test func roundingIsPlainHalfAwayFromZero() {
        #expect(ExpenseCSV.amountString(0.125, fractionDigits: 2) == "0.13")
        #expect(ExpenseCSV.amountString(1.005, fractionDigits: 2) == "1.01")
        #expect(ExpenseCSV.amountString(1.004, fractionDigits: 2) == "1")
    }

    @Test func amountsFollowTheCurrencyMinorUnits() {
        #expect(ExpenseCSV.fractionDigits(for: "EUR") == 2)
        #expect(ExpenseCSV.fractionDigits(for: "USD") == 2)
        #expect(ExpenseCSV.fractionDigits(for: "JPY") == 0)

        let jpy = ExpenseCSV.fractionDigits(for: "JPY")
        #expect(ExpenseCSV.amountString(1234.6, fractionDigits: jpy) == "1235")
        #expect(ExpenseCSV.amountString(1234.4, fractionDigits: jpy) == "1234")

        #expect(dataLine(row(amount: 1234.6), currency: "JPY") == "2026-03-05,Coffee,1235,JPY,Food,,,food")
        #expect(dataLine(row(amount: 1234.6), currency: "EUR") == "2026-03-05,Coffee,1234.6,EUR,Food,,,food")
    }

    @Test func tinyAndHugeAmountsGoThroughTheExponentForm() {
        // Control: both descriptions really are in exponent form.
        #expect(0.00001.description == "1e-05")
        #expect(ExpenseCSV.amountString(0.00001, fractionDigits: 2) == "0")
        #expect(ExpenseCSV.amountString(1e12, fractionDigits: 2) == "1000000000000")
    }

    // MARK: Dates

    @Test func datesAreYearMonthDayWithLeadingZeros() {
        #expect(dataLine(row(date: date(2026, 3, 5))).hasPrefix("2026-03-05,"))
        #expect(dataLine(row(date: date(2026, 12, 31))).hasPrefix("2026-12-31,"))
    }

    @Test func datesUseTheGivenTimeZone() {
        // 05:00 UTC is still the day before in Los Angeles (UTC-8).
        let sample = [row(date: date(2026, 1, 1, 5))]
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        #expect(ExpenseCSV.make(rows: sample, headers: headers, currencyCode: "EUR", timeZone: utc).contains("\r\n2026-01-01,"))
        #expect(ExpenseCSV.make(rows: sample, headers: headers, currencyCode: "EUR", timeZone: losAngeles).contains("\r\n2025-12-31,"))
    }

    @Test func fileNameCarriesTheDay() {
        #expect(ExpenseCSV.fileName(for: date(2026, 3, 5), timeZone: utc) == "NOIR Expenses 2026-03-05.csv")
        #expect(ExpenseCSV.fileName(for: date(2025, 12, 31, 23, 30), timeZone: TimeZone(identifier: "Pacific/Auckland")!)
                == "NOIR Expenses 2026-01-01.csv")
    }
}
