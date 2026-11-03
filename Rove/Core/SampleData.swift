import Foundation

/// Made-up people and trips so every screen can be tried before there's a
/// server: an idea people are answering, a trip being planned with
/// expenses, and a finished trip that's settled up. Dates are relative to
/// `today`, so the sample always looks current.
enum SampleData {
    static func make(today: Date = Date(), calendar: Calendar = .current) -> AppData {
        let base = calendar.startOfDay(for: today)
        func day(_ offset: Int, hour: Int = 12, minute: Int = 0) -> Date {
            let d = calendar.date(byAdding: .day, value: offset, to: base) ?? base
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) ?? d
        }
        func usd(_ dollars: Int64, _ cents: Int64 = 0) -> Int64 { dollars * 100 + cents }

        let me = Person(name: "Alberto Aday", colorIndex: 0)
        let maria = Person(name: "Maria Lopez", colorIndex: 1)
        let jordan = Person(name: "Jordan Reyes", colorIndex: 2)
        let priya = Person(name: "Priya Shah", colorIndex: 3)
        let sam = Person(name: "Sam Carter", colorIndex: 4)
        let lena = Person(name: "Lena Park", colorIndex: 5)
        let people = [me, maria, jordan, priya, sam, lena]

        let crew = TravelGroup(name: "Weekend Crew", memberIDs: people.map(\.id), pendingInvites: ["Chris"])
        let orlandoCrew = TravelGroup(name: "Theme Park Squad", memberIDs: [me.id, sam.id, lena.id])

        // MARK: Nashville: a trip being planned, with expenses already in.
        let nashStart = 17
        let gulch = Place(name: "Airbnb in The Gulch", address: "600 12th Ave S, Nashville, TN", latitude: 36.1520, longitude: -86.7840)
        let stay = PlanItem(kind: .stay, title: "Loft in The Gulch", date: day(nashStart, hour: 16), hasTime: true,
                            priceMinor: usd(309), priceNote: "a night, whole place",
                            notes: "3 bedrooms, rooftop. Check-in after 4 PM.",
                            links: ["https://www.airbnb.com/rooms/53512345"], place: gulch, addedBy: me.id)
        let flight = PlanItem(kind: .flight, title: "Land at BNA", date: day(nashStart, hour: 10, minute: 40), hasTime: true,
                              priceMinor: usd(212), priceNote: "per person, round trip",
                              notes: "Southwest 1423 from FLL.",
                              links: ["https://www.southwest.com"],
                              place: Place(name: "Nashville International Airport", address: "1 Terminal Dr, Nashville, TN", latitude: 36.1263, longitude: -86.6774),
                              addedBy: maria.id)
        let hattie = PlanItem(kind: .food, title: "Hattie B's Hot Chicken", date: day(nashStart, hour: 19), hasTime: true,
                              priceMinor: usd(25), priceNote: "per person",
                              links: ["https://www.yelp.com/biz/hattie-bs-hot-chicken-nashville"],
                              place: Place(name: "Hattie B's Hot Chicken", address: "112 19th Ave S, Nashville, TN", latitude: 36.1511, longitude: -86.7966),
                              addedBy: jordan.id)
        let ryman = PlanItem(kind: .activity, title: "Ryman Auditorium tour", date: day(nashStart + 1, hour: 11), hasTime: true,
                             priceMinor: usd(35), priceNote: "per person",
                             links: ["https://www.ryman.com/tours"],
                             place: Place(name: "Ryman Auditorium", address: "116 Rep. John Lewis Way N, Nashville, TN", latitude: 36.1612, longitude: -86.7785),
                             addedBy: priya.id)
        let broadway = PlanItem(kind: .activity, title: "Honky-tonks on Broadway", date: day(nashStart + 1, hour: 21), hasTime: true,
                                notes: "No cover at most bars.",
                                place: Place(name: "Lower Broadway", address: "Broadway, Nashville, TN", latitude: 36.1610, longitude: -86.7760),
                                addedBy: me.id)
        let opry = PlanItem(kind: .activity, title: "Grand Ole Opry", date: day(nashStart + 2, hour: 19), hasTime: true,
                            priceMinor: usd(75), priceNote: "per person",
                            links: ["https://www.ticketmaster.com/grand-ole-opry-tickets/artist/1"],
                            place: Place(name: "Grand Ole Opry", address: "600 Opry Mills Dr, Nashville, TN", latitude: 36.2069, longitude: -86.6921),
                            addedBy: maria.id)
        let brunch = PlanItem(kind: .food, title: "Brunch at Pancake Pantry", date: day(nashStart + 3, hour: 9, minute: 30), hasTime: true,
                              priceMinor: usd(20), priceNote: "per person",
                              place: Place(name: "Pancake Pantry", address: "1796 21st Ave S, Nashville, TN", latitude: 36.1360, longitude: -86.8000),
                              addedBy: priya.id)
        let rental = PlanItem(kind: .transport, title: "Rental SUV", priceMinor: usd(260), priceNote: "for the trip",
                              notes: "Pick up at BNA, 7 seats.", links: ["https://www.hertz.com"], addedBy: jordan.id)

        var nashville = Trip(name: "Nashville Long Weekend", destination: "Nashville, Tennessee",
                             startDate: day(nashStart), endDate: day(nashStart + 3), currency: "USD",
                             organizerID: me.id, groupID: crew.id, stage: .trip,
                             note: "Music, hot chicken and the Opry.",
                             members: [
                                TripMember(personID: me.id, partySize: 1, response: .interested),
                                TripMember(personID: maria.id, partySize: 1, response: .interested),
                                TripMember(personID: jordan.id, partySize: 2, response: .interested),
                                TripMember(personID: priya.id, partySize: 1, response: .interested),
                             ],
                             categories: [
                                BudgetCategory(kind: .stay, name: "Loft", basis: .sharedPerNight, amountMinor: usd(309)),
                                BudgetCategory(kind: .flights, name: "Flights", basis: .perPerson, amountMinor: usd(212)),
                                BudgetCategory(kind: .food, name: "Food", basis: .perMeal, amountMinor: usd(30), mealsPerDay: 3),
                                BudgetCategory(kind: .activities, name: "Shows and tours", basis: .perPerson, amountMinor: usd(110)),
                                BudgetCategory(kind: .transport, name: "Rental SUV", basis: .sharedTotal, amountMinor: usd(260)),
                             ],
                             items: [stay, flight, hattie, ryman, broadway, opry, brunch, rental],
                             pollPolicy: .approval,
                             createdAt: day(-20))
        let dinnerPoll = Poll(question: "Saturday dinner?", options: [
            PollOption(text: "Martin's Bar-B-Que", voterIDs: [me.id, jordan.id]),
            PollOption(text: "Husk", voterIDs: [maria.id]),
            PollOption(text: "Prince's Hot Chicken", voterIDs: []),
        ], createdBy: maria.id, slot: day(nashStart + 2, hour: 18))
        let bootsPoll = Poll(question: "Boot shopping Sunday morning?", options: [
            PollOption(text: "Yes, before brunch"),
            PollOption(text: "Skip it"),
        ], createdBy: priya.id, status: .pending, itemID: brunch.id)
        nashville.polls = [dinnerPoll, bootsPoll]
        let everyone = nashville.members.map(\.personID)
        nashville.expenses = [
            Expense(title: "Loft in The Gulch", date: day(-12), kind: .stay, payerID: me.id,
                    amount: Money(usd(1236), "USD"), tripCurrency: "USD",
                    shares: Ledger.equalShares(everyone, on: nashville), notes: "4 nights with fees.", place: gulch),
            Expense(title: "Grand Ole Opry tickets", date: day(-9), kind: .activities, payerID: maria.id,
                    amount: Money(usd(375), "USD"), tripCurrency: "USD",
                    shares: Ledger.equalShares(everyone, on: nashville)),
            Expense(title: "Rental SUV deposit", date: day(-5), kind: .transport, payerID: jordan.id,
                    amount: Money(usd(100), "USD"), tripCurrency: "USD",
                    shares: Ledger.equalShares(everyone, on: nashville)),
            Expense(title: "Birthday cake for Maria", date: day(-2), kind: .food, payerID: priya.id,
                    amount: Money(usd(60), "USD"), tripCurrency: "USD", splitMode: .custom,
                    shares: [Share(personID: me.id, weight: usd(20)), Share(personID: jordan.id, weight: usd(20)), Share(personID: priya.id, weight: usd(20))],
                    notes: "Surprise, Maria isn't in this one."),
        ]

        // MARK: Cancún: an idea people are still answering.
        var cancun = Trip(name: "Cancún Spring Break", destination: "Cancún, Mexico",
                          startDate: day(130), endDate: day(134), currency: "USD",
                          organizerID: maria.id, groupID: crew.id, stage: .proposal,
                          note: "Beach house in the Hotel Zone, cenotes, a day in Tulum.",
                          members: [
                            TripMember(personID: maria.id, partySize: 1, response: .interested),
                            TripMember(personID: me.id, partySize: 1, response: nil),
                            TripMember(personID: jordan.id, partySize: 2, response: .interested),
                            TripMember(personID: priya.id, partySize: 1, response: .maybe),
                            TripMember(personID: sam.id, partySize: 1, response: .cantMakeIt),
                            TripMember(personID: lena.id, partySize: 1, response: .interested),
                          ],
                          categories: [
                            BudgetCategory(kind: .stay, name: "Beach house", basis: .sharedPerNight, amountMinor: usd(420)),
                            BudgetCategory(kind: .flights, name: "Flights", basis: .perPerson, amountMinor: usd(380)),
                            BudgetCategory(kind: .food, name: "Food", basis: .perMeal, amountMinor: usd(35), mealsPerDay: 3),
                            BudgetCategory(kind: .activities, name: "Cenotes and Tulum", basis: .perPerson, amountMinor: usd(180)),
                            BudgetCategory(kind: .transport, name: "Van from the airport", basis: .sharedTotal, amountMinor: usd(240)),
                          ],
                          createdAt: day(-3))
        cancun.items = [
            PlanItem(kind: .stay, title: "Casa Turquesa beach house", priceMinor: usd(420), priceNote: "a night",
                     links: ["https://www.vrbo.com/1234567"],
                     place: Place(name: "Hotel Zone", address: "Blvd. Kukulcan, Cancún", latitude: 21.1290, longitude: -86.7480),
                     addedBy: maria.id),
        ]

        // MARK: Keys: a smaller idea.
        let keys = Trip(name: "Keys Road Trip", destination: "Key West, Florida",
                        startDate: day(45), endDate: day(47), currency: "USD",
                        organizerID: jordan.id, groupID: crew.id, stage: .proposal,
                        note: "Drive down Saturday morning, sunset at Mallory Square.",
                        members: [
                            TripMember(personID: jordan.id, partySize: 2, response: .interested),
                            TripMember(personID: me.id, partySize: 1, response: .interested),
                            TripMember(personID: maria.id, partySize: 1, response: .maybe),
                        ],
                        categories: [
                            BudgetCategory(kind: .stay, name: "Guesthouse", basis: .sharedPerNight, amountMinor: usd(260)),
                            BudgetCategory(kind: .food, name: "Food", basis: .perMeal, amountMinor: usd(30), mealsPerDay: 3),
                            BudgetCategory(kind: .transport, name: "Gas and tolls", basis: .sharedTotal, amountMinor: usd(120)),
                        ],
                        createdAt: day(-1))

        // MARK: Orlando: done and settled.
        var orlando = Trip(name: "Orlando Parks", destination: "Orlando, Florida",
                           startDate: day(-60), endDate: day(-57), currency: "USD",
                           organizerID: sam.id, groupID: orlandoCrew.id, stage: .trip,
                           members: [
                            TripMember(personID: sam.id, partySize: 1, response: .interested),
                            TripMember(personID: me.id, partySize: 1, response: .interested),
                            TripMember(personID: lena.id, partySize: 1, response: .interested),
                           ],
                           categories: [
                            BudgetCategory(kind: .stay, name: "Hotel", basis: .sharedPerNight, amountMinor: usd(210)),
                            BudgetCategory(kind: .activities, name: "Park tickets", basis: .perPerson, amountMinor: usd(170)),
                            BudgetCategory(kind: .food, name: "Food", basis: .perMeal, amountMinor: usd(25), mealsPerDay: 3),
                           ],
                           createdAt: day(-90))
        let orlandoAll = orlando.members.map(\.personID)
        orlando.expenses = [
            Expense(title: "Hotel, 3 nights", date: day(-60), kind: .stay, payerID: sam.id, amount: Money(usd(640), "USD"),
                    tripCurrency: "USD", shares: Ledger.equalShares(orlandoAll, on: orlando)),
            Expense(title: "Park tickets", date: day(-59), kind: .activities, payerID: me.id, amount: Money(usd(510), "USD"),
                    tripCurrency: "USD", shares: Ledger.equalShares(orlandoAll, on: orlando)),
            Expense(title: "Dinner at Disney Springs", date: day(-58), kind: .food, payerID: lena.id, amount: Money(usd(96, 75), "USD"),
                    subtotalMinor: usd(78, 50), taxMinor: usd(5, 10), tipMinor: usd(13, 15),
                    tripCurrency: "USD", shares: Ledger.equalShares(orlandoAll, on: orlando)),
        ]
        orlando.payments = Ledger.suggestedRepayments(for: orlando).map {
            Payment(fromID: $0.fromID, toID: $0.toID, amountMinor: $0.amountMinor, date: day(-50))
        }

        return AppData(currentUserID: me.id, people: people, groups: [crew, orlandoCrew],
                       trips: [nashville, cancun, keys, orlando])
    }
}
