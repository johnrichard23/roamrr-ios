import Core
import Foundation

/// A mutation waiting in the local outbox, with its retry history.
public struct OutboxEntry: Sendable, Equatable {
    public var mutation: Mutation
    public var createdAt: Date
    public private(set) var failures: Int
    public private(set) var lastFailureAt: Date?

    public init(mutation: Mutation, createdAt: Date) {
        self.mutation = mutation
        self.createdAt = createdAt
        self.failures = 0
        self.lastFailureAt = nil
    }

    public mutating func recordFailure(at date: Date) {
        failures += 1
        lastFailureAt = date
    }

    /// When this entry may be sent again. A new entry is due at once.
    public func nextAttemptDate(policy: RetryPolicy, jitter: Double) -> Date {
        guard let lastFailureAt else { return createdAt }
        return lastFailureAt.addingTimeInterval(policy.delay(forAttempt: failures - 1, jitter: jitter))
    }
}
