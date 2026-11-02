import Foundation
import Observation
import RoamrrDesign

/// How an expense is divided between people.
enum SplitMode: String, CaseIterable, Identifiable {
    case equally = "Equally"
    case amounts = "Amounts"
    case percent = "Percent"
    case shares = "Shares"

    var id: String { rawValue }

    /// "split equally", for the line under the details.
    var phrase: String {
        switch self {
        case .equally: "split equally"
        case .amounts: "split by amounts"
        case .percent: "split by percent"
        case .shares: "split by shares"
        }
    }
}

/// The state of the "Add expense" sheet: four steps, each one answer. Nothing is lost going back.
@Observable
final class AddExpenseViewModel {
    static let stepCount = 4

    let people: [AvatarMember]
    let me: AvatarMember
    let today: Date

    private(set) var step = 1
    var amountText = ""
    var payer: AvatarMember
    var mode: SplitMode = .equally
    var included: Set<String>
    var exactText: [String: String] = [:]
    var percentText: [String: String] = [:]
    var shareCounts: [String: Int]
    var title = ""
    var category: ExpenseCategory = .food
    var date: Date
    /// Set when someone taps Next on a split that does not add up, so the line turns red.
    var showSplitProblem = false

    init(trip: Trip, me: AvatarMember, today: Date) {
        let people = [me] + trip.members
        self.people = people
        self.me = me
        self.today = today
        self.payer = me
        self.included = Set(people.map(\.id))
        self.shareCounts = Dictionary(uniqueKeysWithValues: people.map { ($0.id, 1) })
        self.date = min(max(today, trip.start), trip.end)
    }

    /// Opens the same steps filled in with an existing expense, to edit it.
    convenience init(trip: Trip, me: AvatarMember, today: Date, editing expense: Expense) {
        self.init(trip: trip, me: me, today: today)
        amountText = "\(expense.amount)"
        payer = expense.payer
        title = expense.title
        category = expense.category
        date = expense.date
        guard !expense.split.isEmpty else { return }
        included = Set(expense.split.map(\.member.id))
        if expense.isEqualSplit {
            mode = .equally
        } else {
            mode = .amounts
            exactText = Dictionary(uniqueKeysWithValues: expense.split.map { ($0.member.id, "\($0.amount)") })
        }
    }

    /// Starts from an idea the group has done: its name, category, and what it costs everyone.
    func prefill(title: String, perPerson: Decimal?, category: ExpenseCategory) {
        self.title = title
        self.category = category
        if let perPerson { amountText = "\(perPerson * Decimal(people.count))" }
    }

    // MARK: Steps

    var isFirstStep: Bool { step == 1 }
    var isLastStep: Bool { step == Self.stepCount }

    /// Whether leaving the sheet would throw something away.
    var hasChanges: Bool { !amountText.isEmpty || !title.isEmpty }

    func back() {
        guard step > 1 else { return }
        step -= 1
    }

    /// Moves on if this step is ready. On the split step it explains the problem instead.
    func next() {
        switch step {
        case 1 where amount == 0: return
        case 3 where splitProblem != nil:
            showSplitProblem = true
            return
        default: break
        }
        showSplitProblem = false
        if step < Self.stepCount { step += 1 }
    }

    var canFinish: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0 }

    // MARK: Amount

    var amount: Decimal { Decimal(string: amountText) ?? 0 }

    func press(_ key: String) {
        AmountInput.press(key, on: &amountText)
    }

    // MARK: Split

    /// What each person owes under the chosen split, as far as it can be worked out.
    var shares: [ExpenseShare] {
        switch mode {
        case .equally:
            return weighted(people.filter { included.contains($0.id) }.map { ($0, 1) })
        case .amounts:
            return people.map { ExpenseShare(member: $0, amount: parse(exactText[$0.id])) }
        case .percent:
            return weighted(people.map { ($0, parse(percentText[$0.id])) })
        case .shares:
            return weighted(people.map { ($0, Decimal(shareCounts[$0.id] ?? 0)) })
        }
    }

    /// Why the split does not add up, or nil when it does.
    var splitProblem: String? {
        switch mode {
        case .equally:
            return included.isEmpty ? "Pick at least one person" : nil
        case .amounts:
            let left = amount - shares.reduce(0) { $0 + $1.amount }
            if left > 0 { return "\(Money.peso(left)) left to assign" }
            if left < 0 { return "\(Money.peso(-left)) over" }
            return nil
        case .percent:
            let left = 100 - people.reduce(Decimal(0)) { $0 + parse(percentText[$1.id]) }
            if left > 0 { return "\(left.formatted())% left to assign" }
            if left < 0 { return "\((-left).formatted())% over" }
            return nil
        case .shares:
            return shareCounts.values.reduce(0, +) == 0 ? "Give at least one person a share" : nil
        }
    }

    /// Each person's amount as a part of the total, rounded to centavos; any left-over centavo goes to the first person with a part.
    /// People with no part are left out.
    private func weighted(_ entries: [(AvatarMember, Decimal)]) -> [ExpenseShare] {
        let total = entries.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        let counted = entries.filter { $0.1 > 0 }
        var amounts = counted.map { (amount * $0.1 / total).roundedToCentavos }
        amounts[0] += amount - amounts.reduce(0, +)
        return zip(counted, amounts).map { ExpenseShare(member: $0.0.0, amount: $0.1) }
    }

    private func parse(_ text: String?) -> Decimal {
        Decimal(string: text ?? "") ?? 0
    }

    /// What one person owes under the current split.
    func share(for person: AvatarMember) -> Decimal? {
        shares.first { $0.member == person }?.amount
    }

    // MARK: Editing

    /// "Equally between 5", for the review row.
    var splitSummary: String {
        switch mode {
        case .equally: "Equally between \(included.count)"
        case .amounts: "By amounts"
        case .percent: "By percent"
        case .shares: "By shares"
        }
    }

    /// The expense as edited: same id and history, with one history entry for each thing that changed.
    func edited(from old: Expense) -> Expense {
        var new = old
        new.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        new.category = category
        new.amount = amount
        new.payer = payer
        new.date = date
        new.split = shares
        new.isPending = true
        var entries: [ExpenseChange] = []
        func note(_ what: String, _ from: String, _ to: String) {
            entries.append(ExpenseChange(id: UUID(), who: me, title: "You changed \(what)", detail: "\(from) → \(to) · \(today.dayMonth)", date: today))
        }
        if old.amount != new.amount { note("the amount", Money.peso(old.amount), Money.peso(new.amount)) }
        if old.payer != new.payer { note("who paid", old.payer.name, new.payer.name) }
        if old.split != new.split, !(old.split.isEmpty && new.isEqualSplit && new.split.count == people.count) {
            note("the split", old.isEqualSplit ? "Equal" : "Custom", new.isEqualSplit ? "Equal" : "Custom")
        }
        if old.title != new.title || old.category != new.category {
            note("the details", old.title, new.title == old.title ? new.category.rawValue : new.title)
        }
        if !Calendar.current.isDate(old.date, inSameDayAs: new.date) { note("the date", old.date.dayMonth, new.date.dayMonth) }
        new.history = entries.reversed() + old.history
        return new
    }

    /// Whether anything differs from the expense being edited.
    func hasEdits(from old: Expense) -> Bool {
        let new = edited(from: old)
        return new.history.count != old.history.count
    }

    // MARK: Result

    func makeExpense() -> Expense {
        Expense(
            id: UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: category,
            amount: amount, payer: payer, date: date, isPending: true, split: shares
        )
    }
}

extension Decimal {
    /// Rounded to two decimal places.
    var roundedToCentavos: Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}
