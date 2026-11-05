import SwiftUI
import UIKit

/// Stand-in photos for the mock ideas: flat landscapes drawn in the app's palette, three angles of the same kind of place.
/// Real photos replace them as soon as someone adds their own.
enum MockPhotos {
    enum Scene {
        case sunrise, lagoon
    }

    /// `count` different views of one kind of place, as JPEG data the idea can carry. Real photos from `Mock/Photos`
    /// when they are there (they are not committed), otherwise drawn ones.
    static func make(_ scene: Scene, count: Int) -> [Data] {
        let prefix = scene == .sunrise ? "kiltepan" : "lagoon"
        let real = (1...count).compactMap { index in
            Bundle.main.url(forResource: "\(prefix)-\(index)", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) }
        }
        if real.count == count { return real }
        return (0..<count).compactMap { render(scene, variant: $0) }
    }

    /// A person's portrait from `Mock/Photos` (`portrait-<name>.jpg`, not committed), or nil so the initial shows.
    static func portrait(_ name: String) -> Data? {
        Bundle.main.url(forResource: "portrait-\(name)", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) }
    }

    private static func render(_ scene: Scene, variant: Int) -> Data? {
        let size = CGSize(width: 900, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            let cg = context.cgContext
            let palette = colors(scene, variant: variant)
            // Sky in bands, not a gradient.
            let bands = palette.sky.count
            for (index, color) in palette.sky.enumerated() {
                cg.setFillColor(color.cgColor)
                cg.fill(CGRect(x: 0, y: size.height * CGFloat(index) / CGFloat(bands), width: size.width, height: size.height / CGFloat(bands) + 1))
            }
            // The sun, in a different place each time.
            let sunX = [0.28, 0.62, 0.8][variant % 3] * size.width
            let sunY = [0.52, 0.36, 0.45][variant % 3] * size.height
            cg.setFillColor(palette.sun.cgColor)
            cg.fillEllipse(in: CGRect(x: sunX - 70, y: sunY - 70, width: 140, height: 140))
            // Two ridges, nearer and farther.
            ridge(cg, size: size, base: [0.62, 0.55, 0.68][variant % 3], height: 0.16, color: palette.far, seed: variant + 1)
            ridge(cg, size: size, base: [0.8, 0.74, 0.84][variant % 3], height: 0.2, color: palette.near, seed: variant + 7)
        }
    }

    private static func ridge(_ cg: CGContext, size: CGSize, base: CGFloat, height: CGFloat, color: UIColor, seed: Int) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height))
        let steps = 24
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let wave = sin(CGFloat(step) * 0.55 + CGFloat(seed)) * 0.5 + sin(CGFloat(step) * 0.17 + CGFloat(seed) * 1.7) * 0.5
            path.addLine(to: CGPoint(x: x, y: size.height * base - wave * size.height * height))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        cg.setFillColor(color.cgColor)
        cg.addPath(path)
        cg.fillPath()
    }

    private static func colors(_ scene: Scene, variant: Int) -> (sky: [UIColor], sun: UIColor, far: UIColor, near: UIColor) {
        switch scene {
        case .sunrise:
            let skies: [[UInt32]] = [
                [0xF1B58C, 0xE8A082, 0xD98E7F, 0x9A8FA3],
                [0xF5C9A0, 0xEDB08E, 0xC99AA0, 0x7F8FB0],
                [0xE9A98F, 0xD58E86, 0x8E86A8, 0x5B6F96],
            ]
            return (skies[variant % 3].map(ui), ui(0xFBE3C8), ui(0x6F86A8), ui(0x324A6E))
        case .lagoon:
            let skies: [[UInt32]] = [
                [0xCFE7EC, 0xB5DCE5, 0x9BD0DC, 0x7FC0D0],
                [0xD9ECEF, 0xBFE0E7, 0xA2D4DE, 0x86C6D4],
                [0xC4E1E8, 0xA8D5DF, 0x8BC8D6, 0x6DB6C8],
            ]
            return (skies[variant % 3].map(ui), ui(0xFFF4DD), ui(0x4C9DB0), ui(0x2E6E86))
        }
    }

    private static func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
