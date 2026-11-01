import XCTest
@testable import Core

final class MoneyExponentTests: XCTestCase {
    func testKnownCurrenciesReportTheirDecimalPlaces() {
        XCTAssertEqual(Money.exponent(for: "USD"), 2)
        XCTAssertEqual(Money.exponent(for: "JPY"), 0)
        XCTAssertEqual(Money.exponent(for: "KWD"), 3)
    }

    func testTheCodeIsMatchedWithoutRegardToCase() {
        XCTAssertEqual(Money.exponent(for: "php"), 2)
    }

    func testAnUnknownCurrencyHasNoExponent() {
        XCTAssertNil(Money.exponent(for: "XTS"))
    }

    func testTheExponentIsTheOneConvertMinorUses() throws {
        // 1 JPY (exponent 0) at 0.5 USD per JPY is 0.50 USD (exponent 2) = 50 minor units.
        XCTAssertEqual(try Money.convertMinor(1, from: "JPY", to: "USD", rate: Decimal(string: "0.5")!), 50)
        XCTAssertEqual(Money.exponent(for: "JPY"), 0)
        XCTAssertEqual(Money.exponent(for: "USD"), 2)
    }
}
