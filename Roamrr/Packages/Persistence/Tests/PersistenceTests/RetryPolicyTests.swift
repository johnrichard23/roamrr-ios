import XCTest
@testable import Persistence

final class RetryPolicyTests: XCTestCase {
    private let policy = RetryPolicy(baseDelay: 2, maxDelay: 300)

    func testFirstRetryWithFullJitterWaitsTheBaseDelay() {
        XCTAssertEqual(policy.delay(forAttempt: 0, jitter: 1), 2, accuracy: 0.0001)
    }

    func testFirstRetryWithNoJitterWaitsHalfTheBaseDelay() {
        XCTAssertEqual(policy.delay(forAttempt: 0, jitter: 0), 1, accuracy: 0.0001)
    }

    func testDelayDoublesEachAttempt() {
        XCTAssertEqual(policy.delay(forAttempt: 3, jitter: 1), 16, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 3, jitter: 0), 8, accuracy: 0.0001)
    }

    func testDelayIsCapped() {
        XCTAssertEqual(policy.delay(forAttempt: 20, jitter: 1), 300, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 20, jitter: 0), 150, accuracy: 0.0001)
    }

    func testHugeAttemptNumbersDoNotOverflow() {
        XCTAssertEqual(policy.delay(forAttempt: 10_000, jitter: 1), 300, accuracy: 0.0001)
    }

    func testNegativeAttemptCountsAsTheFirst() {
        XCTAssertEqual(policy.delay(forAttempt: -5, jitter: 1), 2, accuracy: 0.0001)
    }

    func testJitterIsClampedToZeroToOne() {
        XCTAssertEqual(policy.delay(forAttempt: 0, jitter: 7), 2, accuracy: 0.0001)
        XCTAssertEqual(policy.delay(forAttempt: 0, jitter: -3), 1, accuracy: 0.0001)
    }
}
