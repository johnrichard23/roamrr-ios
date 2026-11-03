import Foundation
import RoamrrDesign

/// What an expense was for. Drives its icon and the filter chips.
enum ExpenseCategory: String, CaseIterable, Hashable {
    case food = "Food"
    case transport = "Transport"
    case stay = "Stay"
    case activity = "Activity"
    case shopping = "Shopping"
    case car = "Car"

    var symbol: String {
        switch self {
        case .food: "cup.and.saucer"
        case .transport: "bus"
        case .stay: "bed.double"
        case .activity: "ticket"
        case .shopping: "bag"
        case .car: "car"
        }
    }
}

/// A shared cost on a trip. Mock data for now.
struct Expense: Identifiable, Hashable {
    let id: UUID
    var title: String
    var category: ExpenseCategory
    var amount: Decimal
    var payer: AvatarMember
    var date: Date
    /// Added on this phone and not sent yet.
    var isPending = false
    /// What each person owes of it. Empty means split equally between everyone on the trip.
    var split: [ExpenseShare] = []
    /// Edits made after it was added, newest first.
    var history: [ExpenseChange] = []

    /// Whether everyone in it owes the same part.
    var isEqualSplit: Bool {
        guard let first = split.first?.amount else { return true }
        return split.allSatisfy { abs($0.amount - first) <= 0.01 }
    }
}

/// One edit in an expense's history: who made it, what changed, and from what to what.
struct ExpenseChange: Identifiable, Hashable {
    let id: UUID
    let who: AvatarMember
    let title: String
    let detail: String
    let date: Date
}

/// One person's part of an expense.
struct ExpenseShare: Hashable {
    let member: AvatarMember
    let amount: Decimal
}
