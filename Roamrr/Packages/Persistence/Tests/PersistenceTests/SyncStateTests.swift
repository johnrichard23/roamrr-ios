import XCTest
@testable import Persistence

final class SyncStateTests: XCTestCase {
    func testRawValuesMatchTheDatabaseColumn() {
        XCTAssertEqual(SyncState.synced.rawValue, "synced")
        XCTAssertEqual(SyncState.pending.rawValue, "pending")
        XCTAssertEqual(SyncState.conflict.rawValue, "conflict")
    }

    func testThereAreExactlyThreeStates() {
        XCTAssertEqual(SyncState.allCases.count, 3)
    }
}
