import Foundation

/// Money rules. Pure functions on integer minor units; `Decimal` is used only for
/// exact base-10 intermediates. Mirrors the SQL in `0003_money.sql` and must pass
/// the same golden vectors.
public enum Money {
    /// Decimal places per currency. Same list as the `currencies` table.
    private static let exponents: [String: Int] = [
        "PHP": 2, "USD": 2, "EUR": 2, "JPY": 0, "KRW": 0, "SGD": 2, "HKD": 2,
        "THB": 2, "VND": 0, "IDR": 2, "MYR": 2, "TWD": 2, "CNY": 2, "AUD": 2,
        "GBP": 2, "CAD": 2, "AED": 2, "SAR": 2, "CHF": 2, "KWD": 3,
    ]

    /// Rounds to the nearest integer; an exact half goes to the even neighbour.
    public static func roundHalfEven(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .bankers)
        return output
    }

    /// Converts minor units of `from` into minor units of `to`. `rate` is units of
    /// `to` per one unit of `from`. Rounds once, at the end.
    public static func convertMinor(
        _ amount: Int64, from: String, to: String, rate: Decimal
    ) throws -> Int64 {
        guard let fromExponent = exponents[from.uppercased()],
              let toExponent = exponents[to.uppercased()]
        else { throw MoneyError.unsupportedCurrency }
        if from.uppercased() == to.uppercased() { return amount }
        guard rate > 0 else { throw MoneyError.invalidRate }

        let scale = Decimal(sign: .plus, exponent: toExponent - fromExponent, significand: 1)
        let converted = roundHalfEven(Decimal(amount) * rate * scale)
        guard converted >= Decimal(Int64.min), converted <= Decimal(Int64.max) else {
            throw MoneyError.invalidInput
        }
        return NSDecimalNumber(decimal: converted).int64Value
    }

    /// Splits `total` across `members` in proportion to `weights` (largest remainder).
    /// Leftover units go to the largest remainders; ties go to the smaller member id.
    /// Equal split is all weights 1; percent, shares and exact amounts are also weights.
    public static func computeShares(
        total: Int64, members: [String], weights: [Decimal]
    ) throws -> [String: Int64] {
        guard total > 0, !members.isEmpty, members.count == weights.count,
              weights.allSatisfy({ $0 > 0 }), Set(members).count == members.count
        else { throw MoneyError.invalidInput }

        let weightSum = weights.reduce(0, +)
        var rows: [(member: String, base: Int64, remainder: Decimal)] = []
        for (member, weight) in zip(members, weights) {
            let exact = Decimal(total) * weight
            var quotient = roundDown(exact / weightSum)
            var remainder = exact - quotient * weightSum
            if remainder < 0 { quotient -= 1; remainder += weightSum }
            rows.append((member, NSDecimalNumber(decimal: quotient).int64Value, remainder))
        }

        let leftover = total - rows.reduce(0) { $0 + $1.base }
        let ranked = rows.indices.sorted {
            rows[$0].remainder != rows[$1].remainder
                ? rows[$0].remainder > rows[$1].remainder
                : rows[$0].member < rows[$1].member
        }
        var result: [String: Int64] = [:]
        for (rank, index) in ranked.enumerated() {
            result[rows[index].member] = rows[index].base + (Int64(rank) < leftover ? 1 : 0)
        }
        return result
    }

    private static func roundDown(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .down)
        return output
    }
}
