import CoreGraphics
import Foundation

/// Where a document comes from.
enum DocumentInput {
    case pdf(URL)
    case photo(Data)
    case scan([CGImage])
}

/// Reads a booking on this phone, then finds its details. Returns nil when nothing in it looks like a booking,
/// so the review screen opens empty and the person fills it in.
enum DocumentReader {
    static func read(_ input: DocumentInput) async -> ExtractedDetails? {
        let text: String
        switch input {
        case .pdf(let url): text = await DocumentTextReader.text(fromPDF: url)
        case .photo(let data): text = await DocumentTextReader.text(fromPhoto: data)
        case .scan(let images): text = await DocumentTextReader.text(from: images)
        }
        return BookingParser.parse(text)
    }
}
