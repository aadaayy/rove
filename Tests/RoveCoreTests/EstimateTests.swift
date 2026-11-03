import XCTest
@testable import RoveCore

final class EstimateTests: XCTestCase {
    // $50 per meal, 3 meals, 4 days = $600 a person; a party of 2 = $1,200.
    // Estimates show whole dollars: $1,359.29 reads $1,359 and $185.50 rounds up.
    func testRoundedMoney() {
        XCTAssertEqual(Money(135_929, "USD").rounded, "$1,359")
        XCTAssertEqual(Money(18_550, "USD").rounded, "$186")
        XCTAssertEqual(Money(41_200, "USD").rounded, "$412")
    }

    func testPerMeal() {
        let food = BudgetCategory(kind: .food, basis: .perMeal, amountMinor: 5000, mealsPerDay: 3)
        let e = Estimator.estimate(categories: [food], days: 4, nights: 3, travelers: 6, currency: "USD")
        XCTAssertEqual(e.perPerson, 60000)
        XCTAssertEqual(e.perParty(2), 120000)
        XCTAssertEqual(e.lines[0].assumption, "$50 per meal × 3 meals × 4 days")
    }

    // $300 a night, 3 nights, shared by 6 = $150 each.
    func testSharedPerNight() {
        let stay = BudgetCategory(kind: .stay, basis: .sharedPerNight, amountMinor: 30000)
        let e = Estimator.estimate(categories: [stay], days: 4, nights: 3, travelers: 6, currency: "USD")
        XCTAssertEqual(e.perPerson, 15000)
        XCTAssertEqual(e.lines[0].assumption, "$300 a night × 3 nights ÷ 6 travelers")
    }

    // $200 shared by 3 = $66.67 each (rounded to the nearest cent).
    func testSharedTotalRounds() {
        let car = BudgetCategory(kind: .transport, basis: .sharedTotal, amountMinor: 20000)
        let e = Estimator.estimate(categories: [car], days: 2, nights: 1, travelers: 3, currency: "USD")
        XCTAssertEqual(e.perPerson, 6667)
    }

    func testAllBasesTogether() {
        let cats = [
            BudgetCategory(kind: .flights, basis: .perPerson, amountMinor: 35000),       // 350
            BudgetCategory(kind: .other, basis: .perPersonPerDay, amountMinor: 2000),    // 20 x 4 = 80
            BudgetCategory(kind: .food, basis: .perMeal, amountMinor: 2500, mealsPerDay: 2), // 25 x 2 x 4 = 200
            BudgetCategory(kind: .transport, basis: .sharedTotal, amountMinor: 40000),   // 400 / 5 = 80
            BudgetCategory(kind: .stay, basis: .sharedPerNight, amountMinor: 25000),     // 250 x 3 / 5 = 150
        ]
        let e = Estimator.estimate(categories: cats, days: 4, nights: 3, travelers: 5, currency: "USD")
        XCTAssertEqual(e.perPerson, 86000)
        XCTAssertEqual(e.groupTotal, 430000)
    }

    // Travelers count everyone who hasn't said no, with parties of 2.
    func testTravelersCountParties() {
        let ids = (0..<5).map { _ in UUID() }
        let trip = Trip(name: "t", destination: "d", startDate: Date(), endDate: Date(), organizerID: ids[0], members: [
            TripMember(personID: ids[0], partySize: 1, response: .interested),
            TripMember(personID: ids[1], partySize: 2, response: .interested),
            TripMember(personID: ids[2], partySize: 1, response: .maybe),
            TripMember(personID: ids[3], partySize: 1, response: nil),
            TripMember(personID: ids[4], partySize: 1, response: .cantMakeIt),
        ])
        XCTAssertEqual(trip.expectedTravelers, 5)
    }

    func testDaysCountBothEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 9))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 22))!
        XCTAssertEqual(TripDates.days(from: friday, to: sunday, calendar: calendar), 3)
        XCTAssertEqual(TripDates.days(from: friday, to: friday, calendar: calendar), 1)
    }

    func testCancunSampleEstimate() {
        // Travelers: Maria 1, Alberto (no answer yet) 1, Jordan 2, Priya 1, Lena 1 = 6 (Sam can't).
        // 5 days, 4 nights. House 420 x 4 / 6 = 280. Flights 380. Food 35 x 3 x 5 = 525.
        // Activities 180. Van 240 / 6 = 40. Total 1,405 a person.
        let trip = SampleData.make().trips.first { $0.name == "Cancún Spring Break" }!
        XCTAssertEqual(trip.expectedTravelers, 6)
        XCTAssertEqual(Estimator.estimate(for: trip).perPerson, 140500)
    }
}
