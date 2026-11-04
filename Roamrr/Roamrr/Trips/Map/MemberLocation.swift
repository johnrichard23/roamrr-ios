import Foundation
import RoamrrDesign

/// Where someone last was, as the map shows them. Only the latest spot is kept.
struct MemberLocation: Identifiable, Hashable {
    let member: AvatarMember
    var latitude: Double
    var longitude: Double
    /// A short place name: "Cloud 9 boardwalk".
    var place: String
    var updatedAt: Date
    /// Their phone's battery, 0 to 100.
    var battery: Int = 100

    var id: String { member.id }

    /// Low enough that their location may stop updating soon.
    var isLowBattery: Bool { battery <= 20 }

    /// "Live" when the last update is under five minutes old.
    func isLive(on now: Date) -> Bool { now.timeIntervalSince(updatedAt) < 300 }

    /// "12 min ago", or "2 h ago" once it is over an hour.
    func lastSeen(on now: Date) -> String {
        let minutes = max(1, Int(now.timeIntervalSince(updatedAt) / 60))
        return minutes < 60 ? "\(minutes) min ago" : "\(minutes / 60) h ago"
    }
}

/// Your own sharing: when it began and when it stops by itself.
struct SharingSession: Hashable {
    var start: Date
    var end: Date

    /// "11 h 58 min", or "45 min" under an hour.
    func remaining(from now: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(now) / 60))
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    /// How much of the time is left, from 1 down to 0.
    func fractionLeft(from now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, end.timeIntervalSince(now) / total))
    }
}

extension Trip {
    /// Everyone live on the map right now, you included while you share.
    func sharingLive(on now: Date, me: AvatarMember) -> [AvatarMember] {
        let sharing = mySharing.map { $0.end > now } ?? false
        return (sharing ? [me] : []) + locations.filter { $0.isLive(on: now) }.map(\.member)
    }
}

extension Date {
    /// "9:41 PM"
    var clockTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }

    /// "until 9:41 PM", "until tomorrow 9:41 AM" or "until 7 Nov, 9:41 AM".
    func untilText(from now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(self, inSameDayAs: now) { return "until \(clockTime)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(self, inSameDayAs: tomorrow) {
            return "until tomorrow \(clockTime)"
        }
        return "until \(dayMonth), \(clockTime)"
    }
}
