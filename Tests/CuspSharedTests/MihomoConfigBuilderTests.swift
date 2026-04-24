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

        assertYAMLContains(yaml, "mixed-port: 1086")
        assertYAMLContains(yaml, "socks-port: 1087")
        assertYAMLContains(yaml, "external-controller: \"127.0.0.1:1090\"")
        assertYAMLContains(yaml, "secret: \"cusp-local-controller\"")
        assertYAMLContains(yaml, "find-process-mode: strict")
        assertYAMLContains(yaml, "type: ss")
        assertYAMLContains(yaml, "server: \"1.2.3.4\"")
        assertYAMLContains(yaml, "cipher: \"aes-256-gcm\"")
        assertYAMLContains(yaml, "name: \"Office\"")
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

    func testGlobalModeUsesRequestedCustomProxyGroupWhenGroupIsRenderable() {
        let config = ShadowsocksConfiguration(
            host: "1.2.3.4",
            port: 8388,
            method: "aes-256-gcm",
            password: "secret",
            remark: "Office"
        )
        let groups = [
            MihomoProxyGroup(
                name: "Fallback, Group",
                type: .fallback,
                proxies: ["Office"],
                testURL: "https://www.gstatic.com/generate_204",
                intervalSeconds: 120
            )
        ]

        let yaml = MihomoConfigBuilder.build(
            from: config,
            mode: .global,
            proxyGroups: groups,
            activeProxyGroupName: "Fallback, Group"
        )

        assertGroupRendered(yaml, name: "Fallback_ Group")
        assertYAMLContains(yaml, "type: fallback")
        assertYAMLContains(yaml, "interval: 120")
        assertRuleRendered(yaml, "MATCH,Fallback_ Group")
    }

    func testGlobalModeFallsBackToDefaultGroupWhenRequestedGroupIsUnavailable() {
        let config = ShadowsocksConfiguration(
            host: "1.2.3.4",
            port: 8388,
            method: "aes-256-gcm",
            password: "secret",
            remark: "Office"
        )
        let groups = [
            MihomoProxyGroup(
                name: "Smart Group",
                type: .urlTest,
                proxies: ["Non-Existing-Proxy"]
            )
        ]

        let yaml = MihomoConfigBuilder.build(
            from: config,
            mode: .global,
            proxyGroups: groups,
            activeProxyGroupName: "Smart Group"
        )

        assertRuleRendered(yaml, "MATCH,Cusp")
        assertYAMLNotContains(yaml, "name: \"Smart Group\"")
    }

    func testRulesModeAppliesProxyActionToRequestedActiveGroup() {
        let config = ShadowsocksConfiguration(
            host: "1.2.3.4",
            port: 8388,
            method: "aes-256-gcm",
            password: "secret",
            remark: "Office"
        )
        let rules = [
            RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
            RoutingRule(type: .domainSuffix, matcher: "example.com", action: .direct),
            RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
        ]
        let groups = [
            MihomoProxyGroup(name: "Smart Group", type: .select, proxies: ["Office"])
        ]

        let yaml = MihomoConfigBuilder.build(
            from: config,
            mode: .rules,
            routingRules: rules,
            proxyGroups: groups,
            activeProxyGroupName: "Smart Group"
        )

        assertRuleRendered(yaml, "DOMAIN,api.openai.com,Smart Group")
        assertRuleRendered(yaml, "DOMAIN-SUFFIX,example.com,DIRECT")
        assertRuleRendered(yaml, "MATCH,Smart Group")
    }

    func testBuildsEndToEndConfigWithDeduplicatedNodesAndRenderedProxyGroups() {
        let primary = ShadowsocksConfiguration(
            host: "1.1.1.1",
            port: 443,
            method: "aes-256-gcm",
            password: "a",
            remark: "JP-01"
        )
        let duplicateStableID = primary
        let secondary = ShadowsocksConfiguration(
            host: "2.2.2.2",
            port: 443,
            method: "aes-128-gcm",
            password: "b",
            remark: "US-02"
        )
        let groups = [
            MihomoProxyGroup(
                name: "Smart Group",
                type: .urlTest,
                proxies: ["JP-01", "US-02"],
                testURL: "https://cp.cloudflare.com/generate_204",
                intervalSeconds: 45
            ),
            // Should be ignored because proxies are unavailable.
            MihomoProxyGroup(
                name: "Unused Group",
                type: .fallback,
                proxies: ["NotExists"]
            )
        ]
        let rules = [
            RoutingRule(type: .domain, matcher: "example.com", action: .proxy),
            RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
        ]

        let yaml = MihomoConfigBuilder.build(
            from: primary,
            allConfigurations: [secondary, duplicateStableID],
            mode: .rules,
            routingRules: rules,
            proxyGroups: groups,
            activeProxyGroupName: "Smart Group"
        )

        // Node de-duplication by stableID should keep JP-01 only once.
        assertYAMLOccurrence(yaml, "name: \"JP-01\"", equals: 1)
        assertYAMLOccurrence(yaml, "name: \"US-02\"", equals: 1)

        // Rendered group should survive and be used by PROXY actions.
        assertGroupRendered(yaml, name: "Smart Group")
        assertYAMLContains(yaml, "type: url-test")
        assertYAMLContains(yaml, "url: \"https://cp.cloudflare.com/generate_204\"")
        assertYAMLContains(yaml, "interval: 45")
        assertRuleRendered(yaml, "DOMAIN,example.com,Smart Group")
        assertRuleRendered(yaml, "MATCH,Smart Group")

        // Unavailable group should not be rendered.
        assertYAMLNotContains(yaml, "name: \"Unused Group\"")
    }

    func testRulesModeFallsBackProxyActionToDefaultGroupWhenActiveGroupNotRenderable() {
        let primary = ShadowsocksConfiguration(
            host: "10.0.0.1",
            port: 443,
            method: "aes-256-gcm",
            password: "secret",
            remark: "HK-01"
        )
        let rules = [
            RoutingRule(type: .domainKeyword, matcher: "openai", action: .proxy),
            RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
        ]
        let groups = [
            MihomoProxyGroup(name: "Smart Group", type: .select, proxies: ["UnknownProxy"])
        ]

        let yaml = MihomoConfigBuilder.build(
            from: primary,
            mode: .rules,
            routingRules: rules,
            proxyGroups: groups,
            activeProxyGroupName: "Smart Group"
        )

        assertRuleRendered(yaml, "DOMAIN-KEYWORD,openai,Cusp")
        assertRuleRendered(yaml, "MATCH,Cusp")
        assertYAMLNotContains(yaml, "name: \"Smart Group\"")
    }
}

private extension XCTestCase {
    func assertYAMLContains(_ yaml: String, _ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(yaml.contains(fragment), "Expected YAML to contain: \(fragment)", file: file, line: line)
    }

    func assertYAMLNotContains(_ yaml: String, _ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(yaml.contains(fragment), "Expected YAML not to contain: \(fragment)", file: file, line: line)
    }

    func assertRuleRendered(_ yaml: String, _ rule: String, file: StaticString = #filePath, line: UInt = #line) {
        assertYAMLContains(yaml, "- \(rule)", file: file, line: line)
    }

    func assertGroupRendered(_ yaml: String, name: String, file: StaticString = #filePath, line: UInt = #line) {
        assertYAMLContains(yaml, "name: \"\(name)\"", file: file, line: line)
    }

    func assertYAMLOccurrence(_ yaml: String, _ fragment: String, equals expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let count = yaml.components(separatedBy: fragment).count - 1
        XCTAssertEqual(count, expected, "Expected occurrence count for \(fragment) to be \(expected), got \(count)", file: file, line: line)
    }
}
