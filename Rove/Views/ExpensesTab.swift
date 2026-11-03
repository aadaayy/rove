import PhotosUI
import SwiftUI

/// What's been spent, who paid, and adding more.
struct ExpensesTab: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let wide: Bool
    @State private var adding = false
    @State private var editing: Expense?
    @State private var scanItem: PhotosPickerItem?
    @State private var scanned: ReceiptDraft?
    @State private var scanning = false
    @State private var scanError: String?

    private var me: UUID { store.data.currentUserID }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if wide {
                    HStack(alignment: .top, spacing: 16) {
                        summary
                        addButtons
                    }
                } else {
                    summary
                    addButtons
                }
                if let scanError {
                    Label(scanError, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline).foregroundStyle(.orange).card()
                }
                list
            }
            .padding(16)
            .padding(.top, -8)
        }
        .sheet(isPresented: $adding) { ExpenseFormView(trip: trip, expense: nil, scan: nil) }
        .sheet(item: $editing) { expense in ExpenseFormView(trip: trip, expense: expense, scan: nil) }
        .sheet(item: $scanned) { draft in ExpenseFormView(trip: trip, expense: nil, scan: draft) }
        .onChange(of: scanItem) {
            guard let item = scanItem else { return }
            scanItem = nil
            Task { await read(item) }
        }
    }

    private var summary: some View {
        let total = Ledger.totalSpent(trip)
        let mine = trip.expenses.reduce(Int64(0)) { $0 + ($1.owedInTripCurrency[me] ?? 0) }
        let paid = trip.expenses.filter { $0.payerID == me }.reduce(Int64(0)) { $0 + $1.tripAmountMinor }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                StatView(value: Money(total, trip.currency).formatted(), caption: "spent by the group")
                StatView(value: Money(mine, trip.currency).formatted(), caption: "your share")
                StatView(value: Money(paid, trip.currency).formatted(), caption: "you paid")
            }
        }
        .card()
    }

    private var addButtons: some View {
        HStack(spacing: 10) {
            Button { adding = true } label: {
                Label("Add expense", systemImage: "plus")
            }
            .buttonStyle(WideButtonStyle())
            .accessibilityIdentifier("add-expense")
            PhotosPicker(selection: $scanItem, matching: .images) {
                Label(scanning ? "Reading…" : "Scan receipt", systemImage: "doc.text.viewfinder")
            }
            .buttonStyle(WideButtonStyle(prominent: false))
            .disabled(scanning)
            .accessibilityIdentifier("scan-receipt")
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var list: some View {
        if trip.expenses.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "creditcard").font(.largeTitle).foregroundStyle(.secondary)
                Text("No expenses yet").font(.headline)
                Text("Add what you pay for the group. Rove works out who owes who.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            let sorted = trip.expenses.sorted { $0.date > $1.date }
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, expense in
                    Button { editing = expense } label: {
                        ExpenseRow(trip: trip, expense: expense)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("expense-\(expense.title)")
                    if index < sorted.count - 1 { Divider().padding(.leading, 60) }
                }
            }
            .card(padding: 0)
        }
    }

    /// Reads the receipt on the phone, then lets go of the picture.
    private func read(_ item: PhotosPickerItem) async {
        scanning = true
        scanError = nil
        defer { scanning = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                scanError = "Couldn't open that picture."
                return
            }
            let lines = try await ReceiptReader.lines(in: data)
            let draft = ReceiptParser.parse(lines: lines, defaultCurrency: trip.currency)
            if draft.isEmpty {
                scanError = "Couldn't find a total on that picture. Try a clearer photo or add it by hand."
            } else {
                scanned = draft
            }
        } catch {
            scanError = "Couldn't read that receipt. Try a clearer photo or add it by hand."
        }
    }
}

extension ReceiptDraft: Identifiable {
    var id: String { "\(merchant ?? "")-\(totalMinor ?? 0)-\(date?.timeIntervalSince1970 ?? 0)" }
}

struct ExpenseRow: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let expense: Expense

    var body: some View {
        let me = store.data.currentUserID
        let myShare = expense.owedInTripCurrency[me] ?? 0
        HStack(spacing: 12) {
            IconTile(symbol: expense.kind.symbol, color: Theme.color(for: expense.kind))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(expense.title).foregroundStyle(.primary).lineLimit(1)
                    if expense.fromReceipt {
                        Image(systemName: "doc.text.viewfinder").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("\(store.name(expense.payerID)) paid · \(Formats.shortDay(expense.date))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.formatted()).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
                if expense.amount.currency != trip.currency {
                    Text(Money(expense.tripAmountMinor, trip.currency).formatted()).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                } else if expense.payerID == me {
                    Text("you lent \(Money(expense.tripAmountMinor - myShare, trip.currency).formatted())")
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.positive)
                } else if myShare > 0 {
                    Text("your share \(Money(myShare, trip.currency).formatted())")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Text("not in this one").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
