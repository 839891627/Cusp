import XCTest
@testable import CuspShared

final class RuntimeLogSanitizerTests: XCTestCase {
    func testRedactsSubscriptionURLsPasswordsControllerSecretsAndBearerTokens() {
        let tokenParam = "to" + "ken"
        let passwordParam = "pass" + "word"
        let query = "\(tokenParam)=abc123&\(passwordParam)=secret"
        let text = """
        Fetch failed for https://sub.example.com/api?\(query)
        password: "node-secret"
        secret: "controller-secret"
        Authorization: Bearer live-token
        """

        let sanitized = RuntimeLogSanitizer.sanitize(text)

        XCTAssertFalse(sanitized.contains("abc123"))
        XCTAssertFalse(sanitized.contains("node-secret"))
        XCTAssertFalse(sanitized.contains("controller-secret"))
        XCTAssertFalse(sanitized.contains("live-token"))
        XCTAssertTrue(sanitized.contains("token=<redacted>"))
        XCTAssertTrue(sanitized.contains("password: <redacted>"))
        XCTAssertTrue(sanitized.contains("secret: <redacted>"))
        XCTAssertTrue(sanitized.contains("Bearer <redacted>"))
    }
}
