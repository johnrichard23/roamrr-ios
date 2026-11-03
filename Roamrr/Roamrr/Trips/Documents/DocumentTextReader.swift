import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Vision

/// Reads the text out of a document on this phone: a PDF's own text when it has some, otherwise Apple's text
/// recognition on its pages. Nothing here touches the network.
nonisolated enum DocumentTextReader {
    /// The longest side, in pixels, that a page or photo is read at. Larger is slower and no more accurate.
    private static let longestSide: CGFloat = 2400
    /// How many pages of a scanned PDF are read.
    private static let pageLimit = 4

    static func text(fromPDF url: URL) async -> String {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else { return "" }
        let own = (0..<min(document.pageCount, pageLimit)).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        if own.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 { return own }
        // A scanned PDF has no text of its own, so read its pages as pictures.
        var images: [CGImage] = []
        for index in 0..<min(document.pageCount, pageLimit) {
            if let page = document.page(at: index), let image = render(page) { images.append(image) }
        }
        return await text(from: images)
    }

    static func text(fromPhoto data: Data) async -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return "" }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return "" }
        return await text(from: [image])
    }

    static func text(from images: [CGImage]) async -> String {
        await Task.detached(priority: .userInitiated) {
            images.map(recognise).joined(separator: "\n")
        }.value
    }

    /// The picture on an opaque white page. A screenshot or PNG with a transparent background would otherwise be read as
    /// black text on black.
    private static func flattened(_ image: CGImage) -> CGImage {
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }

    private static func recognise(_ source: CGImage) -> String {
        let image = flattened(source)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).sorted {
            // Top to bottom, then left to right.
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        return lines.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = longestSide / max(bounds.width, bounds.height)
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }
}
