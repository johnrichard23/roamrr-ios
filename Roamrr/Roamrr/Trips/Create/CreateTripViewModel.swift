import Foundation
import Observation
import PhotosUI
import RoamrrDesign
import SwiftUI

/// The state of the "New trip" sheet: the form, then the "trip created" step in the same sheet.
@Observable
final class CreateTripViewModel {
    var name = ""
    var start: Date?
    var end: Date?
    var cover: CoverStyle = .sea
    var photo: Data?
    var pickerItem: PhotosPickerItem? {
        didSet { Task { await loadPhoto() } }
    }

    /// The first answer: "Just me" (true) or "With friends" (false). Nil until chosen.
    var solo: Bool?
    /// What a solo traveller means to spend per day, as typed. Optional.
    var dailyBudgetText = ""

    /// Set once the trip exists; the sheet then shows the invite step, or closes for a solo trip.
    private(set) var created: Trip?

    var canCreate: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The typed daily budget as a number, ignoring commas and the peso sign; nil when empty or zero.
    var dailyBudget: Decimal? {
        let digits = dailyBudgetText.filter(\.isNumber)
        guard let value = Decimal(string: digits), value > 0 else { return nil }
        return value
    }

    @MainActor
    private func loadPhoto() async {
        guard let pickerItem, let data = try? await pickerItem.loadTransferable(type: Data.self) else { return }
        photo = data
    }

    func chooseIllustration(_ style: CoverStyle) {
        cover = style
        photo = nil
        pickerItem = nil
    }

    func create(in store: TripsStore) {
        guard canCreate, created == nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = start ?? store.today
        var trip = Trip(
            id: UUID(), title: trimmed, destination: trimmed,
            start: first, end: end ?? first, cover: cover, coverPhoto: photo,
            members: [], balance: nil, newCount: 0, code: Self.makeCode()
        )
        trip.datesDecided = start != nil
        if solo == true {
            // Nobody to vote with or finalise for: ideas go straight onto the plan.
            trip.solo = true
            trip.stage = .final
            trip.dailyBudget = dailyBudget
        } else {
            trip.stage = .planning
        }
        store.add(trip)
        created = trip
    }

    /// Eight characters in two groups, without letters that look like digits.
    private static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let characters = (0..<8).map { _ in alphabet.randomElement() ?? "A" }
        return String(characters[0..<4]) + "-" + String(characters[4..<8])
    }
}
