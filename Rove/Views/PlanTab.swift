import MapKit
import SwiftUI

/// The plan: a map of every saved place, the day-by-day list, and polls.
struct PlanTab: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let wide: Bool
    @State private var editing: PlanItem?
    @State private var addingPlace = false
    @State private var addingPoll = false
    @State private var selectedItemID: UUID?

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 0) {
                    TripMap(trip: trip, selectedItemID: $selectedItemID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding([.leading, .bottom], 16)
                        .padding(.top, 16)
                    ScrollView { list.padding(16).padding(.top, -4) }
                        .frame(width: 420)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        TripMap(trip: trip, selectedItemID: $selectedItemID)
                            .frame(height: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        list
                    }
                    .padding(16)
                }
            }
        }
        .sheet(isPresented: $addingPlace) { AddPlaceView(trip: trip, item: nil) }
        .sheet(item: $editing) { item in AddPlaceView(trip: trip, item: item) }
        .sheet(isPresented: $addingPoll) { NewPollView(trip: trip) }
    }

    struct Day: Identifiable {
        var id: Date { date }
        let date: Date
        let items: [PlanItem]
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let dated = trip.items.filter { $0.date != nil }
        let grouped = Dictionary(grouping: dated) { calendar.startOfDay(for: $0.date!) }
        return grouped.keys.sorted().map { day in
            Day(date: day, items: grouped[day]!.sorted { $0.date! < $1.date! })
        }
    }

    private var undated: [PlanItem] { trip.items.filter { $0.date == nil } }

    @ViewBuilder
    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Itinerary")
                Button { addingPlace = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle())
                .accessibilityLabel("Add to the plan")
                .accessibilityIdentifier("add-place")
            }
            if trip.items.isEmpty {
                Text("Add a stay, a dinner or an activity. Paste a link from Airbnb, Expedia or anywhere else.")
                    .foregroundStyle(.secondary)
                    .card()
            }
            ForEach(days) { day in
                Text(Formats.day(day.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                ForEach(day.items) { item in
                    PlaceCard(trip: trip, item: item, selected: selectedItemID == item.id, onSelect: { selectedItemID = item.id }, onEdit: { editing = item })
                        .onTapGesture { selectedItemID = item.id }
                }
            }
            if !undated.isEmpty {
                Text("Not scheduled yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                ForEach(undated) { item in
                    PlaceCard(trip: trip, item: item, selected: selectedItemID == item.id, onSelect: { selectedItemID = item.id }, onEdit: { editing = item })
                        .onTapGesture { selectedItemID = item.id }
                }
            }
            PollsSection(trip: trip, onNewPoll: { addingPoll = true })
                .padding(.top, 8)
        }
    }
}

/// Every place with a pin; Apple Maps for directions.
struct TripMap: View {
    let trip: Trip
    @Binding var selectedItemID: UUID?
    @State private var position: MapCameraPosition = .automatic

    private var pinned: [PlanItem] { trip.items.filter { $0.place != nil } }

    var body: some View {
        Map(position: $position, selection: $selectedItemID) {
            ForEach(pinned) { item in
                let place = item.place!
                Marker(item.title, systemImage: item.kind.symbol,
                       coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                    .tint(Theme.color(for: item.kind))
                    .tag(item.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .topLeading) {
            if pinned.isEmpty {
                Text("Places you add show up here")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
            }
        }
        .onChange(of: selectedItemID) {
            guard let id = selectedItemID, let place = trip.items.first(where: { $0.id == id })?.place else { return }
            withMotion {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
            }
        }
        .accessibilityIdentifier("trip-map")
    }
}

/// A stay, a meal, an activity: time, price, links and directions.
struct PlaceCard: View {
    @Environment(\.openURL) private var openURL
    @Environment(TripStore.self) private var store
    let trip: Trip
    let item: PlanItem
    var selected = false
    var onSelect: () -> Void = {}
    let onEdit: () -> Void

    /// "10:40 AM · $212 per person, round trip"
    private var detail: String {
        var parts: [String] = []
        if let date = item.date, item.hasTime { parts.append(Formats.time(date)) }
        if let price = item.priceMinor {
            parts.append(Money(price, trip.currency).formatted(wholeIfRound: true) + (item.priceNote.isEmpty ? "" : " \(item.priceNote)"))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(symbol: item.kind.symbol, color: Theme.color(for: item.kind))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if !detail.isEmpty {
                        // One line of text, so a long price note wraps under the time.
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let place = item.place {
                        Text(place.address.isEmpty ? place.name : place.address)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Edit \(item.title)")
                .padding(.top, -8)
                .padding(.trailing, -10)
            }
            if !item.notes.isEmpty {
                Text(item.notes).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            if !item.links.isEmpty || item.place != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { buttons }
                    VStack(alignment: .leading, spacing: 8) { buttons }
                }
            }
            if let poll = trip.publishedPolls.first(where: { $0.itemID == item.id }) {
                Label("Poll: \(poll.question)", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
            }
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Theme.color(for: item.kind) : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: "Show on the map") { onSelect() }
        .accessibilityIdentifier("place-\(item.title)")
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(item.links, id: \.self) { link in
            if let url = ListingLinks.url(link) {
                Button {
                    openURL(url)
                } label: {
                    Label(ListingLinks.buttonTitle(for: link), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        if let place = item.place, let url = MapsLinks.directions(to: place) {
            Button {
                openURL(url)
            } label: {
                Label("Open in Apple Maps", systemImage: "map.fill")
            }
            .buttonStyle(PillButtonStyle(neutral: true))
        }
    }
}
