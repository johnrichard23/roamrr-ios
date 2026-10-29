import Foundation

/// Exponential backoff with jitter for retrying a failed sync.
public struct RetryPolicy: Sendable, Equatable {
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(baseDelay: TimeInterval = 2, maxDelay: TimeInterval = 300) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// The wait before a retry. `attempt` is 0 for the first retry. `jitter` is a
    /// number from 0 to 1 supplied by the caller (a random value in production, a
    /// fixed one in tests); it scales the wait between half and all of the backoff.
    public func delay(forAttempt attempt: Int, jitter: Double) -> TimeInterval {
        let exponent = min(max(attempt, 0), 60)
        let backoff = min(maxDelay, baseDelay * pow(2, Double(exponent)))
        let factor = 0.5 + 0.5 * min(max(jitter, 0), 1)
        return backoff * factor
    }
}
