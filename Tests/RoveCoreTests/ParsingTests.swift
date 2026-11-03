import XCTest
@testable import RoveCore

final class ParsingTests: XCTestCase {
    func testMoneyParsing() {
        XCTAssertEqual(MoneyParser.parse("12.5", currency: "USD"), 1250)
        XCTAssertEqual(MoneyParser.parse("$1,234.56", currency: "USD"), 123456)
        XCTAssertEqual(MoneyParser.parse("1200", currency: "USD"), 120000)
        XCTAssertEqual(MoneyParser.parse(".99", currency: "USD"), 99)
        XCTAssertEqual(MoneyParser.parse("3000", currency: "JPY"), 3000)
        XCTAssertNil(MoneyParser.parse("12.345", currency: "USD"))
        XCTAssertNil(MoneyParser.parse("1.2.3", currency: "USD"))
        XCTAssertNil(MoneyParser.parse("", currency: "USD"))
        XCTAssertNil(MoneyParser.parse("12.5", currency: "JPY"))
    }

    func testMoneyFormatting() {
        XCTAssertEqual(Money(123456, "USD").formatted(), "$1,234.56")
        XCTAssertEqual(Money(120000, "USD").formatted(wholeIfRound: true), "$1,200")
        XCTAssertEqual(Money(120050, "USD").formatted(wholeIfRound: true), "$1,200.50")
        XCTAssertEqual(Money(1250, "USD").plainText, "12.50")
        XCTAssertEqual(Money(3000, "JPY").plainText, "3000")
    }

    func testRateParsing() {
        XCTAssertEqual(Conversion.parseRate("1.08"), Decimal(string: "1.08"))
        XCTAssertEqual(Conversion.parseRate("0,055"), Decimal(string: "0.055"))
        XCTAssertNil(Conversion.parseRate("0"))
        XCTAssertNil(Conversion.parseRate("abc"))
    }

    func testProviderButtons() {
        XCTAssertEqual(ListingLinks.buttonTitle(for: "https://www.expedia.com/Nashville-Hotels.h123.Hotel-Information"), "View on Expedia")
        XCTAssertEqual(ListingLinks.buttonTitle(for: "airbnb.com/rooms/123"), "View on Airbnb")
        XCTAssertEqual(ListingLinks.buttonTitle(for: "https://m.booking.com/hotel/us/x.html"), "View on Booking.com")
        XCTAssertEqual(ListingLinks.buttonTitle(for: "https://www.google.com/travel/flights?q=x"), "View on Google Flights")
        XCTAssertEqual(ListingLinks.buttonTitle(for: "https://www.ryman.com/tours"), "Open listing")
        XCTAssertEqual(ListingLinks.shortLabel(for: "https://www.ryman.com/tours"), "ryman.com")
        // A look-alike domain isn't Airbnb.
        XCTAssertEqual(ListingLinks.buttonTitle(for: "https://airbnb.com.evil.example/rooms"), "Open listing")
        XCTAssertNil(ListingLinks.url("not a link"))
    }

    func testPollPermissions() {
        let organizer = UUID(), member = UUID(), picked = UUID()
        XCTAssertEqual(PollPermission.for(personID: organizer, organizerID: organizer, policy: .selected, publishers: []), .publish)
        XCTAssertEqual(PollPermission.for(personID: member, organizerID: organizer, policy: .everyone, publishers: []), .publish)
        XCTAssertEqual(PollPermission.for(personID: member, organizerID: organizer, policy: .selected, publishers: [picked]), .none)
        XCTAssertEqual(PollPermission.for(personID: picked, organizerID: organizer, policy: .selected, publishers: [picked]), .publish)
        XCTAssertEqual(PollPermission.for(personID: member, organizerID: organizer, policy: .approval, publishers: []), .request)
    }

    // MARK: Receipts

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func ymd(_ date: Date?) -> [Int] {
        guard let date else { return [] }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return [parts.year!, parts.month!, parts.day!]
    }

    func testRestaurantReceipt() {
        let lines = [
            "HATTIE B'S HOT CHICKEN",
            "112 19th Ave S",
            "Nashville, TN 37203",
            "Server: Kayla   Table 12",
            "11/21/2026 7:42 PM",
            "2 Medium Dark Plate   27.00",
            "1 Pimento Mac          4.50",
            "2 Sweet Tea            7.00",
            "Subtotal              38.50",
            "Sales Tax              3.98",
            "Tip                    7.70",
            "Total                 50.18",
            "VISA ****1234",
        ]
        let d = ReceiptParser.parse(lines: lines, defaultCurrency: "USD", calendar: calendar)
        XCTAssertEqual(d.merchant, "Hattie B's Hot Chicken")
        XCTAssertEqual(ymd(d.date), [2026, 11, 21])
        XCTAssertEqual(d.subtotalMinor, 3850)
        XCTAssertEqual(d.taxMinor, 398)
        XCTAssertEqual(d.tipMinor, 770)
        XCTAssertEqual(d.totalMinor, 5018)
        XCTAssertNil(d.currency, "No currency printed: the trip's is used")
    }

    // The printed total is before tip; the tip is written in: total adds it.
    func testTipAddedAfterPrintedTotal() {
        let lines = ["Joe's Cafe", "Date: 2026-11-20", "Subtotal 20.00", "Tax 1.40", "Total 21.40", "Tip 4.00"]
        let d = ReceiptParser.parse(lines: lines, defaultCurrency: "USD", calendar: calendar)
        XCTAssertEqual(d.merchant, "Joe's Cafe")
        XCTAssertEqual(ymd(d.date), [2026, 11, 20])
        XCTAssertEqual(d.totalMinor, 2540)
    }

    // Labels and amounts on separate lines, a euro receipt, a written-out date.
    func testSplitLinesAndEuro() {
        let lines = ["Café de Flore", "Nov 18, 2026", "TOTAL", "€ 42,50", "TVA incl."]
        let d = ReceiptParser.parse(lines: lines, defaultCurrency: "USD", calendar: calendar)
        XCTAssertEqual(d.currency, "EUR")
        XCTAssertEqual(d.totalMinor, 4250)
        XCTAssertEqual(ymd(d.date), [2026, 11, 18])
    }

    func testSuggestedTipLinesAreIgnored() {
        let lines = ["Pizza Place", "Subtotal 30.00", "Total 32.10", "Suggested tip 18%: 5.40", "Multiple items 2.00"]
        let d = ReceiptParser.parse(lines: lines, defaultCurrency: "USD", calendar: calendar)
        XCTAssertNil(d.tipMinor)
        XCTAssertEqual(d.totalMinor, 3210)
    }

    func testNoTotalUsesLargestAmount() {
        let d = ReceiptParser.parse(lines: ["Gas Station", "Unleaded 12.345 gal", "Sale $48.21"], defaultCurrency: "USD", calendar: calendar)
        XCTAssertEqual(d.totalMinor, 4821)
    }
}
