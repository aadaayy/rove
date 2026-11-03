import Foundation

/// What a cost is for. Used by budget lines and by expenses, so the plan's
/// estimate can be compared with what was really spent.
enum CostKind: String, Codable, CaseIterable, Hashable {
    case stay, flights, food, activities, transport, other

    var title: String {
        switch self {
        case .stay: return "Stay"
        case .flights: return "Flights"
        case .food: return "Food"
        case .activities: return "Activities"
        case .transport: return "Getting around"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .stay: return "bed.double.fill"
        case .flights: return "airplane"
        case .food: return "fork.knife"
        case .activities: return "ticket.fill"
        case .transport: return "car.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

/// How a budget line's amount turns into a cost for each traveler.
enum CostBasis: String, Codable, CaseIterable, Hashable {
    /// Each traveler pays this once (a flight, a ticket).
    case perPerson
    /// Each traveler, every day of the trip.
    case perPersonPerDay
    /// Each traveler, per meal, a number of meals a day (e.g. $50 per meal).
    case perMeal
    /// One total shared by everyone going (a rental car for the trip).
    case sharedTotal
    /// A nightly price shared by everyone going (a house).
    case sharedPerNight

    var title: String {
        switch self {
        case .perPerson: return "Per person"
        case .perPersonPerDay: return "Per person, per day"
        case .perMeal: return "Per meal"
        case .sharedTotal: return "Shared total"
        case .sharedPerNight: return "Shared, per night"
        }
    }
}

struct BudgetCategory: Identifiable, Hashable, Codable {
    var id: UUID
    var kind: CostKind
    var name: String
    var basis: CostBasis
    /// The amount in the trip currency, read according to `basis`.
    var amountMinor: Int64
    /// Meals a day, for `.perMeal`.
    var mealsPerDay: Int

    init(id: UUID = UUID(), kind: CostKind, name: String? = nil, basis: CostBasis, amountMinor: Int64, mealsPerDay: Int = 3) {
        self.id = id
        self.kind = kind
        self.name = name ?? kind.title
        self.basis = basis
        self.amountMinor = amountMinor
        self.mealsPerDay = max(1, mealsPerDay)
    }
}

/// The likely cost of a trip, before anyone has spent anything.
struct TripEstimate: Hashable {
    struct Line: Hashable, Identifiable {
        let id: UUID
        let kind: CostKind
        let name: String
        /// One traveler's share.
        let perPerson: Int64
        /// "$50 per meal × 3 meals × 4 days".
        let assumption: String
    }

    let currency: String
    let travelers: Int
    let lines: [Line]

    var perPerson: Int64 { lines.reduce(0) { $0 + $1.perPerson } }

    /// For someone signed up for `partySize` people.
    func perParty(_ partySize: Int) -> Int64 { perPerson * Int64(max(1, partySize)) }

    /// Everyone together.
    var groupTotal: Int64 { perPerson * Int64(travelers) }
}

enum Estimator {
    /// Estimate for `travelers` people over `days` days and `nights` nights.
    /// Shared costs are divided evenly, rounded to the nearest cent.
    static func estimate(categories: [BudgetCategory], days: Int, nights: Int, travelers: Int, currency: String) -> TripEstimate {
        let people = max(1, travelers)
        let lines = categories.map { category -> TripEstimate.Line in
            let amount = Money(category.amountMinor, currency).formatted(wholeIfRound: true)
            let perPerson: Int64
            let assumption: String
            switch category.basis {
            case .perPerson:
                perPerson = category.amountMinor
                assumption = "\(amount) per person"
            case .perPersonPerDay:
                perPerson = category.amountMinor * Int64(days)
                assumption = "\(amount) a day × \(plural(days, "day"))"
            case .perMeal:
                perPerson = category.amountMinor * Int64(category.mealsPerDay) * Int64(days)
                assumption = "\(amount) per meal × \(plural(category.mealsPerDay, "meal")) × \(plural(days, "day"))"
            case .sharedTotal:
                perPerson = divideRounded(category.amountMinor, by: Int64(people))
                assumption = "\(amount) total ÷ \(plural(people, "traveler"))"
            case .sharedPerNight:
                let total = category.amountMinor * Int64(max(1, nights))
                perPerson = divideRounded(total, by: Int64(people))
                assumption = "\(amount) a night × \(plural(max(1, nights), "night")) ÷ \(plural(people, "traveler"))"
            }
            return TripEstimate.Line(id: category.id, kind: category.kind, name: category.name, perPerson: perPerson, assumption: assumption)
        }
        return TripEstimate(currency: currency, travelers: people, lines: lines)
    }

    static func estimate(for trip: Trip) -> TripEstimate {
        estimate(categories: trip.categories, days: trip.days, nights: trip.nights,
                 travelers: trip.expectedTravelers, currency: trip.currency)
    }

    /// Rounded half up, for positive amounts.
    static func divideRounded(_ value: Int64, by divisor: Int64) -> Int64 {
        guard divisor > 0 else { return value }
        return (value + divisor / 2) / divisor
    }

    static func plural(_ count: Int, _ word: String) -> String {
        "\(count) \(word)\(count == 1 ? "" : "s")"
    }

    /// Starting budget lines for a new proposal.
    static func defaultCategories(currency: String) -> [BudgetCategory] {
        let unit = Currencies.scale(currency)
        return [
            BudgetCategory(kind: .stay, name: "Stay", basis: .sharedPerNight, amountMinor: 300 * unit),
            BudgetCategory(kind: .flights, name: "Flights", basis: .perPerson, amountMinor: 350 * unit),
            BudgetCategory(kind: .food, name: "Food", basis: .perMeal, amountMinor: 50 * unit, mealsPerDay: 3),
            BudgetCategory(kind: .activities, name: "Activities", basis: .perPerson, amountMinor: 150 * unit),
            BudgetCategory(kind: .transport, name: "Getting around", basis: .sharedTotal, amountMinor: 200 * unit),
        ]
    }
}
