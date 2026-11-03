import Foundation

/// How an expense is divided.
enum SplitMode: String, Codable, Hashable {
    /// Evenly per head: someone "for 2" carries two shares.
    case equal
    /// Exact amounts typed per person, in the expense's own currency.
    case custom
}

/// One person's part of an expense. For `.equal` the weight is their party
/// size; for `.custom` it's the exact amount they owe in the expense currency.
struct Share: Hashable, Codable {
    var personID: UUID
    var weight: Int64
}

/// Something someone paid for the group.
struct Expense: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var date: Date
    var kind: CostKind
    var payerID: UUID
    /// What was paid, in the currency it was paid in.
    var amount: Money
    /// Optional receipt details, same currency as `amount`.
    var subtotalMinor: Int64?
    var taxMinor: Int64?
    var tipMinor: Int64?
    /// 1 unit of `amount.currency` = `rate` units of the trip currency.
    /// Nil when the expense is already in the trip currency.
    var rate: Decimal?
    /// `amount` in the trip currency, fixed when the expense is saved.
    var tripAmountMinor: Int64
    var splitMode: SplitMode
    var shares: [Share]
    var notes: String
    /// Filled in from a receipt scan (the picture itself is never kept).
    var fromReceipt: Bool
    var place: Place?

    init(id: UUID = UUID(), title: String, date: Date, kind: CostKind = .other, payerID: UUID, amount: Money,
         subtotalMinor: Int64? = nil, taxMinor: Int64? = nil, tipMinor: Int64? = nil,
         rate: Decimal? = nil, tripCurrency: String, splitMode: SplitMode = .equal, shares: [Share],
         notes: String = "", fromReceipt: Bool = false, place: Place? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.kind = kind
        self.payerID = payerID
        self.amount = amount
        self.subtotalMinor = subtotalMinor
        self.taxMinor = taxMinor
        self.tipMinor = tipMinor
        self.rate = amount.currency == tripCurrency ? nil : rate
        self.tripAmountMinor = Conversion.convert(amount.minor, from: amount.currency, to: tripCurrency, rate: rate ?? 1)
        self.splitMode = splitMode
        self.shares = shares
        self.notes = notes
        self.fromReceipt = fromReceipt
        self.place = place
    }

    /// What each person owes for this expense, in the trip currency. Always
    /// adds up exactly to `tripAmountMinor`.
    var owedInTripCurrency: [UUID: Int64] {
        Ledger.allocate(tripAmountMinor, weights: shares.map { ($0.personID, $0.weight) })
    }

    /// What each person owes in the expense's own currency.
    var owedInOwnCurrency: [UUID: Int64] {
        if splitMode == .custom {
            return Dictionary(shares.map { ($0.personID, $0.weight) }, uniquingKeysWith: +)
        }
        return Ledger.allocate(amount.minor, weights: shares.map { ($0.personID, $0.weight) })
    }

    var participantIDs: [UUID] { shares.map(\.personID) }

    /// For a custom split: whether the typed amounts add up to the total.
    var customSharesMatchTotal: Bool {
        splitMode == .equal || shares.reduce(0) { $0 + $1.weight } == amount.minor
    }
}

/// Where one person stands on a trip, in the trip currency.
struct PersonBalance: Identifiable, Hashable {
    var id: UUID { personID }
    let personID: UUID
    /// Paid for the group, plus repayments they made.
    let paid: Int64
    /// Their shares of expenses, plus repayments they received.
    let owed: Int64
    /// Positive: the group owes them. Negative: they owe the group.
    var net: Int64 { paid - owed }
}

/// A suggested repayment.
struct Transfer: Hashable, Identifiable {
    var id: String { "\(fromID)-\(toID)-\(amountMinor)" }
    let fromID: UUID
    let toID: UUID
    let amountMinor: Int64
}

enum Ledger {
    /// Splits `total` in proportion to the weights so the parts add up
    /// exactly. Leftover cents go to the largest remainders, ties to whoever
    /// is listed first.
    static func allocate(_ total: Int64, weights: [(UUID, Int64)]) -> [UUID: Int64] {
        let positive = weights.filter { $0.1 > 0 }
        let sum = positive.reduce(Int64(0)) { $0 + $1.1 }
        guard sum > 0 else { return [:] }
        let sign: Int64 = total < 0 ? -1 : 1
        let magnitude = total.magnitude > UInt64(Int64.max) ? Int64.max : Int64(total.magnitude)
        var parts: [(id: UUID, base: Int64, remainder: Int64, order: Int)] = []
        for (index, (id, weight)) in positive.enumerated() {
            // magnitude * weight / sum, without overflowing.
            let product = magnitude.multipliedFullWidth(by: weight)
            let (quotient, remainder) = sum.dividingFullWidth(product)
            parts.append((id, quotient, remainder, index))
        }
        var leftover = magnitude - parts.reduce(0) { $0 + $1.base }
        let order = parts.indices.sorted {
            parts[$0].remainder != parts[$1].remainder ? parts[$0].remainder > parts[$1].remainder : parts[$0].order < parts[$1].order
        }
        var index = 0
        while leftover > 0 && !order.isEmpty {
            parts[order[index % order.count]].base += 1
            leftover -= 1
            index += 1
        }
        var result: [UUID: Int64] = [:]
        for part in parts { result[part.id, default: 0] += part.base * sign }
        return result
    }

    /// Each member's balance over all expenses and recorded repayments.
    static func balances(for trip: Trip) -> [PersonBalance] {
        var paid: [UUID: Int64] = [:]
        var owed: [UUID: Int64] = [:]
        for expense in trip.expenses {
            paid[expense.payerID, default: 0] += expense.tripAmountMinor
            for (id, amount) in expense.owedInTripCurrency { owed[id, default: 0] += amount }
        }
        for payment in trip.payments {
            paid[payment.fromID, default: 0] += payment.amountMinor
            owed[payment.toID, default: 0] += payment.amountMinor
        }
        var ids = trip.members.map(\.personID)
        for id in Set(paid.keys).union(owed.keys).sorted(by: { $0.uuidString < $1.uuidString }) where !ids.contains(id) {
            ids.append(id)
        }
        return ids.map { PersonBalance(personID: $0, paid: paid[$0] ?? 0, owed: owed[$0] ?? 0) }
    }

    /// A short list of repayments that settles everyone: the biggest debtor
    /// pays the biggest creditor, and so on. At most one fewer payment than
    /// people with a balance.
    static func settle(_ balances: [PersonBalance]) -> [Transfer] {
        var creditors = balances.enumerated().filter { $0.element.net > 0 }.map { (order: $0.offset, id: $0.element.personID, amount: $0.element.net) }
        var debtors = balances.enumerated().filter { $0.element.net < 0 }.map { (order: $0.offset, id: $0.element.personID, amount: -$0.element.net) }
        creditors.sort { $0.amount != $1.amount ? $0.amount > $1.amount : $0.order < $1.order }
        debtors.sort { $0.amount != $1.amount ? $0.amount > $1.amount : $0.order < $1.order }
        var transfers: [Transfer] = []
        var c = 0, d = 0
        while c < creditors.count && d < debtors.count {
            let amount = min(creditors[c].amount, debtors[d].amount)
            if amount > 0 {
                transfers.append(Transfer(fromID: debtors[d].id, toID: creditors[c].id, amountMinor: amount))
            }
            creditors[c].amount -= amount
            debtors[d].amount -= amount
            if creditors[c].amount == 0 { c += 1 }
            if debtors[d].amount == 0 { d += 1 }
        }
        return transfers
    }

    static func suggestedRepayments(for trip: Trip) -> [Transfer] {
        settle(balances(for: trip))
    }

    /// Total spent on the trip, in the trip currency.
    static func totalSpent(_ trip: Trip) -> Int64 {
        trip.expenses.reduce(0) { $0 + $1.tripAmountMinor }
    }

    /// Spending per traveler for each kind of cost, to set against the estimate.
    static func actualPerPerson(_ trip: Trip, kind: CostKind) -> Int64 {
        let spent = trip.expenses.filter { $0.kind == kind }.reduce(Int64(0)) { $0 + $1.tripAmountMinor }
        return Estimator.divideRounded(spent, by: Int64(max(1, trip.expectedTravelers)))
    }

    /// The equal-split shares for a set of people on a trip (party sizes as weights).
    static func equalShares(_ ids: [UUID], on trip: Trip) -> [Share] {
        ids.map { Share(personID: $0, weight: Int64(trip.partySize(of: $0))) }
    }
}
