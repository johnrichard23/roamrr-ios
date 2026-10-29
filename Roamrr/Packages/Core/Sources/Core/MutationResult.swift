import Foundation

/// The server's answer for one mutation.
public struct MutationResult: Decodable, Sendable, Equatable {
    public enum Status: String, Decodable, Sendable {
        case applied
        case rejected
    }

    public var mutationID: UUID
    public var status: Status
    /// A SQLSTATE such as `42501`, or `RM001` for a rule the server enforces.
    public var code: String?
    /// A message that is safe to show, or `internal error`.
    public var error: String?
    /// True when the server had already applied this mutation earlier.
    public var isDuplicate: Bool

    private enum CodingKeys: String, CodingKey {
        case mutationID = "mutation_id"
        case status
        case code
        case error
        case duplicate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mutationID = try container.decode(UUID.self, forKey: .mutationID)
        status = try container.decode(Status.self, forKey: .status)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        isDuplicate = try container.decodeIfPresent(Bool.self, forKey: .duplicate) ?? false
    }
}
