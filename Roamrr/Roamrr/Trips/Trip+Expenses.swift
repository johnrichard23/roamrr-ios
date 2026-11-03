import Foundation
import RoamrrDesign

extension Trip {
    /// Your part of everything spent so far; nil before the first expense.
    func yourShare(me: AvatarMember) -> Decimal? {
        spent == nil ? nil : expenses.reduce(0) { $0 + share(of: $1, me: me) }
    }

    /// Your part of one expense.
    func share(of expense: Expense, me: AvatarMember) -> Decimal {
        if expense.split.isEmpty { return expense.amount / Decimal(peopleCount) }
        return expense.split.first { $0.member == me }?.amount ?? 0
    }

    /// Adds an expense and moves everyone's balance by what it changes: the payer is owed the
    /// amount, and each person owes their part.
    mutating func add(_ expense: Expense, me: AvatarMember) {
        expenses.append(expense)
        apply(change(for: expense), me: me)
    }

    /// Who each expense moves money between: the payer is owed the amount, each person owes their part.
    private func change(for expense: Expense) -> [AvatarMember: Decimal] {
        var change: [AvatarMember: Decimal] = [expense.payer: expense.amount]
        if expense.split.isEmpty {
            let part = expense.amount / Decimal(peopleCount)
            for person in members { change[person, default: 0] -= part }
        } else {
            for share in expense.split { change[share.member, default: 0] -= share.amount }
        }
        return change
    }

    /// Whether you may edit or delete it: you added it, or you own the trip.
    func canChange(_ expense: Expense, me: AvatarMember) -> Bool {
        expense.payer == me || owner == nil || owner == me
    }

    /// Swaps an expense for its edited version and moves balances by the difference.
    mutating func replace(_ old: Expense, with new: Expense, me: AvatarMember) {
        guard let index = expenses.firstIndex(where: { $0.id == old.id }) else { return }
        expenses[index] = new
        var difference = change(for: new)
        for (person, amount) in change(for: old) { difference[person, default: 0] -= amount }
        apply(difference, me: me)
    }

    /// Removes an expense and undoes what it did to the balances.
    mutating func remove(_ expense: Expense, me: AvatarMember) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses.remove(at: index)
        apply(change(for: expense).mapValues { -$0 }, me: me)
    }

    /// Records a payment: what the payer owed shrinks and what the payee is owed shrinks by the same amount.
    mutating func record(_ payment: Payment, me: AvatarMember) {
        payments.append(payment)
        apply([payment.from: payment.amount, payment.to: -payment.amount], me: me)
    }

    /// Moves everyone's balance by `change`, then works out the suggested payments again.
    private mutating func apply(_ change: [AvatarMember: Decimal], me: AvatarMember) {
        let people = [me] + members
        var net: [AvatarMember: Decimal] = Dictionary(
            standings.map { ($0.member, $0.amount) }, uniquingKeysWith: { first, _ in first }
        )
        for person in people where net[person] == nil { net[person] = 0 }
        for (person, amount) in change { net[person, default: 0] += amount }
        standings = people.map { Standing(member: $0, amount: net[$0] ?? 0) }
        balance = net[me] ?? 0
        settlements = Self.settle(standings)
    }

    /// The fewest-step payments that clear every balance: the biggest debtor pays the biggest creditor.
    private static func settle(_ standings: [Standing]) -> [Settlement] {
        var owed = standings.filter { $0.amount > 0 }.sorted { $0.amount > $1.amount }.map { ($0.member, $0.amount) }
        var owing = standings.filter { $0.amount < 0 }.sorted { $0.amount < $1.amount }.map { ($0.member, -$0.amount) }
        var result: [Settlement] = []
        while let creditor = owed.first, let debtor = owing.first {
            let amount = min(creditor.1, debtor.1)
            result.append(Settlement(from: debtor.0, to: creditor.0, amount: amount))
            owed[0].1 -= amount
            owing[0].1 -= amount
            if owed[0].1 == 0 { owed.removeFirst() }
            if owing[0].1 == 0 { owing.removeFirst() }
        }
        return result
    }
}
