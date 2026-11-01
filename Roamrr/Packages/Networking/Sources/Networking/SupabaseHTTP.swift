import Core
import DataLayer
import Foundation

/// Builds the HTTP client every Supabase call goes through.
public enum SupabaseHTTP {
    /// A client for the project's PostgREST API (`/rest/v1`).
    ///
    /// - The public key goes in the `apikey` header on every request. It is sent to the
    ///   Supabase host only, never to another host a redirect might lead to.
    /// - The signed-in user's token goes in `Authorization`, so the row-level security
    ///   policies see the user. Signed out, only the key is sent.
    /// - Plain HTTP is refused except to the local stack, and only in a dev build.
    ///
    /// - Parameters:
    ///   - accessToken: the current access token, or `nil` when signed out.
    ///   - refreshSession: renews the session after a 401; return `true` on success.
    public static func makeClient(
        config: SupabaseConfig,
        environment: AppEnvironment,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async -> String?,
        refreshSession: (@Sendable () async -> Bool)? = nil
    ) -> URLSessionHTTPClient {
        URLSessionHTTPClient(
            baseURL: config.url.appendingPathComponent("rest/v1"),
            session: session,
            defaultHeaders: ["apikey": config.anonKey, "Accept": "application/json"],
            interceptors: [BearerTokenInterceptor(token: accessToken, refresh: refreshSession)],
            retry: .exponential(),
            security: environment == .dev ? .allowingLocalhost : .standard
        )
    }
}
