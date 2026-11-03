import Foundation
import Observation

/// Where the app's data lives. Today it's a file on the phone; later a
/// Supabase-backed version can take its place without the screens changing.
protocol TripRepository {
    func load() -> AppData?
    func save(_ data: AppData)
}

/// Keeps everything in one JSON file in the app's private folder.
struct LocalFileRepository: TripRepository {
    var url: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("rove-data.json")
    }()

    func load() -> AppData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.rove.decode(AppData.self, from: data)
    }

    func save(_ data: AppData) {
        guard let encoded = try? JSONEncoder.rove.encode(data) else { return }
        try? encoded.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

/// For the automatic checks: starts from the sample every time, saves nothing.
struct InMemoryRepository: TripRepository {
    func load() -> AppData? { nil }
    func save(_ data: AppData) {}
}

extension JSONEncoder {
    static var rove: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var rove: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// The app's data and every change people can make to it.
@MainActor
@Observable
final class TripStore {
    private(set) var data: AppData
    private let repository: TripRepository

    init(repository: TripRepository, sample: () -> AppData = { SampleData.make() }) {
        self.repository = repository
        if let saved = repository.load() {
            data = saved
        } else {
            data = sample()
            repository.save(data)
        }
    }

    static func make(options: LaunchOptions) -> TripStore {
        if options.inMemory { return TripStore(repository: InMemoryRepository()) }
        return TripStore(repository: LocalFileRepository())
    }

    private func commit(_ change: (inout AppData) -> Void) {
        change(&data)
        repository.save(data)
    }

    // MARK: People

    var me: Person { data.person(data.currentUserID) ?? data.people[0] }
    var people: [Person] { data.people }
    var groups: [TravelGroup] { data.groups }

    func person(_ id: UUID) -> Person {
        data.person(id) ?? Person(id: id, name: "Someone", colorIndex: 7)
    }

    func name(_ id: UUID) -> String {
        id == data.currentUserID ? "You" : person(id).firstName
    }

    /// For trying the app as someone else before accounts exist.
    func actAs(_ id: UUID) {
        commit { $0.currentUserID = id }
    }

    func resetToSample() {
        let current = data.people.first { $0.id == data.currentUserID }?.name
        var fresh = SampleData.make()
        if let current, let match = fresh.people.first(where: { $0.name == current }) {
            fresh.currentUserID = match.id
        }
        commit { $0 = fresh }
    }

    func renameMe(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        commit { data in
            if let index = data.people.firstIndex(where: { $0.id == data.currentUserID }) {
                data.people[index].name = trimmed
            }
        }
    }

    // MARK: Groups

    func createGroup(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        commit { $0.groups.append(TravelGroup(name: trimmed, memberIDs: [$0.currentUserID])) }
    }

    /// Until accounts exist, an invite adds a stand-in person straight away
    /// so they can be put on trips.
    func invite(_ name: String, to groupID: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        commit { data in
            guard let g = data.groups.firstIndex(where: { $0.id == groupID }) else { return }
            let person: Person
            if let existing = data.people.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                person = existing
            } else {
                person = Person(name: trimmed, colorIndex: data.people.count)
                data.people.append(person)
            }
            if !data.groups[g].memberIDs.contains(person.id) { data.groups[g].memberIDs.append(person.id) }
            data.groups[g].pendingInvites.removeAll { $0.lowercased() == trimmed.lowercased() }
        }
    }

    func removeFromGroup(_ personID: UUID, groupID: UUID) {
        commit { data in
            guard let g = data.groups.firstIndex(where: { $0.id == groupID }) else { return }
            data.groups[g].memberIDs.removeAll { $0 == personID }
        }
    }

    // MARK: Trips

    var trips: [Trip] { data.trips }

    func trip(_ id: UUID) -> Trip? { data.trips.first { $0.id == id } }

    func update(_ tripID: UUID, _ change: (inout Trip) -> Void) {
        commit { data in
            guard let index = data.trips.firstIndex(where: { $0.id == tripID }) else { return }
            change(&data.trips[index])
        }
    }

    @discardableResult
    func createProposal(_ trip: Trip) -> UUID {
        commit { $0.trips.insert(trip, at: 0) }
        return trip.id
    }

    func deleteTrip(_ id: UUID) {
        commit { $0.trips.removeAll { $0.id == id } }
    }

    func respond(_ tripID: UUID, response: Response) {
        let me = data.currentUserID
        update(tripID) { trip in
            if let index = trip.members.firstIndex(where: { $0.personID == me }) {
                trip.members[index].response = response
            } else {
                trip.members.append(TripMember(personID: me, partySize: 1, response: response))
            }
        }
    }

    func setPartySize(_ tripID: UUID, personID: UUID, size: Int) {
        update(tripID) { trip in
            if let index = trip.members.firstIndex(where: { $0.personID == personID }) {
                trip.members[index].partySize = max(1, min(size, 9))
            }
        }
    }

    /// Anyone on the trip can turn an idea into a trip.
    func makeItATrip(_ tripID: UUID) {
        update(tripID) { $0.stage = .trip }
    }

    func backToIdea(_ tripID: UUID) {
        update(tripID) { $0.stage = .proposal }
    }

    // MARK: Plan

    func saveItem(_ item: PlanItem, in tripID: UUID) {
        update(tripID) { trip in
            if let index = trip.items.firstIndex(where: { $0.id == item.id }) {
                trip.items[index] = item
            } else {
                trip.items.append(item)
            }
        }
    }

    func deleteItem(_ itemID: UUID, in tripID: UUID) {
        update(tripID) { trip in
            trip.items.removeAll { $0.id == itemID }
            for index in trip.polls.indices where trip.polls[index].itemID == itemID {
                trip.polls[index].itemID = nil
            }
        }
    }

    // MARK: Polls

    /// Posts the poll, or sends it to the organizer when the trip asks first.
    /// Returns what happened.
    @discardableResult
    func addPoll(_ poll: Poll, in tripID: UUID) -> PollPermission {
        guard let trip = self.trip(tripID) else { return .none }
        let permission = trip.canPublishPolls(data.currentUserID)
        guard permission != .none else { return .none }
        var poll = poll
        poll.createdBy = data.currentUserID
        poll.status = permission == .publish ? .published : .pending
        update(tripID) { $0.polls.append(poll) }
        return permission
    }

    func vote(_ optionID: UUID, poll pollID: UUID, in tripID: UUID) {
        let me = data.currentUserID
        update(tripID) { trip in
            guard let p = trip.polls.firstIndex(where: { $0.id == pollID }), !trip.polls[p].isClosed else { return }
            let multiple = trip.polls[p].allowsMultiple
            for o in trip.polls[p].options.indices {
                let isTarget = trip.polls[p].options[o].id == optionID
                let voted = trip.polls[p].options[o].voterIDs.contains(me)
                if isTarget {
                    if voted { trip.polls[p].options[o].voterIDs.removeAll { $0 == me } } else { trip.polls[p].options[o].voterIDs.append(me) }
                } else if !multiple {
                    trip.polls[p].options[o].voterIDs.removeAll { $0 == me }
                }
            }
        }
    }

    func approvePoll(_ pollID: UUID, in tripID: UUID) {
        update(tripID) { trip in
            if let p = trip.polls.firstIndex(where: { $0.id == pollID }) { trip.polls[p].status = .published }
        }
    }

    func deletePoll(_ pollID: UUID, in tripID: UUID) {
        update(tripID) { $0.polls.removeAll { $0.id == pollID } }
    }

    func setPollClosed(_ pollID: UUID, closed: Bool, in tripID: UUID) {
        update(tripID) { trip in
            if let p = trip.polls.firstIndex(where: { $0.id == pollID }) { trip.polls[p].isClosed = closed }
        }
    }

    // MARK: Money

    func saveExpense(_ expense: Expense, in tripID: UUID) {
        update(tripID) { trip in
            if let index = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
                trip.expenses[index] = expense
            } else {
                trip.expenses.append(expense)
            }
        }
    }

    func deleteExpense(_ expenseID: UUID, in tripID: UUID) {
        update(tripID) { $0.expenses.removeAll { $0.id == expenseID } }
    }

    func markPaid(_ transfer: Transfer, in tripID: UUID) {
        update(tripID) {
            $0.payments.append(Payment(fromID: transfer.fromID, toID: transfer.toID, amountMinor: transfer.amountMinor, date: Date()))
        }
    }

    func deletePayment(_ paymentID: UUID, in tripID: UUID) {
        update(tripID) { $0.payments.removeAll { $0.id == paymentID } }
    }
}
