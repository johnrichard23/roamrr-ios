import UIKit
import CoreLocation
import Foundation
import RoamrrDesign

/// What a chat message is: plain text, a one-tap signal, a photo (with an optional caption), or a meeting point proposal.
enum ChatKind: Hashable {
    case text, signal, photo, meeting
}

/// A message between two people on a trip. Mock for now.
struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let from: AvatarMember
    var kind: ChatKind
    var text: String
    var photo: Data?
    /// The meeting point this message proposes or answers.
    var meetingID: UUID?
    var date: Date
    /// Written offline and waiting to be sent.
    var isPending = false
}

/// The one-tap messages for finding each other.
enum QuickSignal: CaseIterable {
    case stayPut, onMyWay, imHere, cantSeeYou

    var text: String {
        switch self {
        case .stayPut: "Stay put, I’m coming"
        case .onMyWay: "I’m on my way"
        case .imHere: "I’m here"
        case .cantSeeYou: "I can’t see you. Call me?"
        }
    }

    var symbol: String {
        switch self {
        case .stayPut: "hand.raised"
        case .onMyWay: "figure.walk"
        case .imHere: "mappin.and.ellipse"
        case .cantSeeYou: "eye.slash"
        }
    }
}

/// How someone answered a meeting point.
enum MeetingResponse: Hashable {
    case accepted, declined, arrived
}

/// A place the group agrees to meet at.
struct MeetingPoint: Identifiable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var proposedBy: AvatarMember
    /// Who it was proposed to. Empty means everyone on the trip.
    var audience: [AvatarMember]
    /// Keyed by `AvatarMember.id`.
    var responses: [String: MeetingResponse] = [:]

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    /// Everyone this was proposed to, other than the person who proposed it.
    func recipients(in trip: Trip, me: AvatarMember) -> [AvatarMember] {
        (audience.isEmpty ? [me] + trip.members : audience).filter { $0 != proposedBy }
    }

    /// "Bea accepted", "Waiting for Bea", or "2 of 3 accepted".
    func status(in trip: Trip, me: AvatarMember) -> String {
        let people = recipients(in: trip, me: me)
        let accepted = people.filter { responses[$0.id] == .accepted || responses[$0.id] == .arrived }
        let declined = people.filter { responses[$0.id] == .declined }
        if people.count == 1, let one = people.first {
            let name = one == me ? "You" : (one.name.split(separator: " ").first.map(String.init) ?? one.name)
            if !accepted.isEmpty { return "\(name) accepted" }
            if !declined.isEmpty { return one == me ? "You can’t make it" : "\(name) can’t make it" }
            return one == me ? "Waiting for your answer" : "Waiting for \(name)"
        }
        let base = "\(accepted.count) of \(people.count) accepted"
        return declined.isEmpty ? base : base + ", \(declined.count) can’t make it"
    }
}

extension Data {
    /// A photo made small enough to send over a weak connection: at most 1024 points on the long side, as JPEG.
    var compressedPhoto: Data? {
        guard let image = UIImage(data: self) else { return nil }
        let longest = Swift.max(image.size.width, image.size.height)
        let scale = Swift.min(1, 1024 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.6) { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
