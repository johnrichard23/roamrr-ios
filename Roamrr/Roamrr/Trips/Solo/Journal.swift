import Foundation
import RoamrrDesign

/// How a day felt, as weather: one of five, optional.
enum JournalMood: Int, CaseIterable, Hashable {
    case rough, low, okay, good, great

    var title: String {
        switch self {
        case .rough: "Rough"
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var symbol: String {
        switch self {
        case .rough: "cloud.bolt.rain"
        case .low: "cloud.drizzle"
        case .okay: "cloud"
        case .good: "cloud.sun"
        case .great: "sun.max"
        }
    }
}

/// One day's entry in a trip's journal. Private to the person who wrote it.
struct JournalEntry: Identifiable, Hashable {
    let id: UUID
    var day: Date
    var text: String = ""
    var mood: JournalMood?
    var photos: [Data] = []
    /// The day's facts already added to the text, by `JournalFact.id`.
    var usedFacts: Set<String> = []

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mood == nil && photos.isEmpty
    }
}

/// Something the app already knows about a day, offered as a line the person can add to their entry.
struct JournalFact: Identifiable, Hashable {
    let id: String
    let symbol: String
    /// What the chip shows.
    let label: String
    /// What goes into the entry when tapped.
    let line: String
}

extension Trip {
    /// A trip with nobody else on it. Votes, splits and live sharing are hidden.
    var isSolo: Bool { solo }

    var dayCount: Int { DateRangeText.dayCount(start, end) }

    /// 1 on the first day of the trip; nil outside it.
    func dayNumber(on date: Date) -> Int? {
        guard datesDecided else { return nil }
        let calendar = Calendar.current
        let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? -1
        return (0..<dayCount).contains(offset) ? offset + 1 : nil
    }

    /// The trip's days from the first up to and including `today`, newest first.
    func daysSoFar(on today: Date) -> [Date] {
        guard datesDecided else { return [] }
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: start)
        let count = min(dayCount, (dayNumber(on: today) ?? (isPast(on: today) ? dayCount : 0)))
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }.reversed()
    }

    func entry(on day: Date) -> JournalEntry? {
        journal.first { Calendar.current.isDate($0.day, inSameDayAs: day) && !$0.isEmpty }
    }

    func spent(on day: Date) -> Decimal {
        expenses.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.amount }
    }

    /// Spending that counts against the daily budget. Stays are paid once for many nights, so they count only toward the trip.
    func dailySpent(on day: Date) -> Decimal {
        expenses.filter { $0.category != .stay && Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.amount }
    }

    /// What the app knows about a day: plans already past, where they were, money spent.
    func facts(on day: Date, now: Date) -> [JournalFact] {
        let calendar = Calendar.current
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let minutesNow = Int(now.timeIntervalSince(calendar.startOfDay(for: now)) / 60)
        let done = planned(on: day).filter { !isToday || ($0.minutes ?? Int.max) <= minutesNow }
        var facts = done.map { JournalFact(id: "plan-\($0.id)", symbol: "checkmark.circle", label: $0.title, line: $0.title) }
        var places: [String] = []
        for place in done.map(\.placeName) where !place.isEmpty && !places.contains(place) { places.append(place) }
        facts += places.map { JournalFact(id: "place-\($0)", symbol: "mappin", label: $0, line: "In \($0)") }
        let spent = spent(on: day)
        if spent > 0 {
            facts.append(JournalFact(id: "spent", symbol: "banknote", label: "\(Money.whole(spent)) spent", line: "Spent \(Money.whole(spent))"))
        }
        return facts
    }
}

extension Money {
    /// "₱1,240", for budget figures where centavos are noise.
    static func whole(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "PHP").precision(.fractionLength(0)).locale(Locale(identifier: "en_PH")))
    }
}
