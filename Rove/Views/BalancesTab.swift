import SwiftUI

/// Who's ahead, who's behind, and the fewest repayments that settle it.
struct BalancesTab: View {
    @Environment(TripStore.self) private var store
    let trip: Trip
    let wide: Bool
    @State private var confirming: Transfer?

    private var me: UUID { store.data.currentUserID }

    var body: some View {
        let balances = Ledger.balances(for: trip).filter { $0.paid != 0 || $0.owed != 0 || trip.member($0.personID) != nil }
        let transfers = Ledger.settle(balances)
        ScrollView {
            Group {
                if wide {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) { mine(balances); repayments(transfers) }
                        VStack(spacing: 16) { everyone(balances); history }
                    }
                } else {
                    VStack(spacing: 16) {
                        mine(balances)
                        repayments(transfers)
                        everyone(balances)
                        history
                    }
                }
            }
            .padding(16)
            .padding(.top, -8)
        }
        .confirmationDialog("Mark as paid?", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { transfer in
            Button("Mark \(Money(transfer.amountMinor, trip.currency).formatted()) as paid") {
                withAnimation { store.markPaid(transfer, in: trip.id) }
            }
            .accessibilityIdentifier("confirm-paid")
        } message: { transfer in
            Text("\(paidSentence(transfer.fromID, transfer.toID)) outside the app, like Venmo, Zelle or cash.")
        }
    }

    private func mine(_ balances: [PersonBalance]) -> some View {
        let net = balances.first { $0.personID == me }?.net ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            Text(net > 0 ? "You're owed" : net < 0 ? "You owe" : "You're all square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if net != 0 {
                Text(Money(abs(net), trip.currency).formatted())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(net > 0 ? Theme.positive : Theme.negative)
                    .accessibilityIdentifier("my-balance")
            } else {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.positive)
            }
            Text("Across \(Estimator.plural(trip.expenses.count, "expense")) in \(trip.currency).")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }

    private func repayments(_ transfers: [Transfer]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested repayments").font(.headline)
            if transfers.isEmpty {
                Label("Everyone's settled up.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.positive)
            } else {
                Text("The fewest payments that square everyone up. Pay however you like, then mark it here.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(transfers) { transfer in
                    transferRow(transfer)
                }
            }
        }
        .card()
    }

    private func transferRow(_ transfer: Transfer) -> some View {
        let from = store.person(transfer.fromID)
        let to = store.person(transfer.toID)
        let involvesMe = transfer.fromID == me || transfer.toID == me
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    Avatar(person: from, size: 30)
                        .padding(2).background(Circle().fill(Theme.inset))
                    Avatar(person: to, size: 30)
                        .padding(2).background(Circle().fill(Theme.inset))
                }
                Text(sentence(transfer))
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text(Money(transfer.amountMinor, trip.currency).formatted())
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(transfer.fromID == me ? Theme.negative : transfer.toID == me ? Theme.positive : .primary)
            }
            Button {
                confirming = transfer
            } label: {
                Text("Mark as paid").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(involvesMe ? Color.accentColor : Color.gray)
            .accessibilityIdentifier("mark-paid-\(from.firstName)-\(to.firstName)")
        }
        .padding(12)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// "Jordan pays you", "You pay Maria", "Priya pays Maria".
    private func sentence(_ transfer: Transfer) -> String {
        let to = transfer.toID == me ? "you" : store.name(transfer.toID)
        return transfer.fromID == me ? "You pay \(to)" : "\(store.name(transfer.fromID)) pays \(to)"
    }

    /// "Jordan paid you", "You paid Maria".
    private func paidSentence(_ from: UUID, _ to: UUID) -> String {
        "\(store.name(from)) paid \(to == me ? "you" : store.name(to))"
    }

    private func everyone(_ balances: [PersonBalance]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Everyone").font(.headline)
            ForEach(balances) { balance in
                let size = trip.partySize(of: balance.personID)
                HStack {
                    PersonRow(person: store.person(balance.personID),
                              title: balance.personID == me ? "You" : store.person(balance.personID).name,
                              subtitle: "Paid \(Money(balance.spent, trip.currency).formatted()) · share \(Money(balance.share, trip.currency).formatted())",
                              partySize: size)
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(balance.net == 0 ? "Even" : Money(abs(balance.net), trip.currency).formatted())
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(balance.net > 0 ? Theme.positive : balance.net < 0 ? Theme.negative : .secondary)
                        if balance.net != 0 {
                            Text(balance.net > 0 ? "is owed" : "owes").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var history: some View {
        if !trip.payments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paid back").font(.headline)
                ForEach(trip.payments.sorted { $0.date > $1.date }) { payment in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.positive)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(paidSentence(payment.fromID, payment.toID)).font(.subheadline)
                            Text(Formats.shortDay(payment.date)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money(payment.amountMinor, trip.currency).formatted()).font(.subheadline).monospacedDigit()
                        Menu {
                            Button("Undo", role: .destructive) { store.deletePayment(payment.id, in: trip.id) }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 28, height: 28)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .card()
        }
    }
}
