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
    private let pageSize: Int

    /// - Parameters:
    ///   - table: the table to read, which is also its path under `/rest/v1`.
    ///   - idColumn: the column holding the model's `id`. Pages are ordered by it.
    ///   - pageSize: rows asked for per request. Keep it at or below the server's
    ///     `max-rows` (1000 by default on Supabase), or a full page looks like the last one.
    public init(
        client: any HTTPClient,
        table: String,
        idColumn: String = "id",
        mapper: MapperType,
        decoder: JSONDecoder = JSONCoding.decoder(keys: .snakeCase),
        pageSize: Int = 1000
    ) {
        self.client = client
        self.table = table
        self.idColumn = idColumn
        self.mapper = mapper
        self.decoder = decoder
        self.pageSize = max(1, pageSize)
    }

    /// Every row, read a page at a time so a table over the server's row limit isn't cut
    /// short. It stops at a short page, or at a page that adds nothing new (a server that
    /// ignores `offset`).
    public func fetchAll() async throws -> [Model] {
        var models: [Model] = []
        var seen = Set<String>()
        var offset = 0
        while true {
            let query = [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "\(idColumn).asc"),
                URLQueryItem(name: "limit", value: String(pageSize)),
                URLQueryItem(name: "offset", value: String(offset)),
            ]
            let response = try await client.send(Endpoint(path: table, query: query))
            let page = try decoder.decode([MapperType.DTO].self, from: response.data)
            let fresh = try mapper.models(from: page).filter { seen.insert($0.id).inserted }
            models += fresh
            if page.count < pageSize || fresh.isEmpty { return models }
            offset += pageSize
        }
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
