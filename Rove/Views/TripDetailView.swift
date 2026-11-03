import SwiftUI

enum TripTab: String, CaseIterable, Hashable {
    case overview, plan, expenses, balances

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .plan: return "Plan"
        case .expenses: return "Expenses"
        case .balances: return "Balances"
        }
    }
}

/// One trip: overview, plan, expenses and balances.
struct TripDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    @State private var tab: TripTab
    @State private var showingSettings = false

    init(tripID: UUID, initialTab: TripTab = .overview) {
        self.tripID = tripID
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        if let trip = store.trip(tripID) {
            GeometryReader { geometry in
                let wide = geometry.size.width >= Theme.wideWidth
                VStack(spacing: 0) {
                    Picker("Section", selection: $tab) {
                        ForEach(TripTab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("trip-tabs")

                    Group {
                        switch tab {
                        case .overview: OverviewTab(trip: trip, wide: wide, showTab: { tab = $0 })
                        case .plan: PlanTab(trip: trip, wide: wide)
                        case .expenses: ExpensesTab(trip: trip, wide: wide)
                        case .balances: BalancesTab(trip: trip, wide: wide)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    // Cards fade out under the tabs instead of being cut off.
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [Theme.background, Theme.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 14)
                            .allowsHitTesting(false)
                    }
                }
                .background(Theme.background)
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("trip-settings")
                    .accessibilityLabel("Trip settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                TripSettingsView(tripID: trip.id, onDelete: { dismiss() })
            }
        } else {
            ContentUnavailableView("Trip not found", systemImage: "suitcase", description: Text("It may have been deleted."))
        }
    }
}

// MARK: - Overview

struct OverviewTab: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let wide: Bool
    let showTab: (TripTab) -> Void

    var body: some View {
        ScrollView {
            if wide {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        header
                        if trip.stage == .proposal { yourAnswer } else { nextUp }
                        whoIsIn
                    }
                    VStack(spacing: 16) {
                        EstimateCard(trip: trip)
                        if trip.stage == .proposal { makeItATrip }
                    }
                }
                .padding(16)
            } else {
                VStack(spacing: 16) {
                    header
                    if trip.stage == .proposal { yourAnswer } else { nextUp }
                    EstimateCard(trip: trip)
                    whoIsIn
                    if trip.stage == .proposal { makeItATrip }
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if trip.stage == .proposal {
                    Chip(text: "Idea", symbol: "lightbulb.fill", color: .orange)
                } else {
                    Chip(text: "Trip", symbol: "airplane", color: .accentColor)
                }
                Spacer()
                Text(Formats.countdown(to: trip.startDate, end: trip.endDate)).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(trip.destination).font(.title2.weight(.bold))
            Label(Formats.dateRange(trip.startDate, trip.endDate) + " · " + Estimator.plural(trip.days, "day"), systemImage: "calendar")
                .foregroundStyle(.secondary)
            Label("Organized by \(store.name(trip.organizerID) == "You" ? "you" : store.person(trip.organizerID).name)", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
            if !trip.note.isEmpty {
                Text(trip.note).padding(.top, 2)
            }
        }
        .card()
    }

    private var me: UUID { store.data.currentUserID }

    private var yourAnswer: some View {
        let member = trip.member(me)
        return VStack(alignment: .leading, spacing: 12) {
            Text(member?.response == nil ? "Are you in?" : "Your answer").font(.headline)
            HStack(spacing: 8) {
                ForEach(Response.allCases, id: \.self) { response in
                    let selected = member?.response == response
                    Button {
                        store.respond(trip.id, response: response)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: response.symbol).font(.title3)
                            Text(response.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected ? Color.white : Theme.color(for: response))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? Theme.color(for: response) : Theme.color(for: response).opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("respond-\(response.rawValue)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if member != nil, member?.response != .cantMakeIt {
                PartySizeControl(trip: trip, personID: me)
            }
        }
        .card()
    }

    private var nextUp: some View {
        let upcoming = trip.items
            .filter { ($0.date ?? .distantPast) >= Calendar.current.startOfDay(for: Date()) }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        let pending = trip.pendingPolls.count
        let openPolls = trip.publishedPolls.filter { poll in !poll.isClosed && !poll.options.contains { $0.voterIDs.contains(me) } }
        let owe = Ledger.suggestedRepayments(for: trip).filter { $0.fromID == me }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Next up").font(.headline)
            if let first = upcoming.first {
                Button { showTab(.plan) } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: first.kind.symbol, color: Theme.color(for: first.kind))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(first.title).foregroundStyle(.primary)
                            if let date = first.date {
                                Text(Formats.day(date) + (first.hasTime ? " · " + Formats.time(date) : ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            if !openPolls.isEmpty {
                actionRow("\(openPolls.count) poll\(openPolls.count == 1 ? "" : "s") waiting for your vote", symbol: "chart.bar.fill", color: .purple) { showTab(.plan) }
            }
            if pending > 0 && trip.organizerID == me {
                actionRow("\(pending) poll\(pending == 1 ? "" : "s") to approve", symbol: "checkmark.seal.fill", color: .orange) { showTab(.plan) }
            }
            if let debt = owe.first {
                actionRow("You owe \(store.person(debt.toID).firstName) \(Money(debt.amountMinor, trip.currency).formatted())", symbol: "arrow.left.arrow.right", color: Theme.negative) { showTab(.balances) }
            }
            if upcoming.isEmpty && openPolls.isEmpty && owe.isEmpty && pending == 0 {
                Text("Nothing waiting on you.").foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func actionRow(_ text: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color)
                Text(text).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var whoIsIn: some View {
        let groups: [ResponseGroup] = [
            ResponseGroup(title: "Interested", members: trip.members.filter { $0.response == .interested }),
            ResponseGroup(title: "Maybe", members: trip.members.filter { $0.response == .maybe }),
            ResponseGroup(title: "No answer yet", members: trip.members.filter { $0.response == nil }),
            ResponseGroup(title: "Can't make it", members: trip.members.filter { $0.response == .cantMakeIt }),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trip.stage == .proposal ? "Who's in" : "Who's going").font(.headline)
                Spacer()
                Text(Estimator.plural(trip.expectedTravelers, "traveler")).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(groups.filter { !$0.members.isEmpty }) { group in
                VStack(alignment: .leading, spacing: 8) {
                    if trip.stage == .proposal {
                        Text(group.title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ForEach(group.members, id: \.personID) { member in
                        HStack {
                            PersonRow(person: store.person(member.personID),
                                      title: member.personID == me ? "You" : store.person(member.personID).name,
                                      subtitle: member.partySize > 1 ? "Coming as \(member.partySize)" : nil,
                                      partySize: member.partySize)
                            Spacer()
                            if member.personID == trip.organizerID {
                                Chip(text: "Organizer", color: .accentColor)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    private var makeItATrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready to go?").font(.headline)
            Text("Anyone on this idea can turn it into a trip. The plan, expenses and balances open up for everyone.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                withAnimation { store.makeItATrip(trip.id) }
            } label: {
                Label("Make it a trip", systemImage: "airplane.departure")
            }
            .buttonStyle(WideButtonStyle())
            .accessibilityIdentifier("make-it-a-trip")
        }
        .card()
    }
}

struct ResponseGroup: Identifiable {
    var id: String { title }
    let title: String
    let members: [TripMember]
}

/// "Just me" or "For 2": someone signing up for themselves and a partner.
struct PartySizeControl: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let personID: UUID

    var body: some View {
        let size = trip.partySize(of: personID)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(size == 1 ? "Just me" : "Me + \(size - 1)").font(.subheadline.weight(.semibold))
                Text("Coming with someone who isn't on Rove? Count them here.").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Stepper("Party size", value: Binding(get: { size }, set: { store.setPartySize(trip.id, personID: personID, size: $0) }), in: 1...9)
                .labelsHidden()
                .accessibilityIdentifier("party-size")
        }
        .padding(12)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The likely cost, by category, and what's actually been spent once the trip is on.
struct EstimateCard: View {
    @Environment(TripStore.self) private var store
    let trip: Trip

    var body: some View {
        let estimate = Estimator.estimate(for: trip)
        let myParty = trip.partySize(of: store.data.currentUserID)
        let showActual = trip.stage == .trip && !trip.expenses.isEmpty
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Estimate").font(.headline)
                Spacer()
                Text("for \(Estimator.plural(estimate.travelers, "traveler"))").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                StatView(value: Money(estimate.perPerson, trip.currency).rounded, caption: "per person")
                if myParty > 1 {
                    StatView(value: Money(estimate.perParty(myParty), trip.currency).rounded, caption: "your party of \(myParty)")
                } else {
                    StatView(value: Money(estimate.groupTotal, trip.currency).rounded, caption: "whole group")
                }
            }
            Divider()
            VStack(spacing: 12) {
                ForEach(estimate.lines) { line in
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(symbol: line.kind.symbol, color: Theme.color(for: line.kind), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.name).font(.subheadline.weight(.medium))
                            Text(line.assumption).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Money(line.perPerson, trip.currency).rounded)
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                            if showActual {
                                let actual = Ledger.actualPerPerson(trip, kind: line.kind)
                                Text("\(Money(actual, trip.currency).rounded) spent")
                                    .font(.caption).monospacedDigit()
                                    .foregroundStyle(actual > line.perPerson ? Theme.negative : .secondary)
                            }
                        }
                    }
                }
                if estimate.lines.isEmpty {
                    Text("No budget yet. Add costs in the trip's settings.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}
