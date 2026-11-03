import Foundation
import RoamrrDesign

/// Sample people and trips, the same ones the design drafts use.
enum MockData {
    static let you = AvatarMember(name: "Alex Rivera", colorIndex: 0)
    static let bea = AvatarMember(name: "Bea Santos", colorIndex: 1)
    static let ana = AvatarMember(name: "Ana Cruz", colorIndex: 5)
    static let jo = AvatarMember(name: "Jo Reyes", colorIndex: 3)
    static let migs = AvatarMember(name: "Migs Lim", colorIndex: 2)

    /// 4 Nov 2026, 9:41 AM: day 2 of the Siargao trip.
    static let today = date(2026, 11, 4)

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 9, minute: 41)) ?? .now
    }

    private static func expense(
        _ title: String, _ category: ExpenseCategory, _ amount: Decimal, by payer: AvatarMember,
        day: Int, pending: Bool = false
    ) -> Expense {
        Expense(id: UUID(), title: title, category: category, amount: amount, payer: payer, date: date(2026, 11, day), isPending: pending)
    }

    private static func idea(
        _ title: String, _ category: PlanCategory, place: String, lat: Double, lon: Double, by: AvatarMember,
        tile: PlanTile, link: PlanLink? = nil, cost: Decimal? = nil, note: String = "",
        reactions: [String: PlanReaction] = [:]
    ) -> PlanItem {
        PlanItem(
            id: UUID(), title: title, category: category, placeName: place, latitude: lat, longitude: lon, link: link,
            note: note, tile: tile, cost: cost, addedBy: by, reactions: reactions
        )
    }

    private static func plan() -> [PlanItem] {
        var sunrise = idea(
            "Sunrise surf at Cloud 9", .activity, place: "Cloud 9 boardwalk", lat: 9.8105, lon: 126.1585, by: bea,
            tile: .sunrise, link: PlanLink(url: URL(string: "https://www.instagram.com/reel/Cx8example/") ?? URL(filePath: "/"), label: "Reel: sunrise at Cloud 9"),
            note: "Best light at 5:45. Bring a rash guard.",
            reactions: [you.id: .must, bea.id: .must, ana.id: .want, jo.id: .want]
        )
        sunrise.day = date(2026, 11, 4); sunrise.minutes = 6 * 60; sunrise.order = 1
        var lunch = idea(
            "Lunch at Kermit", .food, place: "General Luna", lat: 9.7900, lon: 126.1580, by: jo, tile: .food,
            reactions: [you.id: .want, bea.id: .want, jo.id: .want, migs.id: .maybe]
        )
        lunch.day = date(2026, 11, 4); lunch.minutes = 12 * 60 + 30; lunch.order = 2
        var lagoon = idea(
            "Sugba Lagoon tour", .activity, place: "Del Carmen", lat: 9.8700, lon: 126.0300, by: ana, tile: .lagoon,
            cost: 1200, note: "Boat and lunch included.",
            reactions: [ana.id: .want, bea.id: .want, jo.id: .maybe, migs.id: .skip]
        )
        lagoon.day = date(2026, 11, 5); lagoon.minutes = 8 * 60; lagoon.order = 3
        lagoon.audience = .interested; lagoon.going = [ana.id, bea.id, migs.id]
        let rocks = idea(
            "Magpupungko Rock Pools", .sights, place: "Pilar", lat: 9.7330, lon: 126.1600, by: migs, tile: .rocks,
            link: PlanLink(url: URL(string: "https://maps.app.goo.gl/tides") ?? URL(filePath: "/"), label: "Tide times and how to get there"),
            note: "Low tide only.", reactions: [migs.id: .want, jo.id: .maybe, ana.id: .maybe]
        )
        return [sunrise, lunch, lagoon, rocks]
    }

    private static func sagada() -> Trip {
        var trip = Trip(
            id: UUID(), title: "Sagada weekend", destination: "Sagada",
            start: today, end: today, cover: .hills, coverPhoto: nil,
            members: [bea, ana, jo, migs], balance: nil, newCount: 0, code: "H4TN-2WQC"
        )
        trip.stage = .planning
        trip.datesDecided = false
        trip.place = "Sagada, Mountain Province"
        func idea(_ title: String, _ category: PlanCategory, place: String, tile: PlanTile, by: AvatarMember, _ reactions: [String: PlanReaction]) -> PlanItem {
            PlanItem(id: UUID(), title: title, category: category, placeName: place, tile: tile, addedBy: by, reactions: reactions)
        }
        trip.plan = [
            idea("Sunrise at Kiltepan Peak", .activity, place: "Kiltepan", tile: .sunrise, by: bea, [you.id: .must, bea.id: .must, ana.id: .must, migs.id: .want]),
            idea("Lemon pie at Yoghurt House", .food, place: "Sagada town", tile: .food, by: ana, [you.id: .want, bea.id: .want, ana.id: .want, migs.id: .want]),
            idea("Sumaguing Cave", .sights, place: "Sumaguing", tile: .rocks, by: migs, [you.id: .must, migs.id: .must, bea.id: .want]),
            idea("Echo Valley hanging coffins", .sights, place: "Echo Valley", tile: .lagoon, by: ana, [ana.id: .maybe]),
            idea("Dinner at Salt & Pepper", .food, place: "Sagada town", tile: .food, by: you, [you.id: .want]),
        ]
        return trip
    }

    static let trips: [Trip] = [
        Trip(
            id: UUID(), title: "Siargao surf week", destination: "Siargao",
            start: date(2026, 11, 3), end: date(2026, 11, 10), cover: .sea, coverPhoto: nil,
            members: [bea, ana, jo, migs], balance: 560, newCount: 4, code: "K7Q2-M9XD",
            place: "General Luna, Siargao",
            locations: [
                MemberLocation(member: bea, latitude: 9.8105, longitude: 126.1585, place: "Cloud 9 boardwalk", updatedAt: date(2026, 11, 4).addingTimeInterval(-60), battery: 62),
                MemberLocation(member: jo, latitude: 9.7895, longitude: 126.1575, place: "General Luna", updatedAt: date(2026, 11, 4), battery: 18),
                MemberLocation(member: migs, latitude: 9.8000, longitude: 126.1570, place: "Tourism Rd", updatedAt: date(2026, 11, 4).addingTimeInterval(-12 * 60), battery: 7),
            ],
            expenses: [
                expense("Surf lessons", .activity, 2400, by: you, day: 4, pending: true),
                {
                    var dinner = expense("Dinner at Kermit", .food, 3250, by: bea, day: 3)
                    dinner.history = [ExpenseChange(
                        id: UUID(), who: bea, title: "Bea changed the amount",
                        detail: "₱3,050.00 → ₱3,250.00 · 3 Nov", date: date(2026, 11, 3)
                    )]
                    return dinner
                }(),
                expense("Habal-habal to Cloud 9", .transport, 400, by: jo, day: 3),
                expense("Villa, 7 nights", .stay, 6350, by: ana, day: 3),
            ],
            standings: [
                Standing(member: you, amount: 560), Standing(member: bea, amount: 150),
                Standing(member: ana, amount: -150), Standing(member: jo, amount: -240),
                Standing(member: migs, amount: -320),
            ],
            settlements: [
                Settlement(from: migs, to: you, amount: 320), Settlement(from: jo, to: you, amount: 240),
                Settlement(from: ana, to: bea, amount: 150),
            ],
            owner: bea,
            joined: [you.id: date(2026, 11, 2), ana.id: date(2026, 11, 1), jo.id: date(2026, 11, 1), migs.id: date(2026, 11, 2)],
            plan: plan()
        ),
        Trip(
            id: UUID(), title: "Baguio weekend", destination: "Baguio",
            start: date(2026, 8, 22), end: date(2026, 8, 24), cover: .hills, coverPhoto: nil,
            members: [bea, jo, migs], balance: 0, newCount: 0, code: "B4GW-3K2E",
            place: "Baguio",
            expenses: [
                Expense(id: UUID(), title: "Lodge, 2 nights", category: .stay, amount: 5200, payer: bea, date: date(2026, 8, 22)),
                Expense(id: UUID(), title: "Strawberry taho and lunch", category: .food, amount: 2400, payer: jo, date: date(2026, 8, 23)),
                Expense(id: UUID(), title: "Jeepney and taxi", category: .transport, amount: 1040, payer: migs, date: date(2026, 8, 23)),
            ],
            standings: [you, bea, jo, migs].map { Standing(member: $0, amount: 0) },
            owner: bea
        ),
        Trip(
            id: UUID(), title: "Seoul in spring", destination: "Seoul",
            start: date(2026, 4, 9), end: date(2026, 4, 14), cover: .city, coverPhoto: nil,
            members: [ana, jo], balance: -320, newCount: 0, code: "S9PR-4HTD",
            place: "Seoul",
            expenses: [
                Expense(id: UUID(), title: "Guesthouse", category: .stay, amount: 3600, payer: ana, date: date(2026, 4, 9)),
                Expense(id: UUID(), title: "Street food crawl", category: .food, amount: 1560, payer: ana, date: date(2026, 4, 11)),
                Expense(id: UUID(), title: "T-money cards", category: .transport, amount: 600, payer: jo, date: date(2026, 4, 10)),
            ],
            standings: [Standing(member: you, amount: -320), Standing(member: ana, amount: 320), Standing(member: jo, amount: 0)],
            settlements: [Settlement(from: you, to: ana, amount: 320)],
            owner: ana
        ),
        sagada(),
    ]
}
