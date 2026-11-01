import Core
import DataLayer
import XCTest
@testable import Networking

/// Replies to every request with a fixed body and records what was sent.
private final class RecordingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var body = Data("[]".utf8)
    private static let lock = NSLock()

    static func reset() { lock.withLock { requests = [] } }
    static var last: URLRequest? { lock.withLock { requests.last } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.requests.append(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class SupabaseHTTPTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingProtocol.self]
        session = URLSession(configuration: configuration)
        RecordingProtocol.reset()
    }

    private func config(_ url: String) throws -> SupabaseConfig {
        try XCTUnwrap(SupabaseConfig(infoDictionary: ["SupabaseURL": url, "SupabaseAnonKey": "public-key"]))
    }

    private func client(_ url: String, _ environment: AppEnvironment, token: String? = "user-token") throws -> URLSessionHTTPClient {
        SupabaseHTTP.makeClient(
            config: try config(url), environment: environment, session: session, accessToken: { token }
        )
    }

    func testRequestsGoToRestV1WithTheKeyAndTheUsersToken() async throws {
        let http = try client("https://abc.supabase.co", .prod)
        _ = try await http.send(Endpoint(path: "currencies"))

        let request = try XCTUnwrap(RecordingProtocol.last)
        XCTAssertEqual(request.url?.path, "/rest/v1/currencies")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user-token")
    }

    func testSignedOutSendsTheKeyButNoAuthorization() async throws {
        let http = try client("https://abc.supabase.co", .prod, token: nil)
        _ = try await http.send(Endpoint(path: "currencies"))

        let request = try XCTUnwrap(RecordingProtocol.last)
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testTheLocalStackOverPlainHTTPIsAllowedInDevOnly() async throws {
        let dev = try client("http://127.0.0.1:54321", .dev)
        _ = try await dev.send(Endpoint(path: "currencies"))
        XCTAssertEqual(RecordingProtocol.last?.url?.absoluteString, "http://127.0.0.1:54321/rest/v1/currencies")

        RecordingProtocol.reset()
        let prod = try client("http://127.0.0.1:54321", .prod)
        do {
            _ = try await prod.send(Endpoint(path: "currencies"))
            XCTFail("a production build must not send over plain HTTP")
        } catch {
            XCTAssertEqual(error as? NetworkError, .insecureConnection)
        }
        XCTAssertNil(RecordingProtocol.last, "nothing is sent")
    }
}
