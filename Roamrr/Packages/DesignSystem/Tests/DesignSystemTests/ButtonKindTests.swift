import XCTest
@testable import DesignSystem

final class ButtonKindTests: XCTestCase {
    private func ratio(_ colors: ButtonColors, dark: Bool, over background: ColorToken) -> Double {
        let fill = colors.fill ?? background
        return Contrast.ratio(dark ? colors.label.dark : colors.label.light, dark ? fill.dark : fill.light)
    }

    func testPrimaryIsInkWithOnInkLabel() {
        let colors = ButtonKind.primary.colors(isEnabled: true)
        XCTAssertEqual(colors.fill, Palette.ink)
        XCTAssertEqual(colors.label, Palette.onInk)
    }

    func testSecondaryUsesTheSoftAccentFillAndNeutralUsesPill() {
        XCTAssertEqual(ButtonKind.secondary.colors(isEnabled: true).fill, Palette.accentSoft)
        XCTAssertEqual(ButtonKind.neutral.colors(isEnabled: true).fill, Palette.pill)
        XCTAssertEqual(ButtonKind.secondary.colors(isEnabled: true).label, Palette.ink)
        XCTAssertEqual(ButtonKind.neutral.colors(isEnabled: true).label, Palette.ink)
    }

    func testTertiaryAndDestructiveHaveNoFill() {
        XCTAssertNil(ButtonKind.tertiary.colors(isEnabled: true).fill)
        XCTAssertNil(ButtonKind.destructive.colors(isEnabled: true).fill)
        XCTAssertEqual(ButtonKind.tertiary.colors(isEnabled: true).label, Palette.accent)
        XCTAssertEqual(ButtonKind.destructive.colors(isEnabled: true).label, Palette.danger)
    }

    func testEveryEnabledLabelIsReadableInLightAndDark() {
        for kind in ButtonKind.allCases {
            let colors = kind.colors(isEnabled: true)
            for dark in [false, true] {
                for background in [Palette.canvas, Palette.blush] {
                    XCTAssertGreaterThanOrEqual(
                        ratio(colors, dark: dark, over: background), 4.5, "\(kind) \(dark ? "dark" : "light")"
                    )
                }
            }
        }
    }

    func testDisabledButtonsDropTheirKindAndStayReadable() {
        for kind in ButtonKind.allCases {
            let enabled = kind.colors(isEnabled: true)
            let disabled = kind.colors(isEnabled: false)
            XCTAssertNotEqual(enabled, disabled, "\(kind)")
            for dark in [false, true] {
                XCTAssertGreaterThanOrEqual(ratio(disabled, dark: dark, over: Palette.canvas), 3.0, "\(kind) disabled")
            }
        }
        XCTAssertEqual(ButtonKind.primary.colors(isEnabled: false).fill, Palette.hairline)
    }

    func testFilledButtonsAreTallEnoughAndTextButtonsMeetTheTapTarget() {
        XCTAssertEqual(ButtonKind.primary.minHeight, 52)
        XCTAssertEqual(ButtonKind.secondary.minHeight, 52)
        XCTAssertEqual(ButtonKind.neutral.minHeight, 52)
        XCTAssertGreaterThanOrEqual(ButtonKind.tertiary.minHeight, 44)
        XCTAssertGreaterThanOrEqual(ButtonKind.destructive.minHeight, 44)
    }
}
