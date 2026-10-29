import XCTest
@testable import DesignSystem

final class TextRoleTests: XCTestCase {
    func testMultiLineRolesOpenUpTheirLines() {
        for role in [TextRole.body, .subheadline, .footnote, .caption] {
            XCTAssertGreaterThan(role.lineSpacing, 0, "\(role)")
        }
    }

    func testSingleLineRolesAddNoLineSpacing() {
        for role in [TextRole.display, .title, .headline, .rowAmount] {
            XCTAssertEqual(role.lineSpacing, 0, "\(role)")
        }
    }

    func testLineSpacingStaysSmall() {
        for role in TextRole.allCases {
            XCTAssertLessThanOrEqual(role.lineSpacing, 4, "\(role)")
        }
    }

    /// System fonts already carry their own optical tracking, so any extra value stays tiny.
    func testTrackingStaysTiny() {
        for role in TextRole.allCases {
            XCTAssertLessThanOrEqual(abs(role.tracking), 0.5, "\(role)")
        }
    }

    func testTypographyConstantsComeFromTheRoles() {
        XCTAssertEqual(Typography.body, TextRole.body.font)
        XCTAssertEqual(Typography.caption, TextRole.caption.font)
        XCTAssertEqual(Typography.display, TextRole.display.font)
    }
}
