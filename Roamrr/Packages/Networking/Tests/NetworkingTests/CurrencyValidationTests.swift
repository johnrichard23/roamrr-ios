import XCTest
@testable import Networking

/// A `Currency` that exists is valid, however it was made: by the mapper, by `init`, or by
/// decoding a cached file.
final class CurrencyValidationTests: XCTestCase {
    func testCodesThatAreNotThreeCapitalLettersAreRejected() {
        for code in ["", "US", "USDX", "usd", "Usd", "U5D", "US ", "€UR"] {
            XCTAssertThrowsError(try Currency(code: code, name: "x", minorUnit: 2), code) { error in
                XCTAssertEqual(error as? CurrencyError, .invalidCode(code))
            }
        }
    }

    func testMinorUnitMustBeBetweenZeroAndFour() {
        XCTAssertThrowsError(try Currency(code: "XTS", name: "x", minorUnit: -1))
        XCTAssertThrowsError(try Currency(code: "XTS", name: "x", minorUnit: 5))
        XCTAssertNoThrow(try Currency(code: "XTS", name: "x", minorUnit: 4))
    }

    func testAMinorUnitThatDisagreesWithMoneyIsRejected() {
        XCTAssertThrowsError(try Currency(code: "USD", name: "US dollar", minorUnit: 0)) { error in
            XCTAssertEqual(error as? CurrencyError, .minorUnitDisagrees(code: "USD", minorUnit: 0, expected: 2))
        }
        XCTAssertThrowsError(try Currency(code: "JPY", name: "Yen", minorUnit: 2))
        XCTAssertNoThrow(try Currency(code: "KWD", name: "Dinar", minorUnit: 3))
    }

    func testACurrencyMoneyDoesNotKnowIsAcceptedSoOneNewRowCannotBreakTheList() throws {
        let currency = try Currency(code: "XTS", name: "Test code", minorUnit: 2)
        XCTAssertEqual(currency.id, "XTS")
    }

    func testDecodingGoesThroughTheSameChecks() throws {
        let good = Data(#"{"code":"USD","name":"US dollar","minorUnit":2}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Currency.self, from: good).code, "USD")

        for bad in [
            #"{"code":"","name":"x","minorUnit":2}"#,
            #"{"code":"usd","name":"x","minorUnit":2}"#,
            #"{"code":"USD","name":"x","minorUnit":9}"#,
            #"{"code":"USD","name":"x","minorUnit":0}"#,
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(Currency.self, from: Data(bad.utf8)), bad)
        }
    }

    func testAnEncodedCurrencyDecodesBackToItself() throws {
        let original = try Currency(code: "PHP", name: "Philippine peso", minorUnit: 2)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Currency.self, from: data), original)
    }

    func testTheMapperRejectsTheSameRows() {
        let mapper = CurrencyMapper()
        XCTAssertThrowsError(try mapper.model(from: CurrencyDTO(code: "usd", name: "x", minorUnit: 2)))
        XCTAssertThrowsError(try mapper.model(from: CurrencyDTO(code: "USD", name: "x", minorUnit: 0)))
        XCTAssertThrowsError(try mapper.model(from: CurrencyDTO(code: nil, name: "x", minorUnit: 2)))
        XCTAssertThrowsError(try mapper.model(from: CurrencyDTO(code: "USD", name: "x", minorUnit: nil)))
    }
}
