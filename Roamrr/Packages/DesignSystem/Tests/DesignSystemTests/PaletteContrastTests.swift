import XCTest
@testable import DesignSystem

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

    func testLightPairs() {
        let p = Palette.self
        check([
            ("ink on canvas", p.ink, p.canvas, 14.7),
            ("ink on blush", p.ink, p.blush, 14.6),
            ("ink on pill", p.ink, p.pill, 17.0),
            ("secondary on blush", p.inkSecondary, p.blush, 6.2),
            ("secondary on canvas", p.inkSecondary, p.canvas, 6.3),
            ("secondary on pill", p.inkSecondary, p.pill, 7.2),
            ("muted on blush", p.inkMuted, p.blush, 4.9),
            ("muted on canvas", p.inkMuted, p.canvas, 4.9),
            ("muted on pill", p.inkMuted, p.pill, 5.7),
            ("accent on canvas", p.accent, p.canvas, 4.6),
            ("accent on blush", p.accent, p.blush, 4.6),
            ("accent on pill", p.accent, p.pill, 5.3),
            ("ink on accent soft", p.ink, p.accentSoft, 11.2),
            ("danger on blush", p.danger, p.blush, 6.1),
            ("danger on canvas", p.danger, p.canvas, 6.2),
            ("danger on pill", p.danger, p.pill, 7.1),
            ("on danger tint", p.onDangerTint, p.dangerTint, 7.4),
            ("on ink button", p.onInk, p.ink, 17.0),
            ("wordmark rr on canvas (large)", p.wordmarkRR, p.canvas, 3.0),
            ("field outline on pill", p.fieldLine, p.pill, 3.5),
            ("field outline on blush", p.fieldLine, p.blush, 3.0),
        ], dark: false)
    }

    func testDarkPairs() {
        let p = Palette.self
        check([
            ("ink on canvas", p.ink, p.canvas, 15.7),
            ("ink on blush", p.ink, p.blush, 13.7),
            ("ink on pill", p.ink, p.pill, 13.5),
            ("secondary on canvas", p.inkSecondary, p.canvas, 8.7),
            ("secondary on blush", p.inkSecondary, p.blush, 7.6),
            ("secondary on pill", p.inkSecondary, p.pill, 7.4),
            ("muted on canvas", p.inkMuted, p.canvas, 6.0),
            ("muted on blush", p.inkMuted, p.blush, 5.2),
            ("muted on pill", p.inkMuted, p.pill, 5.1),
            ("accent on canvas", p.accent, p.canvas, 8.6),
            ("accent on blush", p.accent, p.blush, 7.5),
            ("accent on pill", p.accent, p.pill, 7.4),
            ("ink on accent soft", p.ink, p.accentSoft, 10.6),
            ("accent on accent soft", p.accent, p.accentSoft, 5.8),
            ("danger on canvas", p.danger, p.canvas, 8.3),
            ("danger on blush", p.danger, p.blush, 7.2),
            ("danger on pill", p.danger, p.pill, 7.1),
            ("on danger tint", p.onDangerTint, p.dangerTint, 9.5),
            ("on ink button", p.onInk, p.ink, 15.7),
            ("wordmark rr on canvas", p.wordmarkRR, p.canvas, 8.6),
            ("field outline on pill", p.fieldLine, p.pill, 4.2),
            ("field outline on blush", p.fieldLine, p.blush, 4.2),
        ], dark: true)
    }

    /// The design system forbids accent text on the soft accent fill in light mode.
    func testAccentTextOnSoftFillStaysBelowTheTextMinimumInLightMode() {
        let ratio = Contrast.ratio(Palette.accent.light, Palette.accentSoft.light)
        XCTAssertLessThan(ratio, 4.5)
    }

    func testAvatarInitialsAreReadable() {
        XCTAssertEqual(Palette.avatars.count, 8)
        for hex in Palette.avatars {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.avatarInitials, hex), 11.0, String(hex, radix: 16))
        }
    }
}
