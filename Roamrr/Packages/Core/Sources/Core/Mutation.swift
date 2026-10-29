import Foundation

/// One change waiting to be sent to the server. The encoded form is what the
/// `apply_mutations` function expects.
public struct Mutation: Codable, Sendable, Equatable {
    public enum Entity: String, Codable, Sendable {
        case expense
        case settlement
        case place
        case albumLink = "album_link"
    }

    public enum Operation: String, Codable, Sendable {
        case upsert
        case delete
    }

    public var mutationID: UUID
    public var entity: Entity
    public var operation: Operation
    public var payload: JSONValue

    public init(mutationID: UUID, entity: Entity, operation: Operation, payload: JSONValue) {
        self.mutationID = mutationID
        self.entity = entity
        self.operation = operation
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case mutationID = "mutation_id"
        case entity
        case operation = "op"
        case payload
    }
}
