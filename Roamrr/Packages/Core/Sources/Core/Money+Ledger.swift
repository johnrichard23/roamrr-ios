extension Money {
    /// Net balance per member in the trip currency: paid minus owed, plus settlements
    /// sent, minus settlements received. Positive means the member is owed money.
    /// The values always add up to zero.
    public static func netBalances(
        members: [String], expenses: [ExpenseRecord], settlements: [SettlementRecord]
    ) -> [String: Int64] {
        var nets = Dictionary(uniqueKeysWithValues: members.map { ($0, Int64(0)) })
        for expense in expenses where !expense.isDeleted {
            nets[expense.payer, default: 0] += expense.amountMinor
            for (member, share) in expense.shares { nets[member, default: 0] -= share }
        }
        for settlement in settlements where !settlement.isDeleted {
            nets[settlement.from, default: 0] += settlement.amountMinor
            nets[settlement.to, default: 0] -= settlement.amountMinor
        }
        return nets
    }

    /// Fewest-effort list of payments that clears every balance, at most one fewer
    /// than the number of people. Each round pays the largest remaining debtor to the
    /// largest remaining creditor (ties by member id), then looks again at what is left.
    public static func simplify(_ balances: [String: Int64]) -> [Payment] {
        var debtors = balances.filter { $0.value < 0 }.mapValues { -$0 }
        var creditors = balances.filter { $0.value > 0 }
        var payments: [Payment] = []
        while let debtor = largest(debtors), let creditor = largest(creditors) {
            let amount = min(debtors[debtor] ?? 0, creditors[creditor] ?? 0)
            payments.append(Payment(from: debtor, to: creditor, amountMinor: amount))
            debtors[debtor, default: 0] -= amount
            creditors[creditor, default: 0] -= amount
            if debtors[debtor] == 0 { debtors[debtor] = nil }
            if creditors[creditor] == 0 { creditors[creditor] = nil }
        }
        return payments
    }

    private static func largest(_ amounts: [String: Int64]) -> String? {
        amounts.min { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }?.key
    }
}
