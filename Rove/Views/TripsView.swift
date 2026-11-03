import SwiftUI

/// Home: ideas people are weighing, trips coming up, and past trips.
struct TripsView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.openTrip) private var openTrip
    @State private var showingNewTrip = false

    private var ideas: [Trip] {
        store.trips.filter { $0.phase(today: Date()) == .idea }.sorted { $0.startDate < $1.startDate }
    }
    private var upcoming: [Trip] {
        store.trips.filter { [.now, .upcoming].contains($0.phase(today: Date())) }.sorted { $0.startDate < $1.startDate }
    }
    private var past: [Trip] {
        store.trips.filter { $0.phase(today: Date()) == .past }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = geometry.size.width >= Theme.wideWidth ? 2 : 1
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.trips.isEmpty {
                        emptyState
                    }
                    if !upcoming.isEmpty {
                        SectionHeader(title: "Upcoming")
                        grid(upcoming, columns: columns)
                    }
                    if !ideas.isEmpty {
                        SectionHeader(title: "Ideas", detail: "Say if you're in")
                        grid(ideas, columns: columns)
                    }
                    if !past.isEmpty {
                        SectionHeader(title: "Past")
                        grid(past, columns: columns)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
        }
        .navigationTitle("Rove")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewTrip = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("new-trip")
                .accessibilityLabel("New trip idea")
            }
        }
        .sheet(isPresented: $showingNewTrip) { NewProposalView() }
    }

    private func grid(_ trips: [Trip], columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), spacing: 12) {
            ForEach(trips) { trip in
                Button { openTrip(trip.id) } label: {
                    TripCard(trip: trip)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trip-\(trip.name)")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "suitcase.rolling.fill").font(.system(size: 44)).foregroundStyle(Color.accentColor)
            Text("No trips yet").font(.title3.weight(.semibold))
            Text("Start an idea, set a rough budget, and see who's in.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("New trip idea") { showingNewTrip = true }
                .buttonStyle(WideButtonStyle())
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

/// One trip in the list: name, where and when, who's going and the money.
struct TripCard: View {
    @Environment(TripStore.self) private var store
    let trip: Trip

    var body: some View {
        let phase = trip.phase(today: Date())
        let estimate = Estimator.estimate(for: trip)
        let myResponse = trip.member(store.data.currentUserID)?.response
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    status(phase, myResponse: myResponse)
                }
                Text("\(trip.destination) · \(Formats.dateRange(trip.startDate, trip.endDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(alignment: .lastTextBaseline) {
                AvatarStack(people: trip.members.filter(\.isComing).map { store.person($0.personID) }, size: 24)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if phase == .idea || trip.expenses.isEmpty {
                        Text(Money(estimate.perPerson, trip.currency).rounded)
                            .font(.headline).monospacedDigit()
                        Text("est. per person").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(Money(Ledger.totalSpent(trip), trip.currency).formatted(wholeIfRound: true))
                            .font(.headline).monospacedDigit()
                        Text("spent so far").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func status(_ phase: Trip.Phase, myResponse: Response?) -> some View {
        switch phase {
        case .idea:
            if let myResponse {
                Chip(text: myResponse.title, color: Theme.color(for: myResponse))
            } else {
                Chip(text: "Answer", color: Theme.warning)
            }
        case .now: Chip(text: "Now", color: Theme.positive)
        case .upcoming: Chip(text: Formats.countdown(to: trip.startDate, end: trip.endDate), color: .accentColor)
        case .past: Chip(text: "Done", color: .secondary)
        }
    }
}
