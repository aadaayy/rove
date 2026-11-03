import SwiftUI

/// Polls on the plan, with the organizer's approvals.
struct PollsSection: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let onNewPoll: () -> Void

    private var me: UUID { store.data.currentUserID }

    var body: some View {
        let permission = trip.canPublishPolls(me)
        let isOrganizer = trip.organizerID == me
        let pending = trip.pendingPolls.filter { isOrganizer || $0.createdBy == me }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Polls")
                if permission != .none {
                    Button(action: onNewPoll) {
                        Label(permission == .publish ? "New poll" : "Suggest", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("new-poll")
                }
            }
            if permission == .none {
                Label("The organizer picks who can post polls on this trip.", systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            } else if permission == .request {
                Label("Polls you suggest show once \(store.person(trip.organizerID).firstName) approves them.", systemImage: "checkmark.seal")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            ForEach(pending) { poll in
                PendingPollCard(trip: trip, poll: poll, canApprove: isOrganizer)
            }
            ForEach(trip.publishedPolls) { poll in
                PollCard(trip: trip, poll: poll)
            }
            if trip.publishedPolls.isEmpty && pending.isEmpty {
                Text("Can't agree on dinner? Put it to a vote.")
                    .foregroundStyle(.secondary)
                    .card()
            }
        }
    }
}

struct PollCard: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let poll: Poll

    var body: some View {
        let me = store.data.currentUserID
        let total = max(1, poll.totalVotes)
        let leaders = poll.leaders
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(poll.question).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(poll.options) { option in
                let mine = option.voterIDs.contains(me)
                let fraction = CGFloat(option.voterIDs.count) / CGFloat(total)
                Button {
                    store.vote(option.id, poll: poll.id, in: trip.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mine ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mine ? Color.accentColor : Color.secondary)
                        Text(option.text).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        HStack(spacing: -6) {
                            ForEach(option.voterIDs.prefix(3), id: \.self) { id in
                                Avatar(person: store.person(id), size: 20)
                                    .overlay(Circle().stroke(Theme.card, lineWidth: 1.5))
                            }
                        }
                        Text("\(option.voterIDs.count)")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 16, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(alignment: .leading) {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill((leaders.contains(option.id) ? Color.accentColor : Color.secondary).opacity(0.14))
                                .frame(width: max(0, geometry.size.width * fraction))
                        }
                    }
                    .background(Theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(poll.isClosed)
                .accessibilityIdentifier("vote-\(option.text)")
            }
            HStack {
                Text(poll.allowsMultiple ? "Pick as many as you like" : "Pick one")
                Spacer()
                if poll.isClosed { Text("Closed") }
                if poll.createdBy == me || trip.organizerID == me {
                    Menu {
                        Button(poll.isClosed ? "Reopen" : "Close voting") {
                            store.setPollClosed(poll.id, closed: !poll.isClosed, in: trip.id)
                        }
                        Button("Delete poll", role: .destructive) { store.deletePoll(poll.id, in: trip.id) }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.body)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    private var subtitle: String {
        var parts = ["By \(store.name(poll.createdBy))", "\(poll.totalVotes) vote\(poll.totalVotes == 1 ? "" : "s")"]
        if let slot = poll.slot { parts.append(Formats.day(slot) + " · " + Formats.time(slot)) }
        if let id = poll.itemID, let item = trip.items.first(where: { $0.id == id }) { parts.append(item.title) }
        return parts.joined(separator: " · ")
    }
}

/// A suggested poll, waiting for the organizer.
struct PendingPollCard: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let poll: Poll
    let canApprove: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Chip(text: canApprove ? "Needs your OK" : "Waiting for approval", symbol: "hourglass", color: .orange)
                Spacer()
            }
            Text(poll.question).font(.headline)
            Text("Suggested by \(store.name(poll.createdBy)) · \(poll.options.map(\.text).joined(separator: ", "))")
                .font(.subheadline).foregroundStyle(.secondary)
            if canApprove {
                HStack(spacing: 10) {
                    Button("Decline") { store.deletePoll(poll.id, in: trip.id) }
                        .buttonStyle(WideButtonStyle(prominent: false))
                        .accessibilityIdentifier("decline-poll")
                    Button("Approve") { withAnimation { store.approvePoll(poll.id, in: trip.id) } }
                        .buttonStyle(WideButtonStyle())
                        .accessibilityIdentifier("approve-poll")
                }
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }
}

/// Ask the group something.
struct NewPollView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    @State private var question = ""
    @State private var options = ["", ""]
    @State private var itemID: UUID?
    @State private var hasSlot = false
    @State private var slot = Date()
    @State private var allowsMultiple = false

    private var cleanOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var canPost: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty && cleanOptions.count >= 2
    }

    var body: some View {
        let permission = trip.canPublishPolls(store.data.currentUserID)
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Where should we eat Saturday?", text: $question, axis: .vertical)
                        .accessibilityIdentifier("poll-question")
                }
                Section {
                    ForEach(options.indices, id: \.self) { index in
                        TextField("Option \(index + 1)", text: $options[index])
                            .accessibilityIdentifier("poll-option-\(index + 1)")
                    }
                    .onDelete { offsets in
                        if options.count > 2 { options.remove(atOffsets: offsets) }
                    }
                    if options.count < 8 {
                        Button { options.append("") } label: { Label("Add option", systemImage: "plus.circle.fill") }
                    }
                    Toggle("Allow more than one pick", isOn: $allowsMultiple)
                } header: {
                    Text("Options")
                }
                Section {
                    Picker("About", selection: $itemID) {
                        Text("Nothing in particular").tag(UUID?.none)
                        ForEach(trip.items) { item in
                            Text(item.title).tag(UUID?.some(item.id))
                        }
                    }
                    Toggle("For a time slot", isOn: $hasSlot)
                    if hasSlot {
                        DatePicker("When", selection: $slot, in: trip.startDate...(Calendar.current.date(byAdding: .day, value: 1, to: trip.endDate) ?? trip.endDate))
                    }
                } footer: {
                    if permission == .request {
                        Text("\(store.person(trip.organizerID).firstName) approves polls on this trip before everyone sees them.")
                    }
                }
            }
            .navigationTitle(permission == .request ? "Suggest a poll" : "New poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(permission == .request ? "Send" : "Post") { post() }
                        .fontWeight(.semibold)
                        .disabled(!canPost)
                        .accessibilityIdentifier("post-poll")
                }
            }
            .onAppear { slot = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: trip.startDate) ?? trip.startDate }
        }
    }

    private func post() {
        let poll = Poll(question: question.trimmingCharacters(in: .whitespaces),
                        options: cleanOptions.map { PollOption(text: $0) },
                        createdBy: store.data.currentUserID,
                        itemID: itemID, slot: hasSlot ? slot : nil, allowsMultiple: allowsMultiple)
        store.addPoll(poll, in: trip.id)
        dismiss()
    }
}
