import SwiftUI

/// Start a trip idea: where, when, a rough budget, and who to ask.
struct NewProposalView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Trip
    @State private var groupID: UUID?

    init() {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: 30, to: calendar.startOfDay(for: Date())) ?? Date()
        let end = calendar.date(byAdding: .day, value: 3, to: start) ?? start
        _draft = State(initialValue: Trip(name: "", destination: "", startDate: start, endDate: end, currency: "USD",
                                          organizerID: UUID(), categories: Estimator.defaultCategories(currency: "USD")))
    }

    private var canSave: Bool {
        !draft.destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TripBasicsSection(trip: $draft)

                Section {
                    if store.groups.count > 1 {
                        Picker("Group", selection: $groupID) {
                            Text("Pick people").tag(UUID?.none)
                            ForEach(store.groups) { group in
                                Text(group.name).tag(UUID?.some(group.id))
                            }
                        }
                    }
                    ForEach(invitable) { person in
                        Toggle(isOn: invitedBinding(person.id)) {
                            PersonRow(person: person, subtitle: groupNames(person.id))
                        }
                        .accessibilityIdentifier("invite-\(person.firstName)")
                    }
                } header: {
                    Text("Who to ask")
                } footer: {
                    Text("They'll answer Interested, Maybe or Can't make it. Anyone on the trip can turn the idea into a trip when it's ready.")
                }

                BudgetSection(trip: $draft)

                EstimateSummarySection(trip: draft)
            }
            .navigationTitle("New trip idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-proposal")
                }
            }
            .onAppear(perform: setUp)
            .onChange(of: groupID) {
                guard let groupID, let group = store.groups.first(where: { $0.id == groupID }) else { return }
                let me = store.data.currentUserID
                draft.groupID = groupID
                draft.members = group.memberIDs.map { TripMember(personID: $0, response: $0 == me ? .interested : nil) }
            }
        }
    }

    /// Everyone in the groups you're in, you first.
    private var invitable: [Person] {
        let me = store.data.currentUserID
        let ids = store.groups.filter { $0.memberIDs.contains(me) }.flatMap(\.memberIDs)
        var seen = Set<UUID>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.map { store.person($0) }.sorted { a, b in
            if a.id == me { return true }
            if b.id == me { return false }
            return a.name < b.name
        }
    }

    private func groupNames(_ id: UUID) -> String? {
        if id == store.data.currentUserID { return "You, organizing" }
        let names = store.groups.filter { $0.memberIDs.contains(id) }.map(\.name)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    private func invitedBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.members.contains { $0.personID == id } },
            set: { on in
                if id == store.data.currentUserID { return }
                if on {
                    if !draft.members.contains(where: { $0.personID == id }) { draft.members.append(TripMember(personID: id)) }
                } else {
                    draft.members.removeAll { $0.personID == id }
                }
            }
        )
    }

    private func setUp() {
        let me = store.data.currentUserID
        guard draft.organizerID != me else { return }
        draft.organizerID = me
        draft.pollPublisherIDs = []
        if let first = store.groups.first(where: { $0.memberIDs.contains(me) }) {
            groupID = first.id
            draft.groupID = first.id
            draft.members = first.memberIDs.map { TripMember(personID: $0, response: $0 == me ? .interested : nil) }
        } else {
            draft.members = [TripMember(personID: me, response: .interested)]
        }
    }

    private func save() {
        var trip = draft
        trip.destination = trip.destination.trimmingCharacters(in: .whitespaces)
        if trip.name.trimmingCharacters(in: .whitespaces).isEmpty {
            trip.name = trip.destination.split(separator: ",").first.map { "\($0) trip" } ?? "New trip"
        }
        if !trip.members.contains(where: { $0.personID == trip.organizerID }) {
            trip.members.insert(TripMember(personID: trip.organizerID, response: .interested), at: 0)
        }
        trip.createdAt = Date()
        store.createProposal(trip)
        dismiss()
    }
}

/// Name, place, dates and currency.
struct TripBasicsSection: View {
    @Binding var trip: Trip

    var body: some View {
        Section("Trip") {
            LabeledContent("Where") {
                TextField("City or place", text: $trip.destination)
                    .multilineTextAlignment(.trailing)
                    .textContentType(.addressCity)
                    .accessibilityIdentifier("destination")
            }
            LabeledContent("Name") {
                TextField("Optional", text: $trip.name)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("trip-name")
            }
            DatePicker("Starts", selection: $trip.startDate, displayedComponents: .date)
            DatePicker("Ends", selection: $trip.endDate, in: trip.startDate..., displayedComponents: .date)
            Picker("Currency", selection: $trip.currency) {
                ForEach(Currencies.all, id: \.code) { info in
                    Text("\(info.code) · \(info.name)").tag(info.code)
                }
            }
            TextField("Note for everyone", text: $trip.note, axis: .vertical)
                .lineLimit(1...4)
        }
        .onChange(of: trip.startDate) {
            if trip.endDate < trip.startDate { trip.endDate = trip.startDate }
        }
    }
}

/// The budget lines, each with its assumption.
struct BudgetSection: View {
    @Binding var trip: Trip

    var body: some View {
        Section {
            ForEach($trip.categories) { $category in
                NavigationLink {
                    BudgetCategoryEditor(category: $category, currency: trip.currency)
                } label: {
                    let line = Estimator.estimate(categories: [category], days: trip.days, nights: trip.nights,
                                                  travelers: trip.expectedTravelers, currency: trip.currency).lines.first
                    HStack(spacing: 12) {
                        IconTile(symbol: category.kind.symbol, color: Theme.color(for: category.kind), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                            Text(line?.assumption ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money(line?.perPerson ?? 0, trip.currency).rounded)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { trip.categories.remove(atOffsets: $0) }
            Menu {
                ForEach(CostKind.allCases, id: \.self) { kind in
                    Button {
                        trip.categories.append(BudgetCategory(kind: kind, basis: kind == .food ? .perMeal : .perPerson,
                                                              amountMinor: 0))
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            } label: {
                Label("Add a cost", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Budget")
        } footer: {
            Text("Rough numbers are fine. Shared costs are split by everyone who hasn't said no; someone coming as 2 counts twice.")
        }
    }
}

/// Edit one budget line.
struct BudgetCategoryEditor: View {
    @Binding var category: BudgetCategory
    let currency: String
    @State private var amount: Int64?

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("Name", text: $category.name, prompt: Text(category.kind.title))
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("budget-name")
                }
                Picker("Kind", selection: $category.kind) {
                    ForEach(CostKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            }
            Section {
                Picker("Counted", selection: $category.basis) {
                    ForEach(CostBasis.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                MoneyField(title: amountTitle, minor: $amount, currency: currency, identifier: "budget-amount")
                if category.basis == .perMeal {
                    Stepper("\(category.mealsPerDay) meal\(category.mealsPerDay == 1 ? "" : "s") a day", value: $category.mealsPerDay, in: 1...5)
                }
            } footer: {
                Text(explanation)
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { amount = category.amountMinor }
        .onDisappear {
            // A name that's only spaces, or the kind's own name, goes back to following the kind.
            category.name = BudgetCategory.customName(category.name.trimmingCharacters(in: .whitespacesAndNewlines), kind: category.kind)
        }
        .onChange(of: amount) { category.amountMinor = max(0, amount ?? 0) }
    }

    private var amountTitle: String {
        switch category.basis {
        case .perPerson: return "Per person"
        case .perPersonPerDay: return "Per person a day"
        case .perMeal: return "Per meal"
        case .sharedTotal: return "Total"
        case .sharedPerNight: return "A night"
        }
    }

    private var explanation: String {
        switch category.basis {
        case .perPerson: return "Each traveler pays this once, like a flight or a ticket."
        case .perPersonPerDay: return "Each traveler, every day of the trip."
        case .perMeal: return "Each traveler, for every meal of every day. For example $50 per meal."
        case .sharedTotal: return "One cost for the whole group, split evenly, like a rental car."
        case .sharedPerNight: return "A nightly price for the whole group, split evenly, like a house."
        }
    }
}

/// The live estimate under the budget.
struct EstimateSummarySection: View {
    @Environment(TripStore.self) private var store
    let trip: Trip

    var body: some View {
        let estimate = Estimator.estimate(for: trip)
        let myParty = trip.partySize(of: store.data.currentUserID)
        Section {
            LabeledContent("Per person") {
                Text(Money(estimate.perPerson, trip.currency).rounded).monospacedDigit().fontWeight(.semibold)
            }
            if myParty > 1 {
                LabeledContent("Your party of \(myParty)") {
                    Text(Money(estimate.perParty(myParty), trip.currency).rounded).monospacedDigit()
                }
            }
            LabeledContent("Whole group") {
                Text(Money(estimate.groupTotal, trip.currency).rounded).monospacedDigit()
            }
        } header: {
            Text("Estimate")
        } footer: {
            Text("For \(Estimator.plural(estimate.travelers, "traveler")) over \(Estimator.plural(trip.days, "day")).")
        }
    }
}
