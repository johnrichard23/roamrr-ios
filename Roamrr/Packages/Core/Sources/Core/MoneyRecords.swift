/// An expense as the balance calculation sees it: who paid, the total in the trip
/// currency, and each member's share. Deleted rows are ignored.
public struct ExpenseRecord: Sendable, Equatable {
    public var payer: String
    public var amountMinor: Int64
    public var shares: [String: Int64]
    public var isDeleted: Bool

    public init(payer: String, amountMinor: Int64, shares: [String: Int64], isDeleted: Bool) {
        self.payer = payer
        self.amountMinor = amountMinor
        self.shares = shares
        self.isDeleted = isDeleted
    }
}

/// A payment one member made to another. Deleted rows are ignored.
public struct SettlementRecord: Sendable, Equatable {
    public var from: String
    public var to: String
    public var amountMinor: Int64
    public var isDeleted: Bool

    public init(from: String, to: String, amountMinor: Int64, isDeleted: Bool) {
        self.from = from
        self.to = to
        self.amountMinor = amountMinor
        self.isDeleted = isDeleted
    }
}

/// One suggested payment from the simplified list.
public struct Payment: Sendable, Equatable {
    public var from: String
    public var to: String
    public var amountMinor: Int64

    public init(from: String, to: String, amountMinor: Int64) {
        self.from = from
        self.to = to
        self.amountMinor = amountMinor
    }
}
