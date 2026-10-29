import XCTest
@testable import Core

/// Random cases from a fixed seed, so a failure always reproduces.
final class MoneyPropertyTests: XCTestCase {
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func id(_ n: Int) -> String { String(format: "00000000-0000-4000-8000-%012x", n) }

    func testSharesAlwaysAddUpAndStayWithinOneUnitOfExact() throws {
        var rng = SplitMix64(state: 42)
        for _ in 0 ..< 500 {
            let count = Int.random(in: 1 ... 12, using: &rng)
            let total = Int64.random(in: 1 ... 5_000_000, using: &rng)
            let members = (1 ... count).map(id)
            let weights = (0 ..< count).map { _ in Decimal(Int.random(in: 1 ... 40, using: &rng)) }
            let shares = try Money.computeShares(total: total, members: members, weights: weights)
            XCTAssertEqual(shares.values.reduce(0, +), total)
            let weightSum = weights.reduce(0, +)
            for (member, weight) in zip(members, weights) {
                let exact = Decimal(total) * weight / weightSum
                let diff = abs(NSDecimalNumber(decimal: Decimal(shares[member] ?? 0) - exact).doubleValue)
                XCTAssertLessThan(diff, 1)
            }
        }
    }

    func testSharesDoNotDependOnInputOrder() throws {
        var rng = SplitMix64(state: 7)
        for _ in 0 ..< 200 {
            let count = Int.random(in: 2 ... 10, using: &rng)
            let total = Int64.random(in: 1 ... 1_000_000, using: &rng)
            let members = (1 ... count).map(id)
            let weights = (0 ..< count).map { _ in Decimal(Int.random(in: 1 ... 9, using: &rng)) }
            let straight = try Money.computeShares(total: total, members: members, weights: weights)
            let order = Array(0 ..< count).shuffled(using: &rng)
            let shuffled = try Money.computeShares(
                total: total, members: order.map { members[$0] }, weights: order.map { weights[$0] }
            )
            XCTAssertEqual(straight, shuffled)
        }
    }

    func testBalancesSumToZeroAndSimplificationClearsEveryone() throws {
        var rng = SplitMix64(state: 99)
        for _ in 0 ..< 300 {
            let count = Int.random(in: 2 ... 10, using: &rng)
            let members = (1 ... count).map(id)
            var expenses: [ExpenseRecord] = []
            for _ in 0 ..< Int.random(in: 1 ... 8, using: &rng) {
                let total = Int64.random(in: 1 ... 200_000, using: &rng)
                let payer = members.randomElement(using: &rng)!
                let shares = try Money.computeShares(
                    total: total, members: members, weights: members.map { _ in Decimal(Int.random(in: 1 ... 5, using: &rng)) }
                )
                expenses.append(ExpenseRecord(payer: payer, amountMinor: total, shares: shares, isDeleted: false))
            }
            let nets = Money.netBalances(members: members, expenses: expenses, settlements: [])
            XCTAssertEqual(nets.values.reduce(0, +), 0)

            let payments = Money.simplify(nets)
            XCTAssertLessThanOrEqual(payments.count, max(count - 1, 0))
            var after = nets
            for p in payments {
                XCTAssertGreaterThan(p.amountMinor, 0)
                after[p.from, default: 0] += p.amountMinor
                after[p.to, default: 0] -= p.amountMinor
            }
            XCTAssertTrue(after.values.allSatisfy { $0 == 0 })
            XCTAssertEqual(Money.simplify(nets), payments, "same input, same list")
        }
    }
}
