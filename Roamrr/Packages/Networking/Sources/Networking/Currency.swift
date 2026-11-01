import Core
import DataLayer
import Foundation

/// Why a currency was refused.
public enum CurrencyError: Error, Equatable {
    /// The code isn't three capital letters.
    case invalidCode(String)
    /// The minor unit isn't between 0 and 4.
    case invalidMinorUnit(Int)
    /// `Money` converts this currency with a different number of decimal places.
    case minorUnitDisagrees(code: String, minorUnit: Int, expected: Int)
}

/// A currency Roamrr can record money in. Reference data from the `currencies` table.
///
/// The rules are checked in one place, `init`, which decoding also goes through, so a
/// `Currency` that exists is a valid one.
public struct Currency: Identifiable, Sendable, Codable, Equatable {
    /// The ISO 4217 code, for example `USD`.
    public let code: String
    public let name: String
    /// Decimal places in the minor unit: 2 for USD, 0 for JPY.
    public let minorUnit: Int

    public var id: String { code }

    /// - Throws: `CurrencyError` if the code isn't three capital letters, the minor unit
    ///   isn't 0 to 4, or it differs from the places `Money` uses for that code. A code
    ///   `Money` doesn't know is accepted; converting it later fails with
    ///   `MoneyError.unsupportedCurrency` instead of rejecting the whole list.
    public init(code: String, name: String, minorUnit: Int) throws {
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else {
            throw CurrencyError.invalidCode(code)
        }
        guard (0...4).contains(minorUnit) else { throw CurrencyError.invalidMinorUnit(minorUnit) }
        if let expected = Money.exponent(for: code), expected != minorUnit {
            throw CurrencyError.minorUnitDisagrees(code: code, minorUnit: minorUnit, expected: expected)
        }
        self.code = code
        self.name = name
        self.minorUnit = minorUnit
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            code: container.decode(String.self, forKey: .code),
            name: container.decode(String.self, forKey: .name),
            minorUnit: container.decode(Int.self, forKey: .minorUnit)
        )
    }
}

/// A `currencies` row as the server sends it. Fields are optional so one odd row
/// is reported by the mapper instead of failing the whole decode.
public struct CurrencyDTO: Codable, Sendable {
    public var code: String?
    public var name: String?
    public var minorUnit: Int?
}

/// The only place the row and the model meet.
public struct CurrencyMapper: Mapper {
    public init() {}

    public func model(from dto: CurrencyDTO) throws -> Currency {
        guard let code = dto.code else { throw MappingError.missingField("code") }
        guard let minorUnit = dto.minorUnit else { throw MappingError.missingField("minor_unit") }
        return try Currency(code: code, name: dto.name ?? code, minorUnit: minorUnit)
    }

    public func dto(from model: Currency) throws -> CurrencyDTO {
        CurrencyDTO(code: model.code, name: model.name, minorUnit: model.minorUnit)
    }
}

public extension Repository where Model == Currency {
    /// Currencies, kept on disk. They change almost never, so a cached list is used for a
    /// day before it is refreshed.
    static func currencies(client: any HTTPClient, store: any Store<Currency> = FileStore(name: "currencies")) -> Repository<Currency> {
        Repository(
            remote: PostgRESTSource(client: client, table: "currencies", idColumn: "code", mapper: CurrencyMapper()),
            store: store,
            policy: .cacheAndRefresh(staleAfter: 24 * 60 * 60, expireAfter: 30 * 24 * 60 * 60)
        )
    }
}
