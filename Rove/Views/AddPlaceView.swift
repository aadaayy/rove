import MapKit
import SwiftUI

/// Add or change something in the plan: what, when, price, links and where.
struct AddPlaceView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    @State private var draft: PlanItem
    @State private var hasDate: Bool
    @State private var price: Int64?
    @State private var newLink = ""
    @State private var searchText = ""
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var searchFailed = false
    private let isNew: Bool

    init(trip: Trip, item: PlanItem?) {
        self.trip = trip
        isNew = item == nil
        let start = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: trip.startDate) ?? trip.startDate
        let initial = item ?? PlanItem(kind: .activity, title: "", date: start, hasTime: false)
        _draft = State(initialValue: initial)
        _hasDate = State(initialValue: initial.date != nil)
        _price = State(initialValue: initial.priceMinor)
    }

    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(PlaceKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField("Name, like Hattie B's or Loft in The Gulch", text: $draft.title)
                        .accessibilityIdentifier("place-title")
                }

                Section("When") {
                    Toggle("On a set day", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Day", selection: dateBinding, displayedComponents: .date)
                        Toggle("At a set time", isOn: $draft.hasTime)
                        if draft.hasTime {
                            DatePicker("Time", selection: dateBinding, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section {
                    MoneyField(title: "Price", minor: $price, currency: trip.currency, identifier: "place-price")
                    TextField("Covers (per person, a night...)", text: $draft.priceNote)
                } header: {
                    Text("Price estimate")
                }

                Section {
                    ForEach(draft.links, id: \.self) { link in
                        HStack {
                            Image(systemName: "link").foregroundStyle(.secondary).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ListingLinks.buttonTitle(for: link)).font(.subheadline.weight(.semibold))
                                Text(link).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .contextMenu {
                            Button("Remove link", systemImage: "trash", role: .destructive) {
                                draft.links.removeAll { $0 == link }
                            }
                        }
                    }
                    .onDelete { draft.links.remove(atOffsets: $0) }
                    HStack {
                        TextField("Paste a link", text: $newLink)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(addLink)
                            .accessibilityIdentifier("place-link")
                        if !newLink.isEmpty {
                            Button("Add", action: addLink).disabled(ListingLinks.url(newLink) == nil)
                        }
                    }
                } header: {
                    Text("Links")
                } footer: {
                    if let url = ListingLinks.url(newLink), !newLink.isEmpty {
                        Text("Shows as \u{201C}\(ListingLinks.buttonTitle(for: url.absoluteString))\u{201D}")
                    } else {
                        Text("Airbnb, Expedia, Booking.com, a restaurant's page. The button says where it goes.")
                    }
                }

                Section {
                    if let place = draft.place {
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.color(for: draft.kind)).font(.title2)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name)
                                if !place.address.isEmpty {
                                    Text(place.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Remove", role: .destructive) { draft.place = nil }
                                .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        TextField(draft.place == nil ? "Search for the place" : "Search for another place", text: $searchText)
                            .onSubmit { Task { await search() } }
                            .submitLabel(.search)
                            .accessibilityIdentifier("place-search")
                        if searching { ProgressView() }
                    }
                    ForEach(results, id: \.self) { result in
                        Button {
                            draft.place = result
                            if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { draft.title = result.name }
                            results = []
                            searchText = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.name).foregroundStyle(.primary)
                                Text(result.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if searchFailed {
                        Text("Couldn't search right now. You can save without a pin and add it later.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("On the map")
                } footer: {
                    Text("Pick the right result so the pin and Apple Maps directions go to the right spot.")
                }

                Section("Notes") {
                    TextField("Anything people should know", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if !isNew {
                    Section {
                        Button("Remove from plan", role: .destructive) {
                            store.deleteItem(draft.id, in: trip.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add to plan" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-place")
                }
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { draft.date ?? trip.startDate }, set: { draft.date = $0 })
    }

    private func addLink() {
        guard let url = ListingLinks.url(newLink) else { return }
        let text = url.absoluteString
        if !draft.links.contains(text) { draft.links.append(text) }
        newLink = ""
    }

    private func save() {
        if !newLink.isEmpty { addLink() }
        var item = draft
        item.title = item.title.trimmingCharacters(in: .whitespaces)
        item.priceMinor = price
        if !hasDate { item.date = nil; item.hasTime = false }
        if item.addedBy == nil { item.addedBy = store.data.currentUserID }
        store.saveItem(item, in: trip.id)
        dismiss()
    }

    /// Looks the place up with Apple Maps, near the trip's other pins when there are some.
    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searching = true
        searchFailed = false
        defer { searching = false }
        let request = MKLocalSearch.Request()
        let pins = trip.items.compactMap(\.place)
        if let first = pins.first {
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                                                latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        } else {
            request.naturalLanguageQuery = "\(query) \(trip.destination)"
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems.prefix(6).map { item in
                let coordinate = item.placemark.coordinate
                return Place(name: item.name ?? query,
                             address: item.placemark.title ?? "",
                             latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
            searchFailed = results.isEmpty
        } catch {
            results = []
            searchFailed = true
        }
    }
}
