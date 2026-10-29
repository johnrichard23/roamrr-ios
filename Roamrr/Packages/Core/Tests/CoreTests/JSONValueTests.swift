import XCTest
@testable import Core

final class JSONValueTests: XCTestCase {
    private func encode(_ value: JSONValue) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    func testRoundTripKeepsEveryKind() throws {
        let value: JSONValue = .object([
            "amount_minor": .int(100_000),
            "rate": .double(56.5),
            "ok": .bool(true),
            "note": .null,
            "tags": .array([.string("a"), .string("b")]),
        ])
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testIntegersEncodeWithoutDecimalPoint() throws {
        XCTAssertEqual(try encode(.int(100_000)), "100000")
    }

    func testLargeIntegerKeepsPrecision() throws {
        let value = JSONValue.int(9_007_199_254_740_993)
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testFractionDecodesAsDouble() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("56.5".utf8))
        XCTAssertEqual(value, .double(56.5))
    }

    func testWholeNumberDecodesAsInteger() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("42".utf8))
        XCTAssertEqual(value, .int(42))
    }

    func testObjectKeysAreSortedWhenRequested() throws {
        XCTAssertEqual(try encode(.object(["b": .int(2), "a": .int(1)])), #"{"a":1,"b":2}"#)
    }
}
