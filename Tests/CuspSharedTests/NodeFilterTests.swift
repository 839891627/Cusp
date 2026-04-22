import XCTest
@testable import CuspShared

final class NodeFilterTests: XCTestCase {
    func testFiltersByRemarkCaseInsensitively() {
        let configurations = [
            ShadowsocksConfiguration(host: "hk.example.com", port: 443, method: "aes-256-gcm", password: "a", remark: "[vip1] 香港01"),
            ShadowsocksConfiguration(host: "jp.example.com", port: 443, method: "aes-256-gcm", password: "b", remark: "[vip1] 日本01")
        ]

        let filtered = NodeFilter.filter(configurations, query: "香港")

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.remark, "[vip1] 香港01")
    }

    func testFiltersByHostAndMethod() {
        let configurations = [
            ShadowsocksConfiguration(host: "hk.example.com", port: 443, method: "aes-256-gcm", password: "a", remark: "[vip1] 香港01"),
            ShadowsocksConfiguration(host: "us.example.com", port: 443, method: "chacha20-ietf-poly1305", password: "b", remark: "[vip1] 美国01")
        ]

        XCTAssertEqual(NodeFilter.filter(configurations, query: "us.example").count, 1)
        XCTAssertEqual(NodeFilter.filter(configurations, query: "chacha20").count, 1)
    }

    func testReturnsOriginalOrderWhenQueryIsEmpty() {
        let configurations = [
            ShadowsocksConfiguration(host: "a.example.com", port: 443, method: "aes-256-gcm", password: "a", remark: "A"),
            ShadowsocksConfiguration(host: "b.example.com", port: 443, method: "aes-256-gcm", password: "b", remark: "B")
        ]

        let filtered = NodeFilter.filter(configurations, query: "   ")

        XCTAssertEqual(filtered, configurations)
    }
}
