import Foundation
import Observation
import RoamrrDesign

/// The state of the "Join a trip" sheet: type a code (T3), then look at the trip and confirm (T4).
@Observable
final class JoinTripViewModel {
    private let service = MockJoinService()
    private let store: TripsStore

    var code = "" {
        didSet {
            let cleaned = MockJoinService.normalize(code)
            if cleaned != code { code = cleaned }
            if failure != nil, cleaned != oldValue { failure = nil }
        }
    }

    private(set) var failure: JoinFailure?
    private(set) var preview: JoinPreview?
    private(set) var isWorking = false

    init(store: TripsStore, code: String? = nil) {
        self.store = store
        if let code { self.code = MockJoinService.normalize(code) }
    }

    var canContinue: Bool { code.count == 8 && !isWorking && failure != .offline }

    /// "K7Q2-M9XD", as the code is shown elsewhere.
    var spacedCode: String {
        code.count > 4 ? String(code.prefix(4)) + "-" + String(code.dropFirst(4)) : code
    }

    /// Looks the code up. Does nothing while a lookup is already running.
    @MainActor
    func lookUp() async {
        guard canContinue else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }
        do {
            preview = try await service.preview(for: code, among: store.trips, me: store.me)
        } catch let error as JoinFailure {
            failure = error
        } catch {
            failure = nil
        }
    }

    func backToCode() {
        preview = nil
    }

    func clear() {
        code = ""
        failure = nil
    }

    /// Adds you to the trip and returns it. Joining needs a connection, so this is where the mock would fail offline.
    @MainActor
    func join() async -> Trip.ID? {
        guard let preview, !isWorking else { return nil }
        if preview.alreadyOn { return preview.trip.id }
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(350))
        var trip = preview.trip
        trip.owner = preview.invitedBy
        trip.joined[store.me.id] = store.today
        trip.newCount = 0
        store.add(trip)
        return trip.id
    }
}
