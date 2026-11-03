import SwiftUI

/// Add or change an expense: what, how much, who paid, and who shares it.
struct ExpenseFormView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    private let original: Expense?
    private let fromScan: Bool

    @State private var title: String
    @State private var date: Date
    @State private var kind: CostKind
    @State private var payerID: UUID?
    @State private var currency: String
    @State private var amount: Int64?
    @State private var subtotal: Int64?
    @State private var tax: Int64?
    @State private var tip: Int64?
    @State private var rateText: String
    @State private var splitMode: SplitMode
    @State private var included: Set<UUID>
    @State private var custom: [UUID: Int64?]
    @State private var notes: String
    @State private var showDetails: Bool
    @State private var confirmDelete = false

    init(trip: Trip, expense: Expense?, scan: ReceiptDraft?) {
        self.trip = trip
        original = expense
        fromScan = scan != nil || (expense?.fromReceipt ?? false)
        let everyone = trip.comingMemberIDs
        if let expense {
            _title = State(initialValue: expense.title)
            _date = State(initialValue: expense.date)
            _kind = State(initialValue: expense.kind)
            _payerID = State(initialValue: expense.payerID)
            _currency = State(initialValue: expense.amount.currency)
            _amount = State(initialValue: expense.amount.minor)
            _subtotal = State(initialValue: expense.subtotalMinor)
            _tax = State(initialValue: expense.taxMinor)
            _tip = State(initialValue: expense.tipMinor)
            _rateText = State(initialValue: expense.rate.map(Conversion.rateText) ?? "")
            _splitMode = State(initialValue: expense.splitMode)
            _included = State(initialValue: Set(expense.participantIDs))
            let customShares: [UUID: Int64?] = expense.splitMode == .custom
                ? Dictionary(expense.shares.map { ($0.personID, Optional($0.weight)) }, uniquingKeysWith: { a, _ in a })
                : [:]
            _custom = State(initialValue: customShares)
            _notes = State(initialValue: expense.notes)
            _showDetails = State(initialValue: expense.subtotalMinor != nil || expense.taxMinor != nil || expense.tipMinor != nil)
        } else {
            let scanCurrency = scan?.currency ?? trip.currency
            _title = State(initialValue: scan?.merchant ?? "")
            _date = State(initialValue: scan?.date ?? Date())
            _kind = State(initialValue: .food)
            _payerID = State(initialValue: nil)
            _currency = State(initialValue: scanCurrency)
            _amount = State(initialValue: scan?.totalMinor)
            _subtotal = State(initialValue: scan?.subtotalMinor)
            _tax = State(initialValue: scan?.taxMinor)
            _tip = State(initialValue: scan?.tipMinor)
            _rateText = State(initialValue: Conversion.sampleRate(from: scanCurrency, to: trip.currency).map(Conversion.rateText) ?? "")
            _splitMode = State(initialValue: .equal)
            _included = State(initialValue: Set(everyone))
            _custom = State(initialValue: [:])
            _notes = State(initialValue: "")
            _showDetails = State(initialValue: scan != nil && (scan?.subtotalMinor != nil || scan?.taxMinor != nil || scan?.tipMinor != nil))
        }
    }

    private var people: [UUID] {
        var ids = trip.members.map(\.personID)
        for id in included where !ids.contains(id) { ids.append(id) }
        return ids
    }

    private var rate: Decimal? {
        currency == trip.currency ? 1 : Conversion.parseRate(rateText)
    }

    /// The expense as it would be saved, or nil with what's missing.
    private var built: (expense: Expense?, problem: String?) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return (nil, "Add what it was for.") }
        guard let amount, amount > 0 else { return (nil, "Add the amount.") }
        guard let rate else { return (nil, "Add the exchange rate.") }
        let payer = payerID ?? store.data.currentUserID
        let shares: [Share]
        switch splitMode {
        case .equal:
            let ids = people.filter { included.contains($0) }
            guard !ids.isEmpty else { return (nil, "Pick who shares it.") }
            shares = Ledger.equalShares(ids, on: trip)
        case .custom:
            shares = people.compactMap { id in
                guard let value = custom[id] ?? nil, value > 0 else { return nil }
                return Share(personID: id, weight: value)
            }
            let sum = shares.reduce(Int64(0)) { $0 + $1.weight }
            guard !shares.isEmpty else { return (nil, "Type what each person owes.") }
            if sum != amount {
                let difference = Money(abs(amount - sum), currency).formatted()
                return (nil, sum < amount ? "\(difference) still to assign." : "\(difference) more than the total.")
            }
        }
        var expense = Expense(id: original?.id ?? UUID(), title: title.trimmingCharacters(in: .whitespaces), date: date, kind: kind,
                              payerID: payer, amount: Money(amount, currency),
                              subtotalMinor: showDetails ? subtotal : nil, taxMinor: showDetails ? tax : nil, tipMinor: showDetails ? tip : nil,
                              rate: rate, tripCurrency: trip.currency, splitMode: splitMode, shares: shares,
                              notes: notes, fromReceipt: fromScan, place: original?.place)
        if original?.fromReceipt == true { expense.fromReceipt = true }
        return (expense, nil)
    }

    var body: some View {
        let result = built
        NavigationStack {
            Form {
                if fromScan && original == nil {
                    Section {
                        Label("Check these against the receipt. The picture isn't kept.", systemImage: "doc.text.viewfinder")
                            .font(.subheadline)
                    }
                }
                Section {
                    TextField("What was it?", text: $title)
                        .accessibilityIdentifier("expense-title")
                    MoneyField(title: "Amount", minor: $amount, currency: currency, identifier: "expense-amount")
                    Picker("Currency", selection: $currency) {
                        ForEach(Currencies.codes, id: \.self) { Text($0).tag($0) }
                    }
                    if currency != trip.currency {
                        HStack {
                            Text("1 \(currency) =")
                            TextField("rate", text: $rateText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(trip.currency)
                        }
                        if let amount, let rate {
                            LabeledContent("On the trip ledger") {
                                Text(Money(Conversion.convert(amount, from: currency, to: trip.currency, rate: rate), trip.currency).formatted())
                                    .monospacedDigit()
                            }
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $kind) {
                        ForEach(CostKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                } footer: {
                    if currency != trip.currency {
                        Text("Use the rate on your card or bank statement for that day. It's saved with the expense so balances don't change later.")
                    }
                }

                Section {
                    Toggle("Receipt details", isOn: $showDetails.animation(gentleAnimation))
                    if showDetails {
                        MoneyField(title: "Subtotal", minor: $subtotal, currency: currency)
                        MoneyField(title: "Tax", minor: $tax, currency: currency)
                        MoneyField(title: "Tip", minor: $tip, currency: currency)
                        if let subtotal {
                            let sum = subtotal + (tax ?? 0) + (tip ?? 0)
                            if sum != amount {
                                Button("Use \(Money(sum, currency).formatted()) as the amount") { amount = sum }
                            }
                        }
                    }
                }

                Section {
                    Picker("Paid by", selection: payerBinding) {
                        ForEach(people, id: \.self) { id in
                            Text(id == store.data.currentUserID ? "You" : store.person(id).name).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("payer")
                }

                Section {
                    Picker("Split", selection: $splitMode) {
                        Text("Equally").tag(SplitMode.equal)
                        Text("Custom amounts").tag(SplitMode.custom)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("split-mode")
                    ForEach(people, id: \.self) { id in
                        splitRow(id)
                    }
                } header: {
                    Text("Split between")
                } footer: {
                    if splitMode == .equal {
                        Text("Split evenly by head. Someone coming as 2 pays two shares.")
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(1...4)
                }

                if original != nil {
                    Section {
                        Button("Delete expense", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let problem = result.problem, amount != nil || !title.isEmpty {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle(original == nil ? (fromScan ? "Scanned receipt" : "New expense") : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let expense = result.expense {
                            store.saveExpense(expense, in: trip.id)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(result.expense == nil)
                    .accessibilityIdentifier("save-expense")
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let original { store.deleteExpense(original.id, in: trip.id) }
                    dismiss()
                }
            }
            .onChange(of: currency) {
                if currency != trip.currency, let sample = Conversion.sampleRate(from: currency, to: trip.currency) {
                    rateText = Conversion.rateText(sample)
                }
            }
        }
    }

    private var payerBinding: Binding<UUID> {
        Binding(get: { payerID ?? store.data.currentUserID }, set: { payerID = $0 })
    }

    @ViewBuilder
    private func splitRow(_ id: UUID) -> some View {
        let person = store.person(id)
        let size = trip.partySize(of: id)
        let name = id == store.data.currentUserID ? "You" : person.name
        switch splitMode {
        case .equal:
            let shares = Ledger.equalShares(people.filter { included.contains($0) }, on: trip)
            let owed = Ledger.allocate(amount ?? 0, weights: shares.map { ($0.personID, $0.weight) })[id]
            Button {
                if included.contains(id) { included.remove(id) } else { included.insert(id) }
            } label: {
                HStack {
                    Image(systemName: included.contains(id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(included.contains(id) ? Color.accentColor : Color.secondary)
                        .font(.title3)
                    PersonRow(person: person, title: name, subtitle: size > 1 ? "Counts as \(size)" : nil, partySize: size)
                    Spacer()
                    if let owed, included.contains(id) {
                        Text(Money(owed, currency).formatted()).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("split-\(person.firstName)")
        case .custom:
            HStack {
                PersonRow(person: person, title: name, partySize: size)
                Spacer(minLength: 8)
                MoneyField(title: "", minor: customBinding(id), currency: currency, identifier: "custom-\(person.firstName)")
                    .frame(width: 110)
            }
        }
    }

    private func customBinding(_ id: UUID) -> Binding<Int64?> {
        Binding(get: { custom[id] ?? nil }, set: { custom[id] = $0 })
    }
}
