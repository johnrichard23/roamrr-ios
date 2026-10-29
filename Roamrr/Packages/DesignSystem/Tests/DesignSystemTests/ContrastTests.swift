import XCTest
@testable import DesignSystem

final class ContrastTests: XCTestCase {
    func testBlackOnWhiteIs21() {
        XCTAssertEqual(Contrast.ratio(0x000000, 0xFFFFFF), 21, accuracy: 0.001)
    }

    func testSameColorIs1() {
        XCTAssertEqual(Contrast.ratio(0x336699, 0x336699), 1, accuracy: 0.001)
    }

    func testOrderDoesNotMatter() {
        XCTAssertEqual(Contrast.ratio(0x1D1C19, 0xFBEBE2), Contrast.ratio(0xFBEBE2, 0x1D1C19), accuracy: 0.0001)
    }
}
