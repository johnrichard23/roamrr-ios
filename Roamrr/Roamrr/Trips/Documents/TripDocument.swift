import Foundation
import RoamrrDesign

/// What a booking document is. Drives its icon, its group on the list and where it can go on the plan.
enum DocumentKind: String, CaseIterable, Hashable {
    case flight = "Flight"
    case stay = "Stay"
    case activity = "Activity"
    case insurance = "Insurance"
    case other = "Other"

    var symbol: String {
        switch self {
        case .flight: "airplane"
        case .stay: "bed.double"
        case .activity: "ticket"
        case .insurance: "cross.case"
        case .other: "doc"
        }
    }

    /// The heading on the documents list.
    var plural: String {
        switch self {
        case .flight: "Flights"
        case .stay: "Stays"
        case .activity: "Activities"
        case .insurance: "Insurance"
        case .other: "Other"
        }
    }

    /// The plan category it becomes when it is put on a day; nil when it has no place on the plan.
    var planCategory: PlanCategory? {
        switch self {
        case .flight: .travel
        case .stay: .stay
        case .activity: .activity
        case .insurance, .other: nil
        }
    }

    /// Flights carry names and passport numbers, so they start private.
    var defaultVisibility: DocumentVisibility { self == .flight ? .onlyMe : .trip }
}

/// Who can open a document.
enum DocumentVisibility: Hashable {
    case trip, onlyMe
}

/// A booking someone added to the trip. The file itself is mock-only for now.
struct TripDocument: Identifiable, Hashable {
    let id: UUID
    var kind: DocumentKind
    var title: String
    var fileName: String
    var addedBy: AvatarMember
    var visibility: DocumentVisibility
    var place: String = ""
    var start: Date?
    /// Minutes after midnight.
    var minutes: Int?
    var end: Date?
    var confirmation: String = ""
    /// The plan item made from it, if the person chose to put it on a day.
    var planItemID: PlanItem.ID?
    var isPending = false

    /// "Tue 3 Nov · 6:40 AM"
    var summary: String {
        [start?.weekdayDayMonth, minutes.map(PlanItem.clockText)].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A passport, ID or insurance card. It lives on this phone and is never sent anywhere.
struct PersonalDocument: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var symbol: String
}

extension Trip {
    /// What you can open: everything shared, plus your own private documents.
    func documents(for me: AvatarMember) -> [TripDocument] {
        documents.filter { $0.visibility == .trip || $0.addedBy == me }
    }
}
