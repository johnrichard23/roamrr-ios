import Foundation
import XCTest

/// Loads the shared JSON cases. The same files drive the database tests.
enum GoldenVectors {
    struct File<Case: Decodable>: Decodable {
        let cases: [Case]
    }

    static func load<Case: Decodable>(_ name: String, as type: Case.Type = Case.self) throws -> [Case] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Golden") else {
            throw XCTSkip("missing golden file \(name)")
        }
        return try JSONDecoder().decode(File<Case>.self, from: Data(contentsOf: url)).cases
    }

    static func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }
}

struct RoundingCase: Decodable {
    let name: String
    let value: String
    let expected: String
}

struct ConvertCase: Decodable {
    let name: String
    let amountMinor: Int64
    let from: String
    let to: String
    let rate: String
    let expectedMinor: Int64?
    let expectedError: String?

    enum CodingKeys: String, CodingKey {
        case name, from, to, rate
        case amountMinor = "amount_minor"
        case expectedMinor = "expected_minor"
        case expectedError = "expected_error"
    }
}

struct SharesCase: Decodable {
    let name: String
    let totalMinor: Int64
    let members: [String]
    let weights: [String]
    let expected: [String: Int64]?
    let expectedError: String?

    enum CodingKeys: String, CodingKey {
        case name, members, weights, expected
        case totalMinor = "total_minor"
        case expectedError = "expected_error"
    }
}

struct BalancesCase: Decodable {
    struct Expense: Decodable {
        let payer: String
        let amountTripMinor: Int64
        let shares: [String: Int64]
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case payer, shares, deleted
            case amountTripMinor = "amount_trip_minor"
        }
    }

    struct Settlement: Decodable {
        let from: String
        let to: String
        let amountMinor: Int64
        let deleted: Bool

        enum CodingKeys: String, CodingKey {
            case from, to, deleted
            case amountMinor = "amount_minor"
        }
    }

    let name: String
    let members: [String]
    let expenses: [Expense]
    let settlements: [Settlement]
    let expected: [String: Int64]
}

struct SettlementsCase: Decodable {
    struct Payment: Decodable {
        let from: String
        let to: String
        let amountMinor: Int64

        enum CodingKeys: String, CodingKey {
            case from, to
            case amountMinor = "amount_minor"
        }
    }

    let name: String
    let balances: [String: Int64]
    let expected: [Payment]
}
