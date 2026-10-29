import XCTest
@testable import Core

final class MutationResultTests: XCTestCase {
    private func decode(_ json: String) throws -> MutationResult {
        try JSONDecoder().decode(MutationResult.self, from: Data(json.utf8))
    }

    func testApplied() throws {
        let result = try decode(#"{"mutation_id":"11111111-2222-4333-8444-555555555555","status":"applied"}"#)
        XCTAssertEqual(result.status, .applied)
        XCTAssertNil(result.code)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.isDuplicate)
    }

    func testRejectedCarriesCodeAndMessage() throws {
        let result = try decode(
            #"{"mutation_id":"11111111-2222-4333-8444-555555555555","status":"rejected","code":"42501","error":"not a member of this trip"}"#
        )
        XCTAssertEqual(result.status, .rejected)
        XCTAssertEqual(result.code, "42501")
        XCTAssertEqual(result.error, "not a member of this trip")
    }

    func testDuplicateFlag() throws {
        let result = try decode(
            #"{"mutation_id":"11111111-2222-4333-8444-555555555555","status":"applied","duplicate":true}"#
        )
        XCTAssertTrue(result.isDuplicate)
    }

    func testUnknownStatusFailsToDecode() {
        XCTAssertThrowsError(
            try decode(#"{"mutation_id":"11111111-2222-4333-8444-555555555555","status":"maybe"}"#)
        )
    }

    func testArrayOfResults() throws {
        let json = #"[{"mutation_id":"11111111-2222-4333-8444-555555555555","status":"applied"},{"mutation_id":"11111111-2222-4333-8444-555555555556","status":"rejected","code":"RM001","error":"amounts must add up to the total"}]"#
        let results = try JSONDecoder().decode([MutationResult].self, from: Data(json.utf8))
        XCTAssertEqual(results.map(\.status), [.applied, .rejected])
    }
}
