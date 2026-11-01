import DesignSystem
import SwiftUI
import UIKit
import XCTest
@testable import RoamrrDesign

/// The Roamrr theme is the palette in the shared theme's roles. These tests read the
/// colors back out of the theme in both appearances and check them against the palette,
/// and check the contrast of every pairing the buttons draw.
final class ThemeMappingTests: XCTestCase {
    private let theme = DesignSystem.Theme.roamrr

    private func hex(_ color: Color, dark: Bool) -> UInt32 {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let byte = { (value: CGFloat) in UInt32((value * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    private func alpha(_ color: Color, dark: Bool) -> CGFloat {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return alpha
    }

    private func assertMatches(_ color: Color, _ token: ColorToken, _ name: String) {
        XCTAssertEqual(hex(color, dark: false), token.light, "\(name) light")
        XCTAssertEqual(hex(color, dark: true), token.dark, "\(name) dark")
    }

    // MARK: Colors

    func testRolesComeFromThePalette() {
        assertMatches(theme.accent, Palette.accent, "accent")
        assertMatches(theme.onAccent, Palette.onInk, "onAccent")
        assertMatches(theme.background, Palette.canvas, "background")
        assertMatches(theme.surface, Palette.pill, "surface")
        assertMatches(theme.surfacePressed, Palette.hairline, "surfacePressed")
        assertMatches(theme.labelPrimary, Palette.ink, "labelPrimary")
        assertMatches(theme.labelSecondary, Palette.inkSecondary, "labelSecondary")
        assertMatches(theme.labelTertiary, Palette.inkMuted, "labelTertiary")
        assertMatches(theme.border, Palette.fieldLine, "border")
        assertMatches(theme.separator, Palette.hairline, "separator")
        assertMatches(theme.destructive, Palette.danger, "destructive")
    }

    func testColorTokenFollowsTheAppearance() {
        assertMatches(Color.Roamrr.canvas, Palette.canvas, "canvas")
        assertMatches(Color.Roamrr.wordmarkRR, Palette.wordmarkRR, "wordmarkRR")
    }

    // MARK: Buttons

    private func kinds() -> [(String, DesignSystem.ButtonKind)] {
        [("ink", .ink), ("soft", .soft), ("neutral", .neutral), ("plain", .plain), ("dangerText", .dangerText)]
    }

    func testEveryButtonLabelIsReadableOnItsFillInLightAndDark() {
        for (name, kind) in kinds() {
            let colors = kind.colors(theme)
            for dark in [false, true] {
                // A text-only kind has a clear fill, so the label sits on the canvas.
                // Judged by alpha: an opaque black fill has the same hex value as clear.
                let isTextOnly = alpha(colors.fill, dark: dark) == 0
                let background = isTextOnly ? theme.background : colors.fill
                let ratio = Contrast.ratio(hex(colors.foreground, dark: dark), hex(background, dark: dark))
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) \(dark ? "dark" : "light")")
            }
        }
    }

    func testAnOpaqueBlackFillIsNotMistakenForAClearOne() {
        // Black and clear have the same hex value; only alpha tells them apart.
        XCTAssertEqual(hex(.black, dark: false), hex(.clear, dark: false))
        XCTAssertEqual(alpha(.black, dark: false), 1)
        XCTAssertEqual(alpha(.black, dark: true), 1)
        XCTAssertEqual(alpha(.clear, dark: false), 0)
        XCTAssertEqual(alpha(.clear, dark: true), 0)
    }

    func testInkIsThePrimaryLookAndSoftUsesTheSoftAccent() {
        let ink = DesignSystem.ButtonKind.ink.colors(theme)
        assertMatches(ink.fill, Palette.ink, "ink fill")
        assertMatches(ink.foreground, Palette.onInk, "ink label")
        assertMatches(DesignSystem.ButtonKind.soft.colors(theme).fill, Palette.accentSoft, "soft fill")
        assertMatches(DesignSystem.ButtonKind.neutral.colors(theme).fill, Palette.pill, "neutral fill")
        assertMatches(DesignSystem.ButtonKind.dangerText.colors(theme).foreground, Palette.danger, "danger")
    }

    /// A disabled button draws its label in `labelTertiary` on `surfacePressed`.
    func testDisabledButtonsStayReadable() {
        for dark in [false, true] {
            let ratio = Contrast.ratio(
                hex(theme.labelTertiary, dark: dark), hex(theme.surfacePressed, dark: dark)
            )
            XCTAssertGreaterThanOrEqual(ratio, 3.0, dark ? "dark" : "light")
        }
    }

    // MARK: Tokens

    func testSpacing() {
        XCTAssertEqual(theme.spacing.screenMarginCompact, 20)
        XCTAssertEqual(theme.spacing.screenMarginRegular, 20)
        XCTAssertEqual(theme.spacing.sectionGap, 32)
        XCTAssertEqual(theme.spacing.cardPadding, 20)
    }

    func testRadiiAndButtonSizes() {
        XCTAssertEqual(theme.radius.card, 24)
        XCTAssertEqual(theme.radius.field, 16)
        XCTAssertEqual(theme.radius.control, 14)
        XCTAssertGreaterThanOrEqual(theme.radius.button, theme.size.buttonHeight / 2, "capsule")
        XCTAssertEqual(theme.size.buttonHeight, 52)
        XCTAssertGreaterThanOrEqual(theme.size.compactButtonHeight, DesignSystem.minTapTarget)
    }

    func testDisplayTitleIsSerifAndOtherRolesStayOnTheSystemDesign() {
        XCTAssertEqual(theme.typography.largeTitle.design, .serif)
        for role in DesignSystem.TextRole.allCases where role != .largeTitle {
            XCTAssertEqual(theme.typography[role].design, .default, "\(role)")
        }
    }
}
