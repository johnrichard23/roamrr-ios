import Foundation
import Observation
import RoamrrDesign

/// The state of the "Record payment" sheet: who paid who, how much, how, then a "recorded" step.
@Observable
final class RecordPaymentViewModel {
    static let stepCount = 3

    let tripID: Trip.ID
    let people: [AvatarMember]
    let me: AvatarMember
    let today: Date
    private let settlements: [Settlement]

    private(set) var step = 1
    private(set) var recorded: Payment?
    var from: AvatarMember
    var to: AvatarMember
    var amountText = ""
    var method: PaymentMethod = .cash
    var date: Date
    var note = ""
    /// The amount the pad was last filled with for you, so a changed pair can refill it but typed digits stay.
    private var prefilled = ""

    init(trip: Trip, me: AvatarMember, today: Date, seed: Settlement?) {
        let people = [me] + trip.members
        self.tripID = trip.id
        self.people = people
        self.me = me
        self.today = today
        self.settlements = trip.settlements
        self.date = min(max(today, trip.start), trip.end)
        let first = seed ?? trip.settlements.first
        let payer = first?.from ?? me
        self.from = payer
        self.to = first?.to ?? people.first { $0 != payer } ?? payer
        fill()
    }

    // MARK: Steps

    var isFirstStep: Bool { step == 1 }
    var isLastStep: Bool { step == Self.stepCount }

    var hasChanges: Bool { amountText != prefilled || !note.isEmpty }

    func back() {
        guard step > 1 else { return }
        step -= 1
    }

    func next() {
        if step == 2, amount == 0 { return }
        if step == 1 { fill() }
        if step < Self.stepCount { step += 1 }
    }

    // MARK: Who

    func choosePayer(_ person: AvatarMember) {
        from = person
        if to == person { to = people.first { $0 != person } ?? person }
    }

    func chooseReceiver(_ person: AvatarMember) {
        to = person
        if from == person { from = people.first { $0 != person } ?? person }
    }

    // MARK: Amount

    var amount: Decimal { Decimal(string: amountText) ?? 0 }

    /// What the suggested payments say this pair should pay, if they list one.
    private var suggested: Decimal? {
        settlements.first { $0.from == from && $0.to == to }?.amount
    }

    /// "Settles Migs with you" when the amount clears what this pair owes, otherwise nil.
    var hint: String? {
        guard let suggested, suggested == amount else { return nil }
        if from == me { return "Settles you with \(name(to))" }
        if to == me { return "Settles \(name(from)) with you" }
        return "Settles \(name(from)) with \(name(to))"
    }

    /// Puts the suggested amount on the pad, unless the person already typed their own.
    private func fill() {
        guard amountText == prefilled else { return }
        amountText = suggested.map { "\($0)" } ?? ""
        prefilled = amountText
    }

    // MARK: Result

    func record() -> Payment {
        let payment = Payment(
            id: UUID(), from: from, to: to, amount: amount, method: method, date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines), isPending: true
        )
        recorded = payment
        return payment
    }

    /// "You", or the first name.
    func name(_ person: AvatarMember) -> String {
        person == me ? "You" : person.name.split(separator: " ").first.map(String.init) ?? person.name
    }
}
