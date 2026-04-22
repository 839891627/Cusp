import XCTest
@testable import CuspShared

final class SSURLParserTests: XCTestCase {
    func testParsesBase64EncodedURI() throws {
        let uri = "ss://YWVzLTI1Ni1nY206c2VjcmV0QDE5Mi4xNjguMS4xOjgzODg=#Office"

        let config = try SSURLParser.parse(uri)

        XCTAssertEqual(config.host, "192.168.1.1")
        XCTAssertEqual(config.port, 8388)
        XCTAssertEqual(config.method, "aes-256-gcm")
        XCTAssertEqual(config.password, "secret")
        XCTAssertEqual(config.remark, "Office")
    }

    func testParsesSIP002StyleURIWithEncodedUserInfo() throws {
        let uri = "ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTphYjI3YmQ5ZS1mOTdiLTRhYjktYTNmNS1lZDg3MTg5ZWRkMzc@gu.gnodecn.com:21819#%5Bvip1%5D%20%E7%BE%8E%E5%9B%BD02"

        let config = try SSURLParser.parse(uri)

        XCTAssertEqual(config.host, "gu.gnodecn.com")
        XCTAssertEqual(config.port, 21819)
        XCTAssertEqual(config.method, "chacha20-ietf-poly1305")
        XCTAssertEqual(config.password, "ab27bd9e-f97b-4ab9-a3f5-ed87189edd37")
        XCTAssertEqual(config.remark, "[vip1] 美国02")
    }

    func testRejectsInvalidURI() {
        XCTAssertThrowsError(try SSURLParser.parse("ss://not-valid")) { error in
            XCTAssertEqual(error as? SSURLParser.Error, .invalidPayload)
        }
    }
}
