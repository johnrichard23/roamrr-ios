/// Where a locally stored row stands with the server.
public enum SyncState: String, Codable, Sendable, CaseIterable {
    case synced
    case pending
    case conflict
}
