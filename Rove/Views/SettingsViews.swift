import SwiftUI

/// The organizer's controls: trip basics, budget, who's on it, polls.
struct TripSettingsView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    let onDelete: () -> Void
    @State private var draft: Trip?
    @State private var confirmDelete = false
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group {
                if let binding = Binding($draft) {
                    form(binding)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Trip settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let draft { store.update(tripID) { $0 = draft } }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-settings")
                }
            }
            .onAppear { if draft == nil { draft = store.trip(tripID) } }
        }
    }

    private func form(_ trip: Binding<Trip>) -> some View {
        let me = store.data.currentUserID
        let isOrganizer = trip.wrappedValue.organizerID == me
        return Form {
            if !isOrganizer {
                Section {
                    Label("\(store.person(trip.wrappedValue.organizerID).firstName) organizes this trip. Anyone on it can change the plan; the organizer picks who posts polls.", systemImage: "info.circle")
                        .font(.subheadline)
                }
            }
            TripBasicsSection(trip: trip)

            Section {
                ForEach(trip.members, id: \.personID) { $member in
                    HStack {
                        PersonRow(person: store.person(member.personID),
                                  title: member.personID == me ? "You" : store.person(member.personID).name,
                                  subtitle: member.response?.title ?? "No answer yet",
                                  partySize: member.partySize)
                        Spacer()
                        Stepper(member.partySize == 1 ? "1" : "\(member.partySize)", value: $member.partySize, in: 1...9)
                            .fixedSize()
                            .accessibilityLabel("Party size for \(store.person(member.personID).firstName)")
                    }
                    .contextMenu {
                        if member.personID != trip.wrappedValue.organizerID {
                            Button("Take off this trip", systemImage: "person.badge.minus", role: .destructive) {
                                trip.wrappedValue.members.removeAll { $0.personID == member.personID }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let organizer = trip.wrappedValue.organizerID
                    let keep = offsets.filter { trip.wrappedValue.members[$0].personID != organizer }
                    trip.wrappedValue.members.remove(atOffsets: IndexSet(keep))
                }
                let candidates = addable(trip.wrappedValue)
                if !candidates.isEmpty {
                    Menu {
                        ForEach(candidates) { person in
                            Button(person.name) { trip.wrappedValue.members.append(TripMember(personID: person.id)) }
                        }
                    } label: {
                        Label("Add someone", systemImage: "person.badge.plus")
                    }
                }
            } header: {
                Text("People")
            } footer: {
                Text("The number is how many people each person signs up for. Someone bringing a partner who isn't on Rove counts as 2 in splits and estimates.")
            }

            BudgetSection(trip: trip)

            Section {
                Picker("Who can post polls", selection: trip.pollPolicy) {
                    ForEach(PollPolicy.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!isOrganizer)
                .accessibilityIdentifier("poll-policy")
                if trip.wrappedValue.pollPolicy == .selected {
                    ForEach(trip.wrappedValue.members.filter { $0.personID != trip.wrappedValue.organizerID }, id: \.personID) { member in
                        Toggle(store.person(member.personID).name, isOn: publisherBinding(trip, member.personID))
                            .disabled(!isOrganizer)
                    }
                }
            } header: {
                Text("Polls")
            } footer: {
                Text(trip.wrappedValue.pollPolicy.detail + (isOrganizer ? "" : " Only the organizer can change this."))
            }

            Section {
                if trip.wrappedValue.stage == .trip {
                    Button("Turn back into an idea") { trip.wrappedValue.stage = .proposal }
                } else {
                    Button("Make it a trip") { trip.wrappedValue.stage = .trip }
                }
                if isOrganizer {
                    Button("Delete trip", role: .destructive) { confirmDelete = true }
                }
            }
            .confirmationDialog("Delete \(trip.wrappedValue.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete for everyone", role: .destructive) {
                    store.deleteTrip(tripID)
                    dismiss()
                    onDelete()
                }
            } message: {
                Text("The plan, expenses and balances go too.")
            }
        }
    }

    private func addable(_ trip: Trip) -> [Person] {
        let me = store.data.currentUserID
        let ids = store.groups.filter { $0.memberIDs.contains(me) }.flatMap(\.memberIDs)
        var seen = Set(trip.members.map(\.personID))
        return ids.filter { seen.insert($0).inserted }.map { store.person($0) }
    }

    private func publisherBinding(_ trip: Binding<Trip>, _ id: UUID) -> Binding<Bool> {
        Binding(
            get: { trip.wrappedValue.pollPublisherIDs.contains(id) },
            set: { on in
                trip.wrappedValue.pollPublisherIDs.removeAll { $0 == id }
                if on { trip.wrappedValue.pollPublisherIDs.append(id) }
            }
        )
    }
}

/// Your groups: the people you travel with.
struct GroupsView: View {
    @Environment(TripStore.self) private var store
    @State private var newGroupName = ""
    @State private var inviteNames: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Everyone joins Rove on their own, then you invite each other into groups. Ideas and trips are shared with the people you pick.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(store.groups) { group in
                    Section {
                        ForEach(group.memberIDs, id: \.self) { id in
                            PersonRow(person: store.person(id), title: id == store.data.currentUserID ? "You" : store.person(id).name)
                                .swipeActions {
                                    if id != store.data.currentUserID {
                                        Button("Remove", role: .destructive) { store.removeFromGroup(id, groupID: group.id) }
                                    }
                                }
                                // The same as the swipe, for anyone who doesn't swipe.
                                .contextMenu {
                                    if id != store.data.currentUserID {
                                        Button("Remove from \(group.name)", systemImage: "person.badge.minus", role: .destructive) {
                                            store.removeFromGroup(id, groupID: group.id)
                                        }
                                    }
                                }
                        }
                        ForEach(group.pendingInvites, id: \.self) { name in
                            HStack {
                                Image(systemName: "envelope.badge").foregroundStyle(.secondary).frame(width: 34).accessibilityHidden(true)
                                Text(name)
                                Spacer()
                                Text("Invited").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            TextField("Invite someone by name", text: Binding(get: { inviteNames[group.id] ?? "" }, set: { inviteNames[group.id] = $0 }))
                                .onSubmit { invite(group.id) }
                                .accessibilityIdentifier("invite-\(group.name)")
                            Button("Invite") { invite(group.id) }
                                .disabled((inviteNames[group.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } header: {
                        Text(group.name)
                    }
                }
                Section {
                    HStack {
                        TextField("New group name", text: $newGroupName)
                        Button("Create") {
                            store.createGroup(name: newGroupName)
                            newGroupName = ""
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Until accounts are switched on, invites add people right away so you can try trips with them.")
                }
            }
            .readableWidth()
            .navigationTitle("Groups")
        }
    }

    private func invite(_ groupID: UUID) {
        store.invite(inviteNames[groupID] ?? "", to: groupID)
        inviteNames[groupID] = ""
    }
}

/// You, plus testing tools while there's no server.
struct ProfileView: View {
    @Environment(TripStore.self) private var store
    @State private var name = ""
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Avatar(person: store.me, size: 56)
                        TextField("Your name", text: $name)
                            .font(.title3.weight(.semibold))
                            .onSubmit { store.renameMe(name) }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Picker("Use Rove as", selection: Binding(get: { store.data.currentUserID }, set: { store.actAs($0); name = store.me.name })) {
                        ForEach(store.people) { person in
                            Text(person.name).tag(person.id)
                        }
                    }
                    .accessibilityIdentifier("act-as")
                    Button("Start over with the sample trips", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Everything is on this phone for now. Switch person to see a trip the way someone else does: answer for them, vote, or approve polls as the organizer.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1")
                    LabeledContent("Receipts", value: "Read on this phone, never kept")
                }
            }
            .readableWidth()
            .navigationTitle("You")
            .onAppear { name = store.me.name }
            .onDisappear { store.renameMe(name) }
            .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Replace everything with the sample", role: .destructive) {
                    store.resetToSample()
                    name = store.me.name
                }
            } message: {
                Text("Trips, plans and expenses on this phone are replaced.")
            }
        }
    }
}
