import XCTest
import Core
@testable import Persistence

final class OutboxEntryTests: XCTestCase {
    private let mutation = Mutation(
        mutationID: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
        entity: .expense,
        operation: .upsert,
        payload: .object([:])
    )
    private let policy = RetryPolicy(baseDelay: 2, maxDelay: 300)
    private let created = Date(timeIntervalSince1970: 1_000)

    func testNewEntryIsDueImmediately() {
        let entry = OutboxEntry(mutation: mutation, createdAt: created)
        XCTAssertEqual(entry.failures, 0)
        XCTAssertEqual(entry.nextAttemptDate(policy: policy, jitter: 1), created)
    }

    func testFirstFailureWaitsTheBaseDelay() {
        var entry = OutboxEntry(mutation: mutation, createdAt: created)
        let failedAt = Date(timeIntervalSince1970: 2_000)
        entry.recordFailure(at: failedAt)
        XCTAssertEqual(entry.failures, 1)
        XCTAssertEqual(entry.nextAttemptDate(policy: policy, jitter: 1), failedAt.addingTimeInterval(2))
    }

    func testSecondFailureWaitsLonger() {
        var entry = OutboxEntry(mutation: mutation, createdAt: created)
        entry.recordFailure(at: Date(timeIntervalSince1970: 2_000))
        let secondFailure = Date(timeIntervalSince1970: 2_010)
        entry.recordFailure(at: secondFailure)
        XCTAssertEqual(entry.failures, 2)
        XCTAssertEqual(entry.nextAttemptDate(policy: policy, jitter: 1), secondFailure.addingTimeInterval(4))
    }
}
