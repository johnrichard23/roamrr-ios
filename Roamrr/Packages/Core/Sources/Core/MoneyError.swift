/// Why a money calculation was refused. The cases match the error names in the
/// golden vectors.
public enum MoneyError: Error, Equatable, Sendable {
    case invalidInput
    case unsupportedCurrency
    case invalidRate
}
