import Foundation
import RoamrrDesign

/// Where a trip is in its life. Every new trip starts in planning; the owner finalises the itinerary.
enum TripStage: Hashable {
    case planning, final
}

/// A trip as the Trips screens show it. Mock data for now.
struct Trip: Identifiable, Hashable {
    let id: UUID
    var title: String
    /// The place the greeting names: "Day 2 in Siargao".
    var destination: String
    var start: Date
    var end: Date
    var cover: CoverStyle
    /// Planning until the owner finalises the itinerary.
    var stage: TripStage = .final
    /// False while the group has not chosen dates; `start` and `end` are then only placeholders.
    var datesDecided = true
    var coverPhoto: Data?
    /// Everyone else on the trip; you are always the one not listed.
    var members: [AvatarMember]
    /// Positive when you are owed, negative when you owe, nil before any expense.
    var balance: Decimal?
    var newCount: Int
    var code: String
    /// Where it happens, for the overview line: "General Luna, Siargao".
    var place: String = ""
    /// The last known spot of each person who has shared their location on this trip, other than you.
    var locations: [MemberLocation] = []
    var expenses: [Expense] = []
    var payments: [Payment] = []
    /// What each person is owed (positive) or owes (negative), as the balances page lists them.
    var standings: [Standing] = []
    /// The payments that would settle everything.
    var settlements: [Settlement] = []
    /// Who created the trip; nil when it is you.
    var owner: AvatarMember?
    /// When each person joined, keyed by `AvatarMember.id`.
    var joined: [String: Date] = [:]
    /// Your own sharing, while it is on.
    var mySharing: SharingSession?
    /// Chats with each person, keyed by their `AvatarMember.id`.
    var chats: [String: [ChatMessage]] = [:]
    /// Where the group has agreed to meet, if anywhere.
    var meetingPoint: MeetingPoint?
    /// People who were asked to stay put and are standing still, by `AvatarMember.id`.
    var staying: Set<String> = []
    /// Ideas and the day-by-day plan.
    var plan: [PlanItem] = []
    /// Whether this phone hears about the trip. Per person, not per trip.
    var notificationsOn = true

    var peopleCount: Int { members.count + 1 }

    /// Total spent so far; nil before the first expense.
    var spent: Decimal? {
        expenses.isEmpty ? nil : expenses.reduce(0) { $0 + $1.amount }
    }


    /// Everyone on the trip, you last.
    func everyone(with me: AvatarMember) -> [AvatarMember] { members + [me] }
}

extension Trip {
    /// "3 – 10 Nov"
    var dates: String { datesDecided ? DateRangeText.short(start, end) : "Dates not decided yet" }

    var isPlanning: Bool { stage == .planning }

    func isPast(on today: Date) -> Bool { datesDecided && end < Calendar.current.startOfDay(for: today) }

    func isNow(on today: Date) -> Bool { datesDecided && !isPast(on: today) && start <= today }

    /// "Now · day 2 of 8", or how long until it starts.
    func status(on today: Date) -> String {
        if isPlanning { return "Planning" }
        let calendar = Calendar.current
        if isNow(on: today) {
            let day = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? 0) + 1
            return "Now · day \(day) of \(DateRangeText.dayCount(start, end))"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: start)).day ?? 0
        return days == 1 ? "Starts tomorrow" : "Starts in \(days) days"
    }

    /// The line under the title on the overview: "Day 2 of 8 · General Luna, Siargao".
    func overviewSubtitle(on today: Date) -> String {
        let calendar = Calendar.current
        let lead: String
        if isNow(on: today) {
            let day = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? 0) + 1
            lead = "Day \(day) of \(DateRangeText.dayCount(start, end))"
        } else {
            lead = dates
        }
        return place.isEmpty ? lead : "\(lead) · \(place)"
    }

    /// The home greeting's display line: "Day 2 in Siargao" during a trip, "Siargao in 3 days" before one.
    func headline(on today: Date) -> String {
        if isPlanning { return "Planning \(destination)" }
        let calendar = Calendar.current
        if isNow(on: today) {
            let day = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? 0) + 1
            return "Day \(day) in \(destination)"
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: start)).day ?? 0
        return days == 1 ? "\(destination) tomorrow" : "\(destination) in \(days) days"
    }
}

/// One person's standing on a trip: positive when they are owed, negative when they owe.
struct Standing: Hashable, Identifiable {
    let member: AvatarMember
    let amount: Decimal

    var id: String { member.id }
}

/// A suggested payment that brings the trip closer to settled.
struct Settlement: Hashable, Identifiable {
    let from: AvatarMember
    let to: AvatarMember
    let amount: Decimal

    var id: String { "\(from.id)>\(to.id)" }
}

extension Date {
    /// "4 Nov", day first as the drafts write it.
    var dayMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
}

enum Money {
    /// "₱560", or "₱12.4k" from a thousand up: for tiles with little room.
    static func compact(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: abs(amount)).doubleValue
        guard value >= 1000 else { return "₱\(Int(value.rounded()))" }
        let thousands = value / 1000
        return thousands >= 100 ? "₱\(Int(thousands.rounded()))k" : String(format: "₱%.1fk", thousands)
    }

    /// "+₱560.00" or "−₱150.00"
    static func signed(_ amount: Decimal) -> String {
        (amount < 0 ? "−" : "+") + peso(abs(amount))
    }

    /// "₱560.00"
    static func peso(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "PHP").locale(Locale(identifier: "en_PH")))
    }
}
