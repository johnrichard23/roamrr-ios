import DataLayer
import XCTest
@testable import Networking

final class CurrencyTests: XCTestCase {
    private static let rows = #"[{"code":"USD","name":"US dollar","minor_unit":2},{"code":"JPY","name":"Yen","minor_unit":0}]"#

    private func repository(_ reply: @escaping @Sendable (Endpoint) -> HTTPResponse) -> (Repository<Currency>, StubHTTPClient) {
        let client = StubHTTPClient(reply)
        return (.currencies(client: client, store: InMemoryStore()), client)
    }

    func testRowsBecomeCurrenciesAndAskForTheWholeTable() async throws {
        let (currencies, client) = repository { _ in .json(Self.rows) }

        let all = try await currencies.all()

        XCTAssertEqual(all.map(\.code).sorted(), ["JPY", "USD"])
        XCTAssertEqual(all.first { $0.code == "JPY" }?.minorUnit, 0)
        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.path, "currencies")
        XCTAssertEqual(request.query.first { $0.name == "select" }?.value, "*")
    }

    func testOneCurrencyIsFilteredByCode() async throws {
        let (currencies, client) = repository { _ in .json(#"[{"code":"USD","name":"US dollar","minor_unit":2}]"#) }

        let usd = try await currencies.item(id: "USD", policy: .networkOnly)

        XCTAssertEqual(usd.name, "US dollar")
        let query = try XCTUnwrap(client.requests.first).query
        XCTAssertEqual(query.first { $0.name == "code" }?.value, "eq.USD")
        XCTAssertEqual(query.first { $0.name == "limit" }?.value, "1")
    }

    func testSecondReadComesFromTheCache() async throws {
        let (currencies, client) = repository { _ in .json(Self.rows) }
        _ = try await currencies.all()
        _ = try await currencies.all()
        XCTAssertEqual(client.requests.count, 1)
    }

    func testARowWithoutACodeIsReportedNotShownAsABlankCurrency() async throws {
        let (currencies, _) = repository { _ in .json(#"[{"name":"Mystery","minor_unit":2}]"#) }
        do {
            _ = try await currencies.all()
            XCTFail("should throw")
        } catch {}
    }

    func testMinorUnitOutsideZeroToFourIsRejected() throws {
        XCTAssertThrowsError(try CurrencyMapper().model(from: CurrencyDTO(code: "XXX", name: "x", minorUnit: 9)))
    }
}
