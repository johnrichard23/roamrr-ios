import XCTest
@testable import Core

final class MoneyVectorTests: XCTestCase {
    func testRounding() throws {
        for c in try GoldenVectors.load("rounding", as: RoundingCase.self) {
            let got = Money.roundHalfEven(GoldenVectors.decimal(c.value))
            XCTAssertEqual(got, GoldenVectors.decimal(c.expected), c.name)
        }
    }

    func testConversion() throws {
        for c in try GoldenVectors.load("convert", as: ConvertCase.self) {
            let rate = GoldenVectors.decimal(c.rate)
            if let expected = c.expectedMinor {
                XCTAssertEqual(try Money.convertMinor(c.amountMinor, from: c.from, to: c.to, rate: rate), expected, c.name)
            } else {
                let error = MoneyError(vectorName: c.expectedError ?? "")
                XCTAssertThrowsError(try Money.convertMinor(c.amountMinor, from: c.from, to: c.to, rate: rate), c.name) {
                    XCTAssertEqual($0 as? MoneyError, error, c.name)
                }
            }
        }
    }

    func testShares() throws {
        for c in try GoldenVectors.load("shares", as: SharesCase.self) {
            let weights = c.weights.map(GoldenVectors.decimal)
            if let expected = c.expected {
                XCTAssertEqual(try Money.computeShares(total: c.totalMinor, members: c.members, weights: weights), expected, c.name)
            } else {
                XCTAssertThrowsError(try Money.computeShares(total: c.totalMinor, members: c.members, weights: weights), c.name) {
                    XCTAssertEqual($0 as? MoneyError, .invalidInput, c.name)
                }
            }
        }
    }

    func testBalances() throws {
        for c in try GoldenVectors.load("balances", as: BalancesCase.self) {
            let expenses = c.expenses.map {
                ExpenseRecord(payer: $0.payer, amountMinor: $0.amountTripMinor, shares: $0.shares, isDeleted: $0.deleted)
            }
            let settlements = c.settlements.map {
                SettlementRecord(from: $0.from, to: $0.to, amountMinor: $0.amountMinor, isDeleted: $0.deleted)
            }
            XCTAssertEqual(Money.netBalances(members: c.members, expenses: expenses, settlements: settlements), c.expected, c.name)
        }
    }

    func testSimplification() throws {
        for c in try GoldenVectors.load("settlements", as: SettlementsCase.self) {
            let expected = c.expected.map { Payment(from: $0.from, to: $0.to, amountMinor: $0.amountMinor) }
            XCTAssertEqual(Money.simplify(c.balances), expected, c.name)
        }
    }
}

private extension MoneyError {
    init(vectorName: String) {
        switch vectorName {
        case "unsupported_currency": self = .unsupportedCurrency
        case "invalid_rate": self = .invalidRate
        default: self = .invalidInput
        }
    }
}
