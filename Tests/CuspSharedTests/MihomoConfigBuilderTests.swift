import XCTest
@testable import CuspShared

final class MihomoConfigBuilderTests: XCTestCase {
    func testBuildsMinimalConfigFromShadowsocksNode() {
        let config = ShadowsocksConfiguration(
            host: "1.2.3.4",
            port: 8388,
            method: "aes-256-gcm",
            password: "secret",
            remark: "Office"
        )

        let yaml = MihomoConfigBuilder.build(
            from: config,
            localHTTPPort: 1086,
            localSOCKSPort: 1087
        )

        XCTAssertTrue(yaml.contains("mixed-port: 1086"))
        XCTAssertTrue(yaml.contains("socks-port: 1087"))
        XCTAssertTrue(yaml.contains("type: ss"))
        XCTAssertTrue(yaml.contains("server: \"1.2.3.4\""))
        XCTAssertTrue(yaml.contains("cipher: \"aes-256-gcm\""))
        XCTAssertTrue(yaml.contains("name: \"Office\""))
    }

    func testQuotesProxyNamesWithYAMLSpecialCharacters() {
        let config = ShadowsocksConfiguration(
            host: "8.8.8.8",
            port: 443,
            method: "chacha20-ietf-poly1305",
            password: "secret",
            remark: "[vip1] 台湾01"
        )

        let yaml = MihomoConfigBuilder.build(from: config)

        XCTAssertTrue(yaml.contains("name: \"[vip1] 台湾01\""))
        XCTAssertTrue(yaml.contains("- \"[vip1] 台湾01\""))
    }

    func testBuildsMinimalConfigFromVLESSNode() {
        let config = ShadowsocksConfiguration(
            host: "hk.example.com",
            port: 443,
            remark: "HK 01",
            protocolType: .vless,
            uuid: "212f3ab5-4456-4bd9-ba69-88610646d415",
            tls: true,
            skipCertVerify: false,
            flow: "xtls-rprx-vision",
            clientFingerprint: "safari",
            serverName: "edge.example.com",
            udp: true
        )

        let yaml = MihomoConfigBuilder.build(from: config)

        XCTAssertTrue(yaml.contains("type: vless"))
        XCTAssertTrue(yaml.contains("server: \"hk.example.com\""))
        XCTAssertTrue(yaml.contains("uuid: \"212f3ab5-4456-4bd9-ba69-88610646d415\""))
        XCTAssertTrue(yaml.contains("tls: true"))
        XCTAssertTrue(yaml.contains("skip-cert-verify: false"))
        XCTAssertTrue(yaml.contains("flow: \"xtls-rprx-vision\""))
        XCTAssertTrue(yaml.contains("client-fingerprint: \"safari\""))
        XCTAssertTrue(yaml.contains("servername: \"edge.example.com\""))
    }

    func testBuildsMinimalConfigFromVMessNode() {
        let config = ShadowsocksConfiguration(
            host: "jp.example.com",
            port: 443,
            method: "auto",
            remark: "JP 01",
            protocolType: .vmess,
            uuid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            tls: true,
            skipCertVerify: true,
            serverName: "cdn.example.com",
            udp: true,
            alterID: 0,
            network: "ws",
            wsPath: "/ws",
            wsHost: "ws.example.com"
        )

        let yaml = MihomoConfigBuilder.build(from: config)

        XCTAssertTrue(yaml.contains("type: vmess"))
        XCTAssertTrue(yaml.contains("uuid: \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\""))
        XCTAssertTrue(yaml.contains("alterId: 0"))
        XCTAssertTrue(yaml.contains("cipher: \"auto\""))
        XCTAssertTrue(yaml.contains("network: \"ws\""))
        XCTAssertTrue(yaml.contains("servername: \"cdn.example.com\""))
        XCTAssertTrue(yaml.contains("path: \"/ws\""))
        XCTAssertTrue(yaml.contains("Host: \"ws.example.com\""))
    }

    func testBuildsMinimalConfigFromTrojanNode() {
        let config = ShadowsocksConfiguration(
            host: "us.example.com",
            port: 443,
            password: "top-secret",
            remark: "US 01",
            protocolType: .trojan,
            skipCertVerify: false,
            serverName: "trojan.example.com",
            udp: true
        )

        let yaml = MihomoConfigBuilder.build(from: config)

        XCTAssertTrue(yaml.contains("type: trojan"))
        XCTAssertTrue(yaml.contains("password: \"top-secret\""))
        XCTAssertTrue(yaml.contains("servername: \"trojan.example.com\""))
        XCTAssertTrue(yaml.contains("skip-cert-verify: false"))
        XCTAssertTrue(yaml.contains("udp: true"))
    }
}
