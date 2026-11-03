import SwiftUI

/// Home: ideas people are weighing, trips coming up, and past trips.
struct TripsView: View {
    @Environment(TripStore.self) private var store
    @State private var showingNewTrip = false
    @State private var showingPeople = false
    @State private var showingProfile = false

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
            ToolbarItem(placement: .topBarLeading) {
                Button { showingProfile = true } label: {
                    Avatar(person: store.me, size: 30)
                }
                .accessibilityIdentifier("profile")
                .accessibilityLabel("You")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPeople = true } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityIdentifier("groups")
                .accessibilityLabel("Groups")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewTrip = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("new-trip")
                .accessibilityLabel("New trip idea")
            }
        }
        .sheet(isPresented: $showingNewTrip) { NewProposalView() }
        .sheet(isPresented: $showingPeople) { GroupsView() }
        .sheet(isPresented: $showingProfile) { ProfileView() }
    }

    private func grid(_ trips: [Trip], columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), spacing: 12) {
            ForEach(trips) { trip in
                NavigationLink(value: trip.id) {
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

/// One trip in the list.
struct TripCard: View {
    @Environment(TripStore.self) private var store
    let trip: Trip

    var body: some View {
        let phase = trip.phase(today: Date())
        let estimate = Estimator.estimate(for: trip)
        let myResponse = trip.member(store.data.currentUserID)?.response
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Label(trip.destination, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                phaseChip(phase, myResponse: myResponse)
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(Formats.dateRange(trip.startDate, trip.endDate))
                Text("·")
                Text(Formats.countdown(to: trip.startDate, end: trip.endDate))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            Divider()

            HStack(alignment: .center) {
                AvatarStack(people: trip.members.filter(\.isComing).map { store.person($0.personID) })
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
    private func phaseChip(_ phase: Trip.Phase, myResponse: Response?) -> some View {
        switch phase {
        case .idea:
            if let myResponse {
                Chip(text: myResponse.title, symbol: myResponse.symbol, color: Theme.color(for: myResponse))
            } else {
                Chip(text: "Answer", symbol: "bell.fill", color: .orange)
            }
        case .now: Chip(text: "Now", symbol: "location.fill", color: Theme.positive)
        case .upcoming: Chip(text: "Trip", symbol: "airplane", color: .accentColor)
        case .past: Chip(text: "Done", symbol: "checkmark", color: .secondary)
        }
    }
}
