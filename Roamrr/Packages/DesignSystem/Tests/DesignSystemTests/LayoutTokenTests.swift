import XCTest
@testable import DesignSystem

final class LayoutTokenTests: XCTestCase {
    func testSpacingScale() {
        XCTAssertEqual(Spacing.scale, [4, 8, 12, 16, 20, 24, 32, 48])
    }

    func testSpacingScaleIsAscendingMultiplesOfFour() {
        XCTAssertEqual(Spacing.scale, Spacing.scale.sorted())
        XCTAssertTrue(Spacing.scale.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
    }

    func testNamedSpacingComesFromTheScale() {
        XCTAssertEqual(Spacing.screenMargin, 20)
        XCTAssertEqual(Spacing.sectionGap, 32)
        XCTAssertEqual(Spacing.cardPadding, 20)
        XCTAssertEqual(Spacing.rowMinHeight, 60)
        XCTAssertTrue(Spacing.scale.contains(Spacing.screenMargin))
        XCTAssertTrue(Spacing.scale.contains(Spacing.sectionGap))
    }

    func testRadii() {
        XCTAssertEqual(Radius.card, 24)
        XCTAssertEqual(Radius.field, 16)
        XCTAssertEqual(Radius.pin, 14)
    }
}
