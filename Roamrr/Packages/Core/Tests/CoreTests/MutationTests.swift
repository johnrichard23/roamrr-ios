import XCTest
@testable import Core

final class MutationTests: XCTestCase {
    private let id = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!

    func testEncodesWithTheServerKeys() throws {
        let mutation = Mutation(
            mutationID: id,
            entity: .albumLink,
            operation: .upsert,
            payload: .object(["id": .string("x")])
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(mutation), as: UTF8.self)
        XCTAssertEqual(
            json,
            #"{"entity":"album_link","mutation_id":"11111111-2222-4333-8444-555555555555","op":"upsert","payload":{"id":"x"}}"#
        )
    }

    func testEntityRawValuesMatchTheServer() {
        XCTAssertEqual(Mutation.Entity.expense.rawValue, "expense")
        XCTAssertEqual(Mutation.Entity.settlement.rawValue, "settlement")
        XCTAssertEqual(Mutation.Entity.place.rawValue, "place")
        XCTAssertEqual(Mutation.Entity.albumLink.rawValue, "album_link")
    }

    func testOperationRawValuesMatchTheServer() {
        XCTAssertEqual(Mutation.Operation.upsert.rawValue, "upsert")
        XCTAssertEqual(Mutation.Operation.delete.rawValue, "delete")
    }

    func testRoundTrip() throws {
        let mutation = Mutation(
            mutationID: id, entity: .expense, operation: .delete, payload: .object(["id": .string("e1")])
        )
        let data = try JSONEncoder().encode(mutation)
        XCTAssertEqual(try JSONDecoder().decode(Mutation.self, from: data), mutation)
    }
}
