import DataLayer
import XCTest
@testable import Networking

final class PostgRESTSourceTests: XCTestCase {
    private static let rows: [(code: String, name: String, minorUnit: Int)] = [
        ("EUR", "Euro", 2), ("JPY", "Yen", 0), ("KRW", "Won", 0), ("PHP", "Peso", 2), ("USD", "Dollar", 2),
    ]

    private static func json(_ rows: some Sequence<(code: String, name: String, minorUnit: Int)>) -> String {
        let items = rows.map { #"{"code":"\#($0.code)","name":"\#($0.name)","minor_unit":\#($0.minorUnit)}"# }
        return "[" + items.joined(separator: ",") + "]"
    }

    private func source(pageSize: Int, _ reply: @escaping @Sendable (Endpoint) -> HTTPResponse)
        -> (PostgRESTSource<CurrencyMapper>, StubHTTPClient)
    {
        let client = StubHTTPClient(reply)
        return (PostgRESTSource(client: client, table: "currencies", idColumn: "code", mapper: CurrencyMapper(), pageSize: pageSize), client)
    }

    private static func value(_ name: String, in endpoint: Endpoint) -> String? {
        endpoint.query.first { $0.name == name }?.value
    }

    func testEveryPageIsReadNotJustTheFirst() async throws {
        let (source, client) = source(pageSize: 2) { endpoint in
            let limit = Int(Self.value("limit", in: endpoint) ?? "") ?? 0
            let offset = Int(Self.value("offset", in: endpoint) ?? "") ?? 0
            return .json(Self.json(Self.rows.dropFirst(offset).prefix(limit)))
        }

        let all = try await source.fetchAll()

        XCTAssertEqual(all.map(\.code), ["EUR", "JPY", "KRW", "PHP", "USD"])
        XCTAssertEqual(client.requests.count, 3, "2 + 2 + 1 rows: the short page ends it")
        XCTAssertEqual(client.requests.compactMap { Self.value("offset", in: $0) }, ["0", "2", "4"])
    }

    func testPagesAreOrderedByTheIdColumn() async throws {
        let (source, client) = source(pageSize: 10) { _ in .json(Self.json(Self.rows)) }

        _ = try await source.fetchAll()

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(Self.value("order", in: request), "code.asc")
        XCTAssertEqual(Self.value("limit", in: request), "10")
    }

    func testAServerThatIgnoresOffsetDoesNotLoopForever() async throws {
        let (source, client) = source(pageSize: 2) { _ in .json(Self.json(Self.rows.prefix(2))) }

        let all = try await source.fetchAll()

        XCTAssertEqual(all.map(\.code), ["EUR", "JPY"])
        XCTAssertEqual(client.requests.count, 2, "the repeated page adds nothing, so it stops")
    }
}
