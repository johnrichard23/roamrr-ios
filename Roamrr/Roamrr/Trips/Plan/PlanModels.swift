import CoreLocation
import Foundation
import RoamrrDesign

/// What an idea is. Drives its icon and the filter chips.
enum PlanCategory: String, CaseIterable, Hashable {
    case food = "Food"
    case activity = "Activity"
    case sights = "Sights"
    case stay = "Stay"
    case travel = "Travel"

    var symbol: String {
        switch self {
        case .food: "cup.and.saucer"
        case .activity: "ticket"
        case .sights: "mappin.and.ellipse"
        case .stay: "bed.double"
        case .travel: "airplane"
        }
    }

    /// The expense category to start from when the group pays for it.
    var expenseCategory: ExpenseCategory {
        switch self {
        case .food: .food
        case .activity, .sights: .activity
        case .stay: .stay
        case .travel: .transport
        }
    }
}

/// How someone feels about an idea.
enum PlanReaction: String, CaseIterable, Hashable {
    case must = "Must-do"
    case want = "Want"
    case maybe = "Maybe"
    case skip = "Skip"

    /// How much it counts towards the order of the list.
    var weight: Int {
        switch self {
        case .must: 3
        case .want: 2
        case .maybe: 1
        case .skip: 0
        }
    }
}

/// Who a planned item is for.
enum PlanAudience: Hashable {
    case everyone, interested
}

/// A link on an idea: only the address and a label the person typed. It is never loaded.
struct PlanLink: Hashable {
    var url: URL
    var label: String

    /// "instagram.com", without "www.".
    var site: String {
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// An `https` address and nothing else, at most 2,000 characters.
    static func parse(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 2000, trimmed.lowercased().hasPrefix("https://"), let url = URL(string: trimmed),
              url.host?.contains(".") == true else { return nil }
        return url
    }
}

/// Mock-only artwork for ideas that have no real photo yet.
enum PlanTile: Hashable {
    case sunrise, food, lagoon, rocks
}

/// An idea for the trip, and, once it has a day, an item in the plan.
struct PlanItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var category: PlanCategory
    var placeName: String = ""
    var latitude: Double?
    var longitude: Double?
    var link: PlanLink?
    var note: String = ""
    var photo: Data?
    var tile: PlanTile?
    /// Estimated cost per person.
    var cost: Decimal?
    var addedBy: AvatarMember
    /// Keyed by `AvatarMember.id`.
    var reactions: [String: PlanReaction] = [:]
    var day: Date?
    /// Minutes after midnight.
    var minutes: Int?
    var order = 0
    var audience: PlanAudience = .everyone
    /// For "only those who want to": who is in, by `AvatarMember.id`.
    var going: Set<String> = []
    var isPending = false

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func count(_ reaction: PlanReaction) -> Int {
        reactions.values.filter { $0 == reaction }.count
    }

    /// Must-do ×3, Want ×2, Maybe ×1, Skip ×0.
    var score: Int { reactions.values.reduce(0) { $0 + $1.weight } }

    /// "6:00 AM"
    var timeText: String? { minutes.map(Self.clockText) }

    /// "6:00 AM", from minutes after midnight.
    static func clockText(_ minutes: Int) -> String {
        let hour = minutes / 60
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minutes % 60, hour < 12 ? "AM" : "PM")
    }
}

extension Trip {
    /// Ideas in the order the group wants them: highest score first, then newest.
    func ideas(in category: PlanCategory?) -> [PlanItem] {
        plan.filter { category == nil || $0.category == category }
            .enumerated()
            .sorted { ($0.element.score, $0.offset) > ($1.element.score, $1.offset) }
            .map(\.element)
    }

    /// Every day of the trip, first to last.
    var days: [Date] {
        guard datesDecided else { return [] }
        let calendar = Calendar.current
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            result.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(86400)
        }
        return result
    }

    /// What is planned on a day: by time, then in the order they were put there.
    func planned(on day: Date) -> [PlanItem] {
        let calendar = Calendar.current
        return plan.filter { $0.day.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
            .sorted { ($0.minutes ?? Int.max, $0.order) < ($1.minutes ?? Int.max, $1.order) }
    }

    /// The first thing on the itinerary that hasn't happened yet: later today by time, otherwise a later day.
    func nextItem(after now: Date) -> PlanItem? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let minutesNow = Int(now.timeIntervalSince(today) / 60)
        return plan
            .compactMap { item -> (day: Date, minutes: Int, item: PlanItem)? in
                guard let day = item.day else { return nil }
                return (calendar.startOfDay(for: day), item.minutes ?? 24 * 60 - 1, item)
            }
            .filter { $0.day > today || ($0.day == today && $0.minutes >= minutesNow) }
            .sorted { ($0.day, $0.minutes, $0.item.order) < ($1.day, $1.minutes, $1.item.order) }
            .first?.item
    }

    var plannedDayCount: Int {
        days.filter { !planned(on: $0).isEmpty }.count
    }
}

extension Date {
    /// "Tue 4 Nov"
    var weekdayDayMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: self)
    }
}
