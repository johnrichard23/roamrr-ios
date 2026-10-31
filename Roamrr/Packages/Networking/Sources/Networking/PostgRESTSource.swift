import DataLayer
import Foundation

/// Reads a Postgres table through PostgREST.
///
/// PostgREST filters with query items (`?code=eq.USD`) rather than a path per row, so the
/// data layer's path-style `RESTRemoteSource` doesn't fit. This is a `RemoteSource`, so a
/// `Repository` caches it like any other.
public struct PostgRESTSource<MapperType: Mapper>: RemoteSource
where MapperType.DTO: Decodable, MapperType.Model: Identifiable & Sendable, MapperType.Model.ID == String {
    public typealias Model = MapperType.Model

    private let client: any HTTPClient
    private let table: String
    private let idColumn: String
    private let mapper: MapperType
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - table: the table to read, which is also its path under `/rest/v1`.
    ///   - idColumn: the column holding the model's `id`.
    public init(
        client: any HTTPClient,
        table: String,
        idColumn: String = "id",
        mapper: MapperType,
        decoder: JSONDecoder = JSONCoding.decoder(keys: .snakeCase)
    ) {
        self.client = client
        self.table = table
        self.idColumn = idColumn
        self.mapper = mapper
        self.decoder = decoder
    }

    public func fetchAll() async throws -> [Model] {
        let response = try await client.send(Endpoint(path: table, query: [URLQueryItem(name: "select", value: "*")]))
        return try mapper.models(from: decoder.decode([MapperType.DTO].self, from: response.data))
    }

    public func fetch(id: String) async throws -> Model {
        let query = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: idColumn, value: "eq.\(id)"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        let response = try await client.send(Endpoint(path: table, query: query))
        guard let dto = try decoder.decode([MapperType.DTO].self, from: response.data).first else {
            throw NetworkError.notFound(message: nil)
        }
        return try mapper.model(from: dto)
    }
}
