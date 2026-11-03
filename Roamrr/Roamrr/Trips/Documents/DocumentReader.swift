import CoreGraphics
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Where a document comes from.
enum DocumentInput {
    case pdf(URL)
    case photo(URL)
    case scan([CGImage])
}

/// Reads a booking on this phone, then finds its details. Returns nil when nothing in it looks like a booking,
/// so the review screen opens empty and the person fills it in.
enum DocumentReader {
    static func read(_ input: DocumentInput) async -> ExtractedDetails? {
        let text: String
        switch input {
        case .pdf(let url): text = await DocumentTextReader.text(fromPDF: url)
        case .photo(let url):
            text = await DocumentTextReader.text(fromPhoto: url)
            try? FileManager.default.removeItem(at: url)
        case .scan(let images): text = await DocumentTextReader.text(from: images)
        }
        return BookingParser.parse(text)
    }
}

/// A photo from the library, handed over as a file instead of loaded into memory, so a very large photo is
/// shrunk by the reader and never held whole.
struct PickedPhoto: Transferable {
    let url: URL

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedPhoto(url: copy)
        }
    }
}
