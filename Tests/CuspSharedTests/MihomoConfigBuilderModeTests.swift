import XCTest
@testable import CuspShared

final class MihomoConfigBuilderModeTests: XCTestCase {
    func testBuildsDirectModeConfig() {
        let configuration = ShadowsocksConfiguration(
            host: "1.1.1.1",
            port: 443,
            method: "aes-256-gcm",
            password: "a",
            remark: "US 01"
        )

        let yaml = MihomoConfigBuilder.build(from: configuration, mode: .direct)

        assertYAMLContains(yaml, "mode: direct")
        assertRuleRendered(yaml, "MATCH,DIRECT")
    }

    func testBuildsGlobalModeConfig() {
        let configuration = ShadowsocksConfiguration(
            host: "1.1.1.1",
            port: 443,
            method: "aes-256-gcm",
            password: "a",
            remark: "US 01"
        )

        let yaml = MihomoConfigBuilder.build(from: configuration, mode: .global)

        assertYAMLContains(yaml, "mode: global")
        assertRuleRendered(yaml, "MATCH,Cusp")
    }

    func testBuildsRulesModeConfig() {
        let configuration = ShadowsocksConfiguration(
            host: "1.1.1.1",
            port: 443,
            method: "aes-256-gcm",
            password: "a",
            remark: "US 01"
        )

        let yaml = MihomoConfigBuilder.build(from: configuration, mode: .rules)

        assertYAMLContains(yaml, "mode: rule")
        assertRuleRendered(yaml, "GEOIP,CN,DIRECT")
    }

    func testBuildsRulesModeConfigWithCustomRules() {
        let configuration = ShadowsocksConfiguration(
            host: "1.1.1.1",
            port: 443,
            method: "aes-256-gcm",
            password: "a",
            remark: "US 01"
        )
        let customRules = [
            RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
            RoutingRule(type: .final, matcher: "MATCH", action: .direct)
        ]

        let yaml = MihomoConfigBuilder.build(from: configuration, mode: .rules, routingRules: customRules)

        assertRuleRendered(yaml, "DOMAIN,api.openai.com,Cusp")
        assertRuleRendered(yaml, "MATCH,DIRECT")
    }
}

private extension XCTestCase {
    func assertYAMLContains(_ yaml: String, _ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(yaml.contains(fragment), "Expected YAML to contain: \(fragment)", file: file, line: line)
    }

    func assertRuleRendered(_ yaml: String, _ rule: String, file: StaticString = #filePath, line: UInt = #line) {
        assertYAMLContains(yaml, "- \(rule)", file: file, line: line)
    }
}
