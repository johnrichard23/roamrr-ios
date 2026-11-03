import Foundation

/// What the phone found in a document. Anything it could not read stays nil or empty.
struct ExtractedDetails: Hashable {
    var kind: DocumentKind
    var title: String
    var place: String
    var start: Date?
    /// Minutes after midnight, only when the document gives a time.
    var minutes: Int?
    var end: Date?
    var confirmation: String
}

/// Finds the booking details in text the phone has already read from a document. Text in, details out:
/// Apple's data detectors find dates and addresses, and simple rules find the rest. It never guesses a field it
/// cannot see, so a miss leaves it empty for the person to fill in.
enum BookingParser {
    static func parse(_ text: String, calendar: Calendar = .current) -> ExtractedDetails? {
        let text = separatingLabels(in: text)
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        let kind = classify(text.lowercased())
        let confirmation = confirmationNumber(in: text)
        var start: Date?
        var minutes: Int?
        var end: Date?
        switch kind {
        case .stay:
            let checkIn = dateNear(keywords: ["check-in", "check in", "checkin", "arrival", "arrive"], in: lines, calendar: calendar)
            let checkOut = dateNear(keywords: ["check-out", "check out", "checkout", "departure", "depart"], in: lines, calendar: calendar)
            start = checkIn?.day ?? firstDate(in: lines, calendar: calendar)?.day
            minutes = checkIn?.minutes
            end = checkOut?.day
        case .flight:
            let departs = dateNear(keywords: ["depart", "departure", "departs", "from"], in: lines, calendar: calendar) ?? firstDate(in: lines, calendar: calendar)
            start = departs?.day
            minutes = departs?.minutes
        default:
            let first = firstDate(in: lines, calendar: calendar)
            start = first?.day
            minutes = first?.minutes ?? timeNear(keywords: ["pick-up", "pick up", "pickup", "start", "meeting", "time"], in: lines, calendar: calendar)
        }
        let route = kind == .flight ? flightRoute(in: text) : nil
        let title = route.map { "\($0.from) to \($0.to)" } ?? title(for: kind, lines: lines)
        let place = route?.to ?? (kind == .flight || kind == .insurance ? "" : address(in: text))
        // A page with no date, no reference and no recognisable kind was not a booking.
        if kind == .other, start == nil, confirmation.isEmpty { return nil }
        return ExtractedDetails(kind: kind, title: title, place: place, start: start, minutes: minutes, end: end, confirmation: confirmation)
    }

    // MARK: Layout

    /// Some PDFs run several labelled facts together on one line ("Check-in: … Check-out: …"). Start a new line
    /// before each label so every fact can be read on its own.
    private static func separatingLabels(in text: String) -> String {
        let labels = "check-?in|check-?out|arrival|departure|address|confirmation|booking|reservation|reference|guest|room|total|pick-?up|voucher|participants|passenger|flight|date"
        let pattern = #"(?<=\S)[ \t]+(?=(?:"# + labels + #")(?:[ \t]+(?:no\.?|number|code|ref\w*|name|date))?[ \t]*:)"#
        guard let regex = try? NSRegularExpression(pattern: "(?i)" + pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
    }

    // MARK: Kind

    private static let keywords: [DocumentKind: [String]] = [
        .flight: ["boarding pass", "flight", "departure", "gate", "seat", "e-ticket", "eticket", "pnr", "airline", "terminal", "airways", "air asia", "cebu pacific"],
        .stay: ["check-in", "check in", "check-out", "check out", "hotel", "resort", "guest", "room", "nights", "night stay", "reservation", "hostel", "inn", "lodge", "villa"],
        .activity: ["voucher", "tour", "admission", "activity", "pick-up", "pick up", "participants", "excursion", "lesson", "tickets"],
        .insurance: ["policy", "insured", "coverage", "premium", "insurance"],
    ]

    private static func classify(_ lowered: String) -> DocumentKind {
        let scores = keywords.mapValues { words in words.filter { lowered.contains($0) }.count }
        guard let best = scores.max(by: { $0.value < $1.value }), best.value > 0 else { return .other }
        return best.key
    }

    // MARK: Confirmation number

    /// The code after "confirmation", "booking reference", "PNR" and similar. It must look like a code: capitals and
    /// digits, with at least one digit or six letters, so an ordinary word is never taken for one.
    private static func confirmationNumber(in text: String) -> String {
        let pattern = #"(?i)(?:confirmation|booking|reservation|reference|ref|pnr|record locator|voucher)(?:[ \t]*(?:no\.?|number|code|id|#|reference|ref))?[ \t]*[:#\-]?[ \t]*([A-Z0-9][A-Z0-9\-]{4,14})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let codeRange = Range(match.range(at: 1), in: text) else { continue }
            let code = String(text[codeRange])
            let looksLikeCode = code == code.uppercased() && (code.contains { $0.isNumber } || code.count >= 6)
            if looksLikeCode { return code }
        }
        return ""
    }

    // MARK: Dates

    private struct Found {
        let day: Date
        let minutes: Int?
    }

    private static let timePattern = try? NSRegularExpression(pattern: #"\d{1,2}[:.]\d{2}(?:\s?(?:am|pm)\b)?|\b\d{1,2}\s?(?:am|pm)\b"#, options: .caseInsensitive)

    /// The first date in a piece of text, with its time only when the text states one.
    private static func date(in text: String, calendar: Calendar) -> Found? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector.firstMatch(in: text, range: range), let date = match.date,
              let matched = Range(match.range, in: text) else { return nil }
        let words = String(text[matched])
        let hasTime = timePattern?.firstMatch(in: words, range: NSRange(words.startIndex..., in: words)) != nil
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return Found(day: calendar.startOfDay(for: date), minutes: hasTime ? (parts.hour ?? 0) * 60 + (parts.minute ?? 0) : nil)
    }

    private static func firstDate(in lines: [String], calendar: Calendar) -> Found? {
        for index in lines.indices {
            if let found = date(in: window(lines, at: index), calendar: calendar) { return found }
        }
        return nil
    }

    /// The date on, or just after, the first line that has one of the keywords.
    private static func dateNear(keywords: [String], in lines: [String], calendar: Calendar) -> Found? {
        for index in lines.indices where keywords.contains(where: { lines[index].lowercased().contains($0) }) {
            if let found = date(in: window(lines, at: index), calendar: calendar) { return found }
        }
        return nil
    }

    /// A time of day on a line that has one of the keywords: "Pick-up: 8:00 AM".
    private static func timeNear(keywords: [String], in lines: [String], calendar: Calendar) -> Int? {
        for line in lines where keywords.contains(where: { line.lowercased().contains($0) }) {
            guard let regex = timePattern, let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range, in: line),
                  let detected = date(in: String(line[range]), calendar: calendar), let minutes = detected.minutes else { continue }
            return minutes
        }
        return nil
    }

    /// A line and the one after it, since a label and its value are often on separate lines.
    private static func window(_ lines: [String], at index: Int) -> String {
        index + 1 < lines.count ? lines[index] + " " + lines[index + 1] : lines[index]
    }

    // MARK: Flights

    private static let airports = [
        "MNL": "Manila", "CEB": "Cebu", "IAO": "Siargao", "DVO": "Davao", "CRK": "Clark", "KLO": "Kalibo",
        "MPH": "Caticlan", "TAG": "Bohol", "PPS": "Puerto Princesa", "ILO": "Iloilo", "BCD": "Bacolod",
        "CGY": "Cagayan de Oro", "ZAM": "Zamboanga", "USU": "Coron", "LAO": "Laoag", "TAC": "Tacloban",
        "DGT": "Dumaguete", "SIN": "Singapore", "HKG": "Hong Kong", "ICN": "Seoul", "NRT": "Tokyo", "HND": "Tokyo",
        "BKK": "Bangkok", "KUL": "Kuala Lumpur", "TPE": "Taipei", "DXB": "Dubai", "SYD": "Sydney", "LAX": "Los Angeles",
    ]

    /// The two airport codes of a trip: "Manila (MNL)" then "Siargao (IAO)", or "MNL → IAO".
    private static func flightRoute(in text: String) -> (from: String, to: String)? {
        let patterns = [#"\(([A-Z]{3})\)"#, #"\b([A-Z]{3})\s*(?:→|->|–|-|to|TO)\s*([A-Z]{3})\b"#]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            var codes: [String] = []
            if index == 0 {
                codes = matches.compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
            } else if let match = matches.first {
                codes = (1...2).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
            }
            let known = codes.filter { airports[$0] != nil }
            if known.count >= 2, known[0] != known[1] {
                return (airports[known[0]] ?? known[0], airports[known[1]] ?? known[1])
            }
        }
        return nil
    }

    // MARK: Title and place

    private static let nameWords = ["hotel", "resort", "inn", "lodge", "villa", "hostel", "camp", "suites", "tour", "lagoon", "island", "adventure"]
    private static let skipWords = ["confirmation", "booking", "reservation", "reference", "check", "date", "guest", "name", "total", "price", "page", "thank", "dear", "www.", "http", "@"]

    private static func title(for kind: DocumentKind, lines: [String]) -> String {
        let candidates = lines.map(stripHeading).filter { line in
            let lowered = line.lowercased()
            return line.count >= 3 && line.count <= 60 && line.contains(where: \.isLetter)
                && !skipWords.contains { lowered.contains($0) }
        }
        if kind == .insurance, let line = candidates.first(where: { $0.lowercased().contains("insurance") }) { return line }
        if let named = candidates.first(where: { line in nameWords.contains { line.lowercased().contains($0) } }) { return named }
        if kind == .flight, let flight = flightNumber(in: lines) { return flight }
        return candidates.first ?? kind.rawValue
    }

    /// "Siargao Surf Camp Booking Confirmation" is the camp's name followed by the document's heading.
    private static func stripHeading(_ line: String) -> String {
        let headings = #"(?i)\b(?:booking|reservation|hotel|e-?ticket|travel|activity|tour)?[ \t]*(?:confirmation|itinerary receipt|voucher|e-?ticket|itinerary)\b"#
        let cleaned = line.replacingOccurrences(of: headings, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private static func flightNumber(in lines: [String]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\b([A-Z][A-Z0-9])\s?(\d{2,4})\b"#) else { return nil }
        for line in lines {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let code = Range(match.range(at: 1), in: line), let number = Range(match.range(at: 2), in: line) {
                return "Flight \(line[code]) \(line[number])"
            }
        }
        return nil
    }

    private static func address(in text: String) -> String {
        // A labelled line is the most reliable: "Address: …", "Location: …".
        let labelled = #"(?im)^[ \t]*(?:address|location|venue|meeting point)[ \t]*:[ \t]*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: labelled),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return "" }
        return String(text[range]).replacingOccurrences(of: "\n", with: ", ")
    }
}
