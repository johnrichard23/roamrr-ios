import XCTest
@testable import Networking

final class SupabaseConfigTests: XCTestCase {
    private func config(url: String?, key: String?) -> SupabaseConfig? {
        var info: [String: Any] = [:]
        if let url { info["SupabaseURL"] = url }
        if let key { info["SupabaseAnonKey"] = key }
        return SupabaseConfig(infoDictionary: info)
    }

    func testHTTPSURLIsAccepted() {
        let result = config(url: "https://abc.supabase.co", key: "key")
        XCTAssertEqual(result?.url.absoluteString, "https://abc.supabase.co")
        XCTAssertEqual(result?.anonKey, "key")
    }

    func testLocalHTTPIsAcceptedForTheLocalStack() {
        XCTAssertNotNil(config(url: "http://127.0.0.1:54321", key: "key"))
        XCTAssertNotNil(config(url: "http://localhost:54321", key: "key"))
    }

    func testRemoteHTTPIsRejected() {
        XCTAssertNil(config(url: "http://example.com", key: "key"))
    }

    func testMissingValuesAreRejected() {
        XCTAssertNil(config(url: nil, key: "key"))
        XCTAssertNil(config(url: "https://abc.supabase.co", key: nil))
        XCTAssertNil(SupabaseConfig(infoDictionary: nil))
    }

    func testEmptyValuesAreRejected() {
        XCTAssertNil(config(url: "", key: "key"))
        XCTAssertNil(config(url: "https://abc.supabase.co", key: "   "))
    }

    func testUnsubstitutedBuildSettingIsRejected() {
        XCTAssertNil(config(url: "$(SUPABASE_URL)", key: "key"))
        XCTAssertNil(config(url: "https://abc.supabase.co", key: "$(SUPABASE_ANON_KEY)"))
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(config(url: " https://abc.supabase.co \n", key: " key ")?.anonKey, "key")
    }
}
