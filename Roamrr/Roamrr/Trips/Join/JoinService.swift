import Foundation
import RoamrrDesign

/// Why a code could not be used. Each one has plain words and one next step on the join sheet.
enum JoinFailure: Error, Equatable {
    case notFound
    case expired
    case usedUp
    case full(trip: String)
    case archived(trip: String)
    case removed(trip: String)
    case offline

    var message: String {
        switch self {
        case .notFound: "We couldn’t find that code. Check each letter and try again. O and 0 look alike."
        case .expired: "This code has expired. Ask your friend to share a new one."
        case .usedUp: "This code has been used up. Ask your friend to share a new one."
        case let .full(trip): "\(trip) is full. Ask the owner to make room."
        case let .archived(trip): "\(trip) is archived, so no one can join it now."
        case let .removed(trip): "You were removed from \(trip), so this code won’t work for you."
        case .offline: "You’re offline. Joining a trip needs a connection; your code is kept."
        }
    }

    /// Only a mistyped code turns the boxes red; the rest are about the trip, not the letters.
    var isCodeProblem: Bool { self == .notFound || self == .expired || self == .usedUp }
}

/// What a valid code leads to: the trip, who invited you, and whether it names a spot someone added for you.
struct JoinPreview {
    var trip: Trip
    var invitedBy: AvatarMember
    /// The placeholder this invite is for: "Bea added you as Alex".
    var asPlaceholder: String?
    var alreadyOn: Bool
}

/// Looks a code up. Mock for now: a few codes that each end in a different way.
struct MockJoinService {
    /// Codes that work, and what they are, so the flow can be walked in the simulator.
    static let samples: [String: (trip: Trip, inviter: AvatarMember, placeholder: String?)] = [
        "H7KD3MQ9": (
            Trip(
                id: UUID(), title: "Tokyo in December", destination: "Tokyo",
                start: MockData.date(2026, 12, 14), end: MockData.date(2026, 12, 21), cover: .city,
                members: [MockData.ana, MockData.jo, MockData.migs], balance: nil, newCount: 0, code: "H7KD-3MQ9",
                place: "Tokyo", owner: MockData.ana
            ), MockData.ana, nil
        ),
        "P4LC2E8R": (
            Trip(
                id: UUID(), title: "Bohol countryside", destination: "Bohol",
                start: MockData.date(2026, 12, 2), end: MockData.date(2026, 12, 5), cover: .hills, stage: .planning,
                members: [MockData.bea, MockData.jo, MockData.migs], balance: nil, newCount: 0, code: "P4LC-2E8R",
                place: "Bohol", owner: MockData.bea
            ), MockData.bea, "Alex"
        ),
    ]

    /// Codes that fail on purpose.
    private static let failures: [String: JoinFailure] = [
        "XPRD5K2M": .expired,
        "USED7N4C": .usedUp,
        "FULL8H3N": .full(trip: "Palawan retreat"),
        "RMVD4KQ7": .removed(trip: "Cebu food trip"),
        "OFFLINE0": .offline,
    ]

    /// Eight letters and digits, in capitals, with nothing else.
    static func normalize(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
    }

    func preview(for rawCode: String, among trips: [Trip], me: AvatarMember) async throws -> JoinPreview {
        try await Task.sleep(for: .milliseconds(450))
        let code = Self.normalize(rawCode)
        if let failure = Self.failures[code] { throw failure }
        if let known = trips.first(where: { Self.normalize($0.code) == code }) {
            if known.isPast(on: MockData.today) { throw JoinFailure.archived(trip: known.title) }
            return JoinPreview(trip: known, invitedBy: known.owner ?? me, asPlaceholder: nil, alreadyOn: true)
        }
        guard let sample = Self.samples[code] else { throw JoinFailure.notFound }
        return JoinPreview(trip: sample.trip, invitedBy: sample.inviter, asPlaceholder: sample.placeholder, alreadyOn: false)
    }
}
