import Foundation

/// Someone with the app. People join on their own, then invite each other
/// into groups.
struct Person: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    /// Picks the colour of their avatar.
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// A circle of people who travel together, like "Weekend Crew".
struct TravelGroup: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var memberIDs: [UUID]
    /// People invited who haven't joined yet (by name, until accounts exist).
    var pendingInvites: [String]

    init(id: UUID = UUID(), name: String, memberIDs: [UUID], pendingInvites: [String] = []) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.pendingInvites = pendingInvites
    }
}

/// An answer to a trip proposal.
enum Response: String, Codable, CaseIterable, Hashable {
    case interested
    case maybe
    case cantMakeIt

    var title: String {
        switch self {
        case .interested: return "Interested"
        case .maybe: return "Maybe"
        case .cantMakeIt: return "Can't make it"
        }
    }

    var symbol: String {
        switch self {
        case .interested: return "hand.thumbsup.fill"
        case .maybe: return "questionmark.circle.fill"
        case .cantMakeIt: return "xmark.circle.fill"
        }
    }
}

/// One person on a trip. `partySize` is 2 when one person signs up for
/// themselves and a partner who doesn't use the app ("for 2"): their share
/// of every equal split and every estimate counts double.
struct TripMember: Hashable, Codable {
    var personID: UUID
    var partySize: Int
    var response: Response?

    init(personID: UUID, partySize: Int = 1, response: Response? = nil) {
        self.personID = personID
        self.partySize = max(1, partySize)
        self.response = response
    }

    var isComing: Bool { response != .cantMakeIt }
}

enum TripStage: String, Codable, Hashable {
    /// Still an idea: people answer Interested, Maybe or Can't make it.
    case proposal
    /// Happening: plan, expenses and balances.
    case trip
}

/// Who can put up a poll.
enum PollPolicy: String, Codable, CaseIterable, Hashable {
    case everyone
    case selected
    case approval

    var title: String {
        switch self {
        case .everyone: return "Everyone"
        case .selected: return "Only people I pick"
        case .approval: return "Ask me first"
        }
    }

    var detail: String {
        switch self {
        case .everyone: return "Anyone on the trip can post a poll."
        case .selected: return "Only the organizer and the people picked below can post polls."
        case .approval: return "Anyone can suggest a poll; it shows once the organizer approves it."
        }
    }
}

enum PlaceKind: String, Codable, CaseIterable, Hashable {
    case stay, food, activity, flight, transport, other

    var title: String {
        switch self {
        case .stay: return "Stay"
        case .food: return "Food"
        case .activity: return "Activity"
        case .flight: return "Flight"
        case .transport: return "Getting around"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .stay: return "bed.double.fill"
        case .food: return "fork.knife"
        case .activity: return "ticket.fill"
        case .flight: return "airplane"
        case .transport: return "car.fill"
        case .other: return "mappin"
        }
    }

    /// The budget category this kind of place usually counts toward.
    var costKind: CostKind {
        switch self {
        case .stay: return .stay
        case .food: return .food
        case .activity: return .activities
        case .flight: return .flights
        case .transport: return .transport
        case .other: return .other
        }
    }
}

/// A place on the map, confirmed by a person (never guessed from text alone).
struct Place: Hashable, Codable {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
}

/// Something in the plan: a stay, a dinner, an activity, a flight.
struct PlanItem: Identifiable, Hashable, Codable {
    var id: UUID
    var kind: PlaceKind
    var title: String
    /// The day it happens, if decided.
    var date: Date?
    /// Whether `date` carries a time of day worth showing.
    var hasTime: Bool
    /// Estimated price in the trip currency.
    var priceMinor: Int64?
    /// What the price covers, e.g. "per night" or "per person".
    var priceNote: String
    var notes: String
    /// Listing links people pasted (Airbnb, Expedia, a restaurant page...).
    var links: [String]
    var place: Place?
    var addedBy: UUID?

    init(id: UUID = UUID(), kind: PlaceKind, title: String, date: Date? = nil, hasTime: Bool = false,
         priceMinor: Int64? = nil, priceNote: String = "", notes: String = "", links: [String] = [],
         place: Place? = nil, addedBy: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.hasTime = hasTime
        self.priceMinor = priceMinor
        self.priceNote = priceNote
        self.notes = notes
        self.links = links
        self.place = place
        self.addedBy = addedBy
    }
}

struct PollOption: Identifiable, Hashable, Codable {
    var id: UUID
    var text: String
    var voterIDs: [UUID]

    init(id: UUID = UUID(), text: String, voterIDs: [UUID] = []) {
        self.id = id
        self.text = text
        self.voterIDs = voterIDs
    }
}

struct Poll: Identifiable, Hashable, Codable {
    enum Status: String, Codable, Hashable {
        case published
        /// Waiting for the organizer to approve it.
        case pending
    }

    var id: UUID
    var question: String
    var options: [PollOption]
    var createdBy: UUID
    var status: Status
    /// The plan item or time slot it's about, if any.
    var itemID: UUID?
    var slot: Date?
    var allowsMultiple: Bool
    var isClosed: Bool

    init(id: UUID = UUID(), question: String, options: [PollOption], createdBy: UUID,
         status: Status = .published, itemID: UUID? = nil, slot: Date? = nil,
         allowsMultiple: Bool = false, isClosed: Bool = false) {
        self.id = id
        self.question = question
        self.options = options
        self.createdBy = createdBy
        self.status = status
        self.itemID = itemID
        self.slot = slot
        self.allowsMultiple = allowsMultiple
        self.isClosed = isClosed
    }

    var totalVotes: Int { options.reduce(0) { $0 + $1.voterIDs.count } }

    /// The option(s) with the most votes, once anyone has voted.
    var leaders: [UUID] {
        let top = options.map(\.voterIDs.count).max() ?? 0
        guard top > 0 else { return [] }
        return options.filter { $0.voterIDs.count == top }.map(\.id)
    }
}

/// A repayment someone marked as made, outside the app.
struct Payment: Identifiable, Hashable, Codable {
    var id: UUID
    var fromID: UUID
    var toID: UUID
    /// In the trip currency.
    var amountMinor: Int64
    var date: Date

    init(id: UUID = UUID(), fromID: UUID, toID: UUID, amountMinor: Int64, date: Date) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.amountMinor = amountMinor
        self.date = date
    }
}

struct Trip: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    /// The currency balances are kept in.
    var currency: String
    var organizerID: UUID
    var groupID: UUID?
    var stage: TripStage
    var note: String
    var members: [TripMember]
    var categories: [BudgetCategory]
    var items: [PlanItem]
    var polls: [Poll]
    var pollPolicy: PollPolicy
    /// Who may post polls when the policy is `.selected`.
    var pollPublisherIDs: [UUID]
    var expenses: [Expense]
    var payments: [Payment]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, destination: String, startDate: Date, endDate: Date,
         currency: String = "USD", organizerID: UUID, groupID: UUID? = nil, stage: TripStage = .proposal,
         note: String = "", members: [TripMember] = [], categories: [BudgetCategory] = [],
         items: [PlanItem] = [], polls: [Poll] = [], pollPolicy: PollPolicy = .everyone,
         pollPublisherIDs: [UUID] = [], expenses: [Expense] = [], payments: [Payment] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.currency = currency
        self.organizerID = organizerID
        self.groupID = groupID
        self.stage = stage
        self.note = note
        self.members = members
        self.categories = categories
        self.items = items
        self.polls = polls
        self.pollPolicy = pollPolicy
        self.pollPublisherIDs = pollPublisherIDs
        self.expenses = expenses
        self.payments = payments
        self.createdAt = createdAt
    }

    func member(_ personID: UUID) -> TripMember? {
        members.first { $0.personID == personID }
    }

    func partySize(of personID: UUID) -> Int {
        member(personID)?.partySize ?? 1
    }

    /// Everyone who hasn't said they can't make it, counted with their party.
    var expectedTravelers: Int {
        members.filter(\.isComing).reduce(0) { $0 + $1.partySize }
    }

    var comingMemberIDs: [UUID] {
        members.filter(\.isComing).map(\.personID)
    }

    /// Calendar days the trip covers, counting both ends (Fri to Sun is 3).
    var days: Int { TripDates.days(from: startDate, to: endDate) }
    var nights: Int { max(0, days - 1) }

    enum Phase: Hashable { case idea, upcoming, now, past }

    func phase(today: Date, calendar: Calendar = .current) -> Phase {
        if stage == .proposal { return .idea }
        let day = calendar.startOfDay(for: today)
        if calendar.startOfDay(for: endDate) < day { return .past }
        if calendar.startOfDay(for: startDate) <= day { return .now }
        return .upcoming
    }

    func canPublishPolls(_ personID: UUID) -> PollPermission {
        PollPermission.for(personID: personID, organizerID: organizerID, policy: pollPolicy, publishers: pollPublisherIDs)
    }

    var publishedPolls: [Poll] { polls.filter { $0.status == .published } }
    var pendingPolls: [Poll] { polls.filter { $0.status == .pending } }
}

/// What a person may do about polls on a trip.
enum PollPermission: Hashable {
    /// Post it straight away.
    case publish
    /// Suggest it; the organizer approves.
    case request
    /// Not allowed under the organizer's setting.
    case none

    static func `for`(personID: UUID, organizerID: UUID, policy: PollPolicy, publishers: [UUID]) -> PollPermission {
        if personID == organizerID { return .publish }
        switch policy {
        case .everyone: return .publish
        case .selected: return publishers.contains(personID) ? .publish : .none
        case .approval: return .request
        }
    }
}

enum TripDates {
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: end)
        let difference = calendar.dateComponents([.day], from: a, to: b).day ?? 0
        return max(1, difference + 1)
    }
}

/// Everything the app keeps on the phone.
struct AppData: Codable, Hashable {
    var version: Int = 1
    var currentUserID: UUID
    var people: [Person]
    var groups: [TravelGroup]
    var trips: [Trip]

    func person(_ id: UUID) -> Person? { people.first { $0.id == id } }
}
