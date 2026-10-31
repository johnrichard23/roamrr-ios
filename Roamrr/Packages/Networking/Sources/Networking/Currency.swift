import DataLayer
import Foundation

/// A currency Roamrr can record money in. Reference data from the `currencies` table.
public struct Currency: Identifiable, Sendable, Codable, Equatable {
    /// The ISO 4217 code, for example `USD`.
    public let code: String
    public let name: String
    /// Decimal places in the minor unit: 2 for USD, 0 for JPY.
    public let minorUnit: Int

    public var id: String { code }

    public init(code: String, name: String, minorUnit: Int) {
        self.code = code
        self.name = name
        self.minorUnit = minorUnit
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
        guard let code = dto.code, !code.isEmpty else { throw MappingError.missingField("code") }
        guard let minorUnit = dto.minorUnit, (0...4).contains(minorUnit) else {
            throw MappingError.missingField("minor_unit")
        }
        return Currency(code: code, name: dto.name ?? code, minorUnit: minorUnit)
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
