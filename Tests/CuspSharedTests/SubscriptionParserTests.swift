import XCTest
@testable import CuspShared

final class SubscriptionParserTests: XCTestCase {
    func testParsesSingleSSLinkFromPlainText() throws {
        let text = "ss://YWVzLTI1Ni1nY206c2VjcmV0QDE5Mi4xNjguMS4xOjgzODg=#Office"

        let configurations = try SubscriptionParser.parseConfigurations(from: text)

        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.host, "192.168.1.1")
    }

    func testParsesBase64EncodedSubscriptionBody() throws {
        let body = """
        ss://YWVzLTI1Ni1nY206c2VjcmV0QDE5Mi4xNjguMS4xOjgzODg=#Office
        ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTpwYXNzQDEwLjAuMC4xOjQ0Mw==#Lab
        """
        let encoded = Data(body.utf8).base64EncodedString()

        let configurations = try SubscriptionParser.parseConfigurations(from: encoded)

        XCTAssertEqual(configurations.count, 2)
        XCTAssertEqual(configurations.first?.remark, "Office")
        XCTAssertEqual(configurations.last?.host, "10.0.0.1")
    }

    func testRejectsTextWithoutNodes() {
        XCTAssertThrowsError(try SubscriptionParser.parseConfigurations(from: "hello world")) { error in
            XCTAssertEqual(error as? SubscriptionParser.Error, .noNodesFound)
        }
    }

    func testParsesVLESSNodesFromClashYAML() throws {
        let text = """
        mixed-port: 7890
        proxies:
          - { name: 'L1|香港01', type: vless, server: hk.example.com, port: 443, uuid: 212f3ab5-4456-4bd9-ba69-88610646d415, udp: true, tls: true, skip-cert-verify: false, flow: xtls-rprx-vision, client-fingerprint: safari, servername: edge.example.com }
        """

        let configurations = try SubscriptionParser.parseConfigurations(from: text)

        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.protocolType, .vless)
        XCTAssertEqual(configurations.first?.host, "hk.example.com")
        XCTAssertEqual(configurations.first?.port, 443)
        XCTAssertEqual(configurations.first?.uuid, "212f3ab5-4456-4bd9-ba69-88610646d415")
        XCTAssertEqual(configurations.first?.serverName, "edge.example.com")
        XCTAssertEqual(configurations.first?.flow, "xtls-rprx-vision")
        XCTAssertEqual(configurations.first?.remark, "L1|香港01")
    }

    func testParsesVMessNodesFromClashYAML() throws {
        let text = """
        mixed-port: 7890
        proxies:
          - { name: 'VMESS|JP01', type: vmess, server: jp.example.com, port: 443, uuid: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee, alterId: 0, cipher: auto, udp: true, tls: true, skip-cert-verify: true, network: ws, servername: cdn.example.com, ws-opts: { path: /ws, headers: { Host: ws.example.com } } }
        """

        let configurations = try SubscriptionParser.parseConfigurations(from: text)

        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.protocolType, .vmess)
        XCTAssertEqual(configurations.first?.host, "jp.example.com")
        XCTAssertEqual(configurations.first?.port, 443)
        XCTAssertEqual(configurations.first?.uuid, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertEqual(configurations.first?.method, "auto")
        XCTAssertEqual(configurations.first?.alterID, 0)
        XCTAssertEqual(configurations.first?.network, "ws")
        XCTAssertEqual(configurations.first?.serverName, "cdn.example.com")
        XCTAssertEqual(configurations.first?.wsPath, "/ws")
        XCTAssertEqual(configurations.first?.wsHost, "ws.example.com")
        XCTAssertEqual(configurations.first?.remark, "VMESS|JP01")
    }

    func testParsesTrojanNodesFromClashYAML() throws {
        let text = """
        mixed-port: 7890
        proxies:
          - { name: 'TROJAN|US01', type: trojan, server: us.example.com, port: 443, password: top-secret, udp: true, sni: trojan.example.com, skip-cert-verify: false }
        """

        let configurations = try SubscriptionParser.parseConfigurations(from: text)

        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.protocolType, .trojan)
        XCTAssertEqual(configurations.first?.host, "us.example.com")
        XCTAssertEqual(configurations.first?.port, 443)
        XCTAssertEqual(configurations.first?.password, "top-secret")
        XCTAssertEqual(configurations.first?.serverName, "trojan.example.com")
        XCTAssertEqual(configurations.first?.skipCertVerify, false)
        XCTAssertEqual(configurations.first?.remark, "TROJAN|US01")
    }
}
