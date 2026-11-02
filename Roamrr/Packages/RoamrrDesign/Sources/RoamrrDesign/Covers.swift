import SwiftUI

/// The three illustrated trip covers: flat, layered landscapes, no photos and no gradients.
/// The bottom band is always deep navy, so light text placed over it stays readable.
public enum CoverStyle: String, Sendable, CaseIterable, Hashable {
    /// An island, open water and a surfboard.
    case sea
    /// A snow-capped mountain over a skyline.
    case city
    /// Rolling hills and pines.
    case hills
}

/// A cover, drawn on a 400 by 300 box and scaled to fill its frame.
public struct CoverArt: View {
    /// How the artwork sits in its frame.
    public enum Fit: Sendable {
        /// Fills the frame, cropping the edges evenly.
        case fill
        /// Shows everything down to the top of the navy band and ends there, so a solid navy panel can start
        /// exactly where the frame ends.
        case abovePanel
    }

    private let style: CoverStyle
    private let fit: Fit

    public init(_ style: CoverStyle, fit: Fit = .fill) {
        self.style = style
        self.fit = fit
    }

    public var body: some View {
        Canvas { context, size in
            switch fit {
            case .fill:
                let scale = max(size.width / 400, size.height / 300)
                context.translateBy(x: (size.width - 400 * scale) / 2, y: (size.height - 300 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
            case .abovePanel:
                // The artwork's navy band starts at 214; show 18 more units of it, then stop.
                let scale = max(size.width / 400, size.height / 232)
                context.translateBy(x: (size.width - 400 * scale) / 2, y: size.height - 232 * scale)
                context.scaleBy(x: scale, y: scale)
            }
            CoverDrawing.draw(style, in: &context)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

private enum CoverDrawing {
    static let navy = Color(rgb: 0x18233A)
    static let deep = Color(rgb: 0x31446B)
    static let slate = Color(rgb: 0x506A8D)
    static let mid = Color(rgb: 0x6F88A1)
    static let ice = Color(rgb: 0xC1CDCE)
    static let peach = Color(rgb: 0xEBCBB4)
    static let orange = Color(rgb: 0xC26632)
    static let powder = Color(rgb: 0xB8C5D4)

    static func draw(_ style: CoverStyle, in context: inout GraphicsContext) {
        switch style {
        case .sea: sea(&context)
        case .city: city(&context)
        case .hills: hills(&context)
        }
        band(&context)
    }

    // MARK: Pieces

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func fill(_ context: inout GraphicsContext, _ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.closeSubpath()
        return path
    }

    /// A wavy strip: quadratic bumps alternating above and below `y`, closed down to `bottom`.
    private static func wave(y: CGFloat, amplitude: CGFloat, segment: CGFloat, count: Int, bottom: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(0, y))
        for index in 0..<count {
            let x = segment * CGFloat(index)
            let up = index.isMultiple(of: 2)
            path.addQuadCurve(
                to: p(x + segment, y),
                control: p(x + segment / 2, up ? y - amplitude : y + amplitude)
            )
        }
        path.addLine(to: p(400, bottom))
        path.addLine(to: p(0, bottom))
        path.closeSubpath()
        return path
    }

    private static func band(_ context: inout GraphicsContext) {
        fill(&context, wave(y: 214, amplitude: 10, segment: 100, count: 4, bottom: 300), navy)
    }

    private static func pine(_ x: CGFloat, _ base: CGFloat, _ height: CGFloat) -> Path {
        triangle(p(x - height * 0.32, base), p(x, base - height), p(x + height * 0.32, base))
    }

    // MARK: Covers

    private static func sea(_ context: inout GraphicsContext) {
        fill(&context, rect(0, 0, 400, 300), Color(rgb: 0xC9D6DE))
        fill(&context, circle(300, 86, 40), peach)

        var island = Path()
        island.move(to: p(0, 168))
        island.addQuadCurve(to: p(96, 146), control: p(40, 132))
        island.addQuadCurve(to: p(190, 150), control: p(140, 120))
        island.addQuadCurve(to: p(240, 170), control: p(220, 160))
        island.addLine(to: p(240, 300))
        island.addLine(to: p(0, 300))
        island.closeSubpath()
        fill(&context, island, mid)

        var palm = Path()
        palm.move(to: p(60, 150))
        palm.addQuadCurve(to: p(62, 104), control: p(68, 120))
        palm.move(to: p(62, 112))
        palm.addQuadCurve(to: p(36, 114), control: p(48, 106))
        palm.move(to: p(62, 112))
        palm.addQuadCurve(to: p(88, 106), control: p(74, 100))
        palm.move(to: p(62, 112))
        palm.addQuadCurve(to: p(68, 90), control: p(58, 98))
        context.stroke(palm, with: .color(slate), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        fill(&context, rect(0, 168, 400, 132), deep)
        fill(&context, wave(y: 186, amplitude: 8, segment: 80, count: 5, bottom: 202), slate)

        var glints = Path()
        for (x, y, length) in [(30, 196, 40), (140, 192, 56), (260, 198, 48), (340, 190, 36)] as [(CGFloat, CGFloat, CGFloat)] {
            glints.move(to: p(x, y))
            glints.addLine(to: p(x + length, y))
        }
        context.stroke(glints, with: .color(ice.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        var board = context
        board.translateBy(x: 266, y: 182)
        board.rotate(by: .degrees(-8))
        board.translateBy(x: -266, y: -182)
        board.fill(Path(roundedRect: CGRect(x: 226, y: 176, width: 80, height: 13), cornerRadius: 6.5), with: .color(orange))
    }

    private static func city(_ context: inout GraphicsContext) {
        fill(&context, rect(0, 0, 400, 300), peach)
        fill(&context, circle(96, 78, 38), Color(rgb: 0xF3DDCB))
        fill(&context, triangle(p(120, 214), p(222, 88), p(330, 214)), powder)

        var snow = Path()
        snow.move(to: p(200, 115))
        for point in [p(222, 88), p(246, 117), p(236, 112), p(224, 121), p(212, 112)] {
            snow.addLine(to: point)
        }
        snow.closeSubpath()
        fill(&context, snow, Color(rgb: 0xF7F9F9))

        let back: [(CGFloat, CGFloat, CGFloat)] = [
            (20, 150, 34), (58, 128, 26), (88, 160, 30), (122, 138, 22), (150, 118, 28),
            (250, 132, 30), (284, 150, 24), (312, 124, 34), (350, 146, 30),
        ]
        for (x, y, w) in back { fill(&context, rect(x, y, w, 220 - y), slate) }

        let tower = triangle(p(206, 214), p(214, 112), p(222, 214))
        fill(&context, tower, orange)
        context.stroke(tower, with: .color(orange), lineWidth: 2)

        let front: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 176, 46), (52, 168, 40), (98, 182, 36), (300, 172, 44), (350, 180, 50),
        ]
        for (x, y, w) in front { fill(&context, rect(x, y, w, 220 - y), deep) }
    }

    private static func hills(_ context: inout GraphicsContext) {
        fill(&context, rect(0, 0, 400, 300), Color(rgb: 0xD5DDE7))
        fill(&context, circle(250, 70, 30), Color(rgb: 0xF1D5C2))

        var far = Path()
        far.move(to: p(0, 150))
        far.addQuadCurve(to: p(170, 140), control: p(80, 104))
        far.addQuadCurve(to: p(400, 146), control: p(250, 110))
        far.addLine(to: p(400, 300))
        far.addLine(to: p(0, 300))
        far.closeSubpath()
        fill(&context, far, powder)

        var near = Path()
        near.move(to: p(0, 176))
        near.addQuadCurve(to: p(210, 172), control: p(100, 140))
        near.addQuadCurve(to: p(400, 178), control: p(300, 150))
        near.addLine(to: p(400, 300))
        near.addLine(to: p(0, 300))
        near.closeSubpath()
        fill(&context, near, mid)

        for (x, base, height) in [(150, 168, 34), (172, 170, 26), (230, 164, 38), (252, 168, 28)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&context, pine(x, base, height), slate)
        }
        for (x, base, height) in [(60, 196, 58), (88, 200, 42), (300, 194, 64), (332, 200, 46), (360, 198, 52)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(&context, pine(x, base, height), deep)
        }
    }
}

#Preview("Covers") {
    VStack(spacing: 12) {
        ForEach(CoverStyle.allCases, id: \.self) { style in
            CoverArt(style).frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
    .padding()
}
