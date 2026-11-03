import XCTest
@testable import RoveCore

/// Splits, balances and repayments, each checked against numbers worked out
/// by hand.
final class LedgerTests: XCTestCase {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    private func trip(_ members: [(UUID, Int)]) -> Trip {
        Trip(name: "Test", destination: "Here", startDate: Date(), endDate: Date(), organizerID: members[0].0, stage: .trip,
             members: members.map { TripMember(personID: $0.0, partySize: $0.1, response: .interested) })
    }

    private func expense(_ dollars: Int64, cents: Int64 = 0, paidBy payer: UUID, among ids: [UUID], on trip: Trip) -> Expense {
        Expense(title: "x", date: Date(), payerID: payer, amount: Money(dollars * 100 + cents, "USD"),
                tripCurrency: "USD", shares: Ledger.equalShares(ids, on: trip))
    }

    private func net(_ trip: Trip) -> [UUID: Int64] {
        Dictionary(uniqueKeysWithValues: Ledger.balances(for: trip).map { ($0.personID, $0.net) })
    }

    // $90 dinner, A pays, A B C split evenly: B and C each owe A $30.
    func testEqualSplitThreeWays() {
        var t = trip([(a, 1), (b, 1), (c, 1)])
        t.expenses = [expense(90, paidBy: a, among: [a, b, c], on: t)]
        XCTAssertEqual(net(t), [a: 6000, b: -3000, c: -3000])
        let transfers = Ledger.suggestedRepayments(for: t)
        XCTAssertEqual(Set(transfers), [Transfer(fromID: b, toID: a, amountMinor: 3000), Transfer(fromID: c, toID: a, amountMinor: 3000)])
    }

    // B signs up "for 2". $90 paid by A, split evenly by head among A and B's
    // party of 2: 3 heads at $30, so B owes A $60.
    func testPartyOfTwoCountsDouble() {
        var t = trip([(a, 1), (b, 2)])
        t.expenses = [expense(90, paidBy: a, among: [a, b], on: t)]
        XCTAssertEqual(t.expenses[0].owedInTripCurrency, [a: 3000, b: 6000])
        XCTAssertEqual(Ledger.suggestedRepayments(for: t), [Transfer(fromID: b, toID: a, amountMinor: 6000)])
    }

    // B (for 2) pays $100 for A, B's party and C: 4 heads at $25.
    // A owes $25, C owes $25; B's own share is $50 of the $100 they paid.
    func testPartyOfTwoAsPayer() {
        var t = trip([(a, 1), (b, 2), (c, 1)])
        t.expenses = [expense(100, paidBy: b, among: [a, b, c], on: t)]
        XCTAssertEqual(net(t), [a: -2500, b: 5000, c: -2500])
    }

    // $100 in three: 33.34 + 33.33 + 33.33, never a lost or extra cent.
    func testLeftoverCentGoesToFirstListed() {
        let parts = Ledger.allocate(10000, weights: [(a, 1), (b, 1), (c, 1)])
        XCTAssertEqual(parts, [a: 3334, b: 3333, c: 3333])
        XCTAssertEqual(parts.values.reduce(0, +), 10000)
    }

    // $10 among a party of 2 and two singles: 4 heads at $2.50.
    func testWeightedAllocationAddsUp() {
        let parts = Ledger.allocate(1000, weights: [(a, 2), (b, 1), (c, 1)])
        XCTAssertEqual(parts, [a: 500, b: 250, c: 250])
        let odd = Ledger.allocate(1001, weights: [(a, 2), (b, 1), (c, 1)])
        XCTAssertEqual(odd.values.reduce(0, +), 1001)
        XCTAssertEqual(odd[a], 501) // 500.5 has the biggest remainder
    }

    // Custom: $60 cake paid by C; A owes $25, B owes $35, C nothing.
    func testCustomAmounts() {
        var t = trip([(a, 1), (b, 1), (c, 1)])
        t.expenses = [Expense(title: "Cake", date: Date(), payerID: c, amount: Money(6000, "USD"), tripCurrency: "USD",
                              splitMode: .custom, shares: [Share(personID: a, weight: 2500), Share(personID: b, weight: 3500)])]
        XCTAssertTrue(t.expenses[0].customSharesMatchTotal)
        XCTAssertEqual(net(t), [a: -2500, b: -3500, c: 6000])
    }

    // Two payers net out: A pays $120 (A B C), B pays $60 (A B C).
    // A: +120 - 40 - 20 = +60. B: +60 - 40 - 20 = 0. C: -60. One repayment.
    func testNettingNeedsOneRepayment() {
        var t = trip([(a, 1), (b, 1), (c, 1)])
        t.expenses = [expense(120, paidBy: a, among: [a, b, c], on: t), expense(60, paidBy: b, among: [a, b, c], on: t)]
        XCTAssertEqual(net(t), [a: 6000, b: 0, c: -6000])
        XCTAssertEqual(Ledger.suggestedRepayments(for: t), [Transfer(fromID: c, toID: a, amountMinor: 6000)])
    }

    // Recording the suggested repayment brings everyone to zero.
    func testPaymentSettles() {
        var t = trip([(a, 1), (b, 1)])
        t.expenses = [expense(50, paidBy: a, among: [a, b], on: t)]
        let transfer = Ledger.suggestedRepayments(for: t)[0]
        t.payments = [Payment(fromID: transfer.fromID, toID: transfer.toID, amountMinor: transfer.amountMinor, date: Date())]
        XCTAssertTrue(Ledger.balances(for: t).allSatisfy { $0.net == 0 })
        XCTAssertTrue(Ledger.suggestedRepayments(for: t).isEmpty)
        // What each paid and owes for the expense itself doesn't change:
        // A still paid $50 and A's share is still $25.
        let first = Ledger.balances(for: t).first { $0.personID == a }!
        XCTAssertEqual(first.spent, 5000)
        XCTAssertEqual(first.share, 2500)
    }

    // Four people, several expenses: balances always sum to zero and the
    // suggestions settle everyone in at most three payments.
    func testFourPeopleSettleInAtMostThree() {
        var t = trip([(a, 1), (b, 2), (c, 1), (d, 1)])
        t.expenses = [
            expense(1236, paidBy: a, among: [a, b, c, d], on: t),
            expense(375, paidBy: b, among: [a, b, c, d], on: t),
            expense(86, cents: 40, paidBy: d, among: [a, b, c, d], on: t),
            expense(33, cents: 33, paidBy: c, among: [a, c], on: t),
        ]
        let balances = Ledger.balances(for: t)
        XCTAssertEqual(balances.reduce(0) { $0 + $1.net }, 0)
        let transfers = Ledger.settle(balances)
        XCTAssertLessThanOrEqual(transfers.count, 3)
        var after = Dictionary(uniqueKeysWithValues: balances.map { ($0.personID, $0.net) })
        for transfer in transfers {
            after[transfer.fromID, default: 0] += transfer.amountMinor
            after[transfer.toID, default: 0] -= transfer.amountMinor
        }
        XCTAssertTrue(after.values.allSatisfy { $0 == 0 })
    }

    // €50 at 1 EUR = 1.08 USD is $54.00 on the trip ledger; the euro amount is kept.
    func testExpenseInAnotherCurrency() {
        let e = Expense(title: "Lunch", date: Date(), payerID: a, amount: Money(5000, "EUR"), rate: Decimal(string: "1.08"),
                        tripCurrency: "USD", shares: [Share(personID: a, weight: 1), Share(personID: b, weight: 1)])
        XCTAssertEqual(e.tripAmountMinor, 5400)
        XCTAssertEqual(e.amount, Money(5000, "EUR"))
        XCTAssertEqual(e.owedInTripCurrency, [a: 2700, b: 2700])
        XCTAssertEqual(e.owedInOwnCurrency, [a: 2500, b: 2500])
    }

    // ¥3,000 at 0.0067 = $20.10 (yen have no cents).
    func testYenConversion() {
        XCTAssertEqual(Conversion.convert(3000, from: "JPY", to: "USD", rate: Decimal(string: "0.0067")!), 2010)
        // $12.34 to yen at 149.5 = 1844.83 -> ¥1,845
        XCTAssertEqual(Conversion.convert(1234, from: "USD", to: "JPY", rate: Decimal(string: "149.5")!), 1845)
    }

    // Same currency ignores any rate.
    func testSameCurrencyKeepsAmount() {
        let e = Expense(title: "x", date: Date(), payerID: a, amount: Money(1999, "USD"), rate: Decimal(2),
                        tripCurrency: "USD", shares: [Share(personID: a, weight: 1)])
        XCTAssertEqual(e.tripAmountMinor, 1999)
        XCTAssertNil(e.rate)
    }

    func testBigAmountsDontOverflow() {
        let parts = Ledger.allocate(9_000_000_000_000, weights: [(a, 3_000_000_000_000), (b, 6_000_000_000_000)])
        XCTAssertEqual(parts, [a: 3_000_000_000_000, b: 6_000_000_000_000])
    }

    func testSampleTripsBalance() {
        let data = SampleData.make()
        for trip in data.trips {
            XCTAssertEqual(Ledger.balances(for: trip).reduce(0) { $0 + $1.net }, 0, trip.name)
            for expense in trip.expenses {
                XCTAssertEqual(expense.owedInTripCurrency.values.reduce(0, +), expense.tripAmountMinor, expense.title)
                XCTAssertTrue(expense.customSharesMatchTotal, expense.title)
            }
        }
        let orlando = data.trips.first { $0.name == "Orlando Parks" }!
        XCTAssertTrue(Ledger.suggestedRepayments(for: orlando).isEmpty, "The finished sample trip should be settled")
    }

    // Nashville sample, worked by hand. 5 heads (Jordan is for 2).
    // Loft $1,236 / 5 = $247.20 a head. Opry $375 / 5 = $75. SUV $100 / 5 = $20.
    // Cake $60: Alberto, Jordan, Priya $20 each.
    // Alberto: paid 1236, owes 247.20 + 75 + 20 + 20 = 362.20 -> +873.80
    // Maria:   paid 375,  owes 247.20 + 75 + 20 = 342.20 -> +32.80
    // Jordan:  paid 100,  owes 494.40 + 150 + 40 + 20 = 704.40 -> -604.40
    // Priya:   paid 60,   owes 247.20 + 75 + 20 + 20 = 362.20 -> -302.20
    func testNashvilleSampleByHand() {
        let data = SampleData.make()
        let trip = data.trips.first { $0.name == "Nashville Long Weekend" }!
        let byName = Dictionary(uniqueKeysWithValues: Ledger.balances(for: trip).map { (data.person($0.personID)!.firstName, $0.net) })
        XCTAssertEqual(byName, ["Alberto": 87380, "Maria": 3280, "Jordan": -60440, "Priya": -30220])
        let transfers = Ledger.suggestedRepayments(for: trip).map { (data.person($0.fromID)!.firstName, data.person($0.toID)!.firstName, $0.amountMinor) }
        // Jordan pays Alberto 604.40; Priya pays Alberto 269.40 and Maria 32.80.
        XCTAssertEqual(transfers.count, 3)
        XCTAssertEqual(transfers[0].0, "Jordan"); XCTAssertEqual(transfers[0].1, "Alberto"); XCTAssertEqual(transfers[0].2, 60440)
        XCTAssertEqual(transfers[1].0, "Priya"); XCTAssertEqual(transfers[1].1, "Alberto"); XCTAssertEqual(transfers[1].2, 26940)
        XCTAssertEqual(transfers[2].0, "Priya"); XCTAssertEqual(transfers[2].1, "Maria"); XCTAssertEqual(transfers[2].2, 3280)
    }
}
