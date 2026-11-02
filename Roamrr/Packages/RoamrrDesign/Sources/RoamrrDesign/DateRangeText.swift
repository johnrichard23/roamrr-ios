import Foundation

/// Short date ranges as the screens write them: "3 – 10 Nov", "30 Nov – 2 Dec", "20 Nov".
public enum DateRangeText {
    public static func short(_ start: Date, _ end: Date, calendar: Calendar = .current) -> String {
        let day = Date.FormatStyle(calendar: calendar).day()
        let month = Date.FormatStyle(calendar: calendar).month(.abbreviated)
        if calendar.isDate(start, inSameDayAs: end) {
            return "\(start.formatted(day)) \(start.formatted(month))"
        }
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(start.formatted(day)) – \(end.formatted(day)) \(end.formatted(month))"
        }
        return "\(start.formatted(day)) \(start.formatted(month)) – \(end.formatted(day)) \(end.formatted(month))"
    }

    /// With the year, for a trip card: "3 – 10 Nov 2026".
    public static func withYear(_ start: Date, _ end: Date, calendar: Calendar = .current) -> String {
        "\(short(start, end, calendar: calendar)) \(calendar.component(.year, from: end))"
    }

    /// The number of days a range covers, counting both ends.
    public static func dayCount(_ start: Date, _ end: Date, calendar: Calendar = .current) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1
    }
}
