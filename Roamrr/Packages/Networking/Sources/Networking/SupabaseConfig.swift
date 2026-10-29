import Foundation

/// The Supabase address and public key the app was built with.
public struct SupabaseConfig: Sendable, Equatable {
    public let url: URL
    public let anonKey: String

    /// Reads `SupabaseURL` and `SupabaseAnonKey` from an Info dictionary. Returns nil
    /// when a value is missing, empty, or still an unreplaced `$(...)` build setting,
    /// or when the URL is plain HTTP to anything other than the local stack.
    public init?(infoDictionary: [String: Any]?) {
        guard
            let rawURL = Self.value("SupabaseURL", in: infoDictionary),
            let key = Self.value("SupabaseAnonKey", in: infoDictionary),
            let url = URL(string: rawURL),
            let scheme = url.scheme?.lowercased(),
            let host = url.host
        else { return nil }

        let isLocal = host == "127.0.0.1" || host == "localhost"
        guard scheme == "https" || (scheme == "http" && isLocal) else { return nil }

        self.url = url
        self.anonKey = key
    }

    private static func value(_ key: String, in info: [String: Any]?) -> String? {
        guard let raw = info?[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
