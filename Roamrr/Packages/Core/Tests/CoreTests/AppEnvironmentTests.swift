import XCTest
@testable import Core

final class AppEnvironmentTests: XCTestCase {
    func testDevSuffixIsDev() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "com.roamrr.dev"), .dev)
    }

    func testUATSuffixIsUAT() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "com.roamrr.uat"), .uat)
    }

    func testNoSuffixIsProd() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "com.roamrr"), .prod)
    }

    func testPrefixDoesNotMatter() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "app.example.roamrr.uat"), .uat)
    }

    func testOnlyDevAndUATSuffixesAreNotProd() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "com.roamrr.beta"), .prod)
    }

    func testSuffixIsCaseInsensitive() {
        XCTAssertEqual(AppEnvironment(bundleIdentifier: "com.roamrr.DEV"), .dev)
    }
}
