import XCTest
@testable import RoamrrDesign

/// Guards the contrast figures written in the design system. Each row is
/// (name, foreground, background, minimum ratio). Text needs 4.5, large text and
/// input outlines need 3.
final class PaletteContrastTests: XCTestCase {
    typealias Pair = (String, ColorToken, ColorToken, Double)

    private func check(_ pairs: [Pair], dark: Bool, file: StaticString = #filePath, line: UInt = #line) {
        for (name, fg, bg, minimum) in pairs {
            let ratio = Contrast.ratio(dark ? fg.dark : fg.light, dark ? bg.dark : bg.light)
            XCTAssertGreaterThanOrEqual(
                ratio, minimum, "\(dark ? "dark" : "light") \(name): \(ratio) < \(minimum)", file: file, line: line
            )
        }
    }

    // Minimums are the figures written in the design system, rounded down a little.
    func testLightPairs() {
        let p = Palette.self
        check([
            ("ink on canvas", p.ink, p.canvas, 13.2),
            ("ink on ice", p.ink, p.ice, 11.2),
            ("ink on pill", p.ink, p.pill, 14.7),
            ("secondary on canvas", p.inkSecondary, p.canvas, 6.7),
            ("secondary on ice", p.inkSecondary, p.ice, 5.6),
            ("secondary on pill", p.inkSecondary, p.pill, 7.5),
            ("muted on canvas", p.inkMuted, p.canvas, 5.5),
            ("muted on ice", p.inkMuted, p.ice, 4.7),
            ("muted on pill", p.inkMuted, p.pill, 6.2),
            ("accent on canvas", p.accent, p.canvas, 5.7),
            ("accent on ice", p.accent, p.ice, 4.8),
            ("accent on pill", p.accent, p.pill, 6.4),
            ("ink on accent soft", p.ink, p.accentSoft, 11.1),
            ("danger on canvas", p.danger, p.canvas, 6.0),
            ("danger on ice", p.danger, p.ice, 5.1),
            ("danger on pill", p.danger, p.pill, 6.7),
            ("on danger tint", p.onDangerTint, p.dangerTint, 7.4),
            ("on ink button", p.onInk, p.ink, 14.7),
            ("on accent fill", p.onInk, p.accentFill, 6.4),
            ("on panel", p.onPanel, p.panel, 14.7),
            ("on panel secondary", p.onPanelSecondary, p.panel, 10.3),
            ("wordmark rr on canvas (large)", p.wordmarkRR, p.canvas, 3.0),
            ("field outline on pill", p.fieldLine, p.pill, 4.2),
            ("field outline on canvas", p.fieldLine, p.canvas, 3.8),
            ("field outline on ice", p.fieldLine, p.ice, 3.2),
        ], dark: false)
    }

    func testDarkPairs() {
        let p = Palette.self
        check([
            ("ink on canvas", p.ink, p.canvas, 15.4),
            ("ink on ice", p.ink, p.ice, 12.6),
            ("ink on pill", p.ink, p.pill, 13.6),
            ("secondary on canvas", p.inkSecondary, p.canvas, 9.8),
            ("secondary on ice", p.inkSecondary, p.ice, 8.0),
            ("secondary on pill", p.inkSecondary, p.pill, 8.7),
            ("muted on canvas", p.inkMuted, p.canvas, 7.1),
            ("muted on ice", p.inkMuted, p.ice, 5.8),
            ("muted on pill", p.inkMuted, p.pill, 6.2),
            ("accent on canvas", p.accent, p.canvas, 8.0),
            ("accent on ice", p.accent, p.ice, 6.6),
            ("accent on pill", p.accent, p.pill, 7.1),
            ("ink on accent soft", p.ink, p.accentSoft, 11.6),
            ("danger on canvas", p.danger, p.canvas, 8.4),
            ("danger on ice", p.danger, p.ice, 6.9),
            ("danger on pill", p.danger, p.pill, 7.4),
            ("on danger tint", p.onDangerTint, p.dangerTint, 9.5),
            ("on ink button", p.onInk, p.ink, 15.4),
            ("on accent fill", p.onInk, p.accentFill, 8.0),
            ("wordmark rr on canvas", p.wordmarkRR, p.canvas, 8.0),
            ("field outline on pill", p.fieldLine, p.pill, 4.8),
            ("field outline on ice", p.fieldLine, p.ice, 4.5),
        ], dark: true)
    }

    /// Accent text on the soft fill passes (4.9), but the design system keeps ink for text on it.
    func testAccentTextOnSoftFillStillPassesInLightMode() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.accent.light, Palette.accentSoft.light), 4.8)
    }

    func testAvatarInitialsAreReadable() {
        XCTAssertEqual(Palette.avatars.count, 8)
        for hex in Palette.avatars {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.avatarInitials, hex), 8.8, String(hex, radix: 16))
        }
    }
}
