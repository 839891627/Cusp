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

        XCTAssertTrue(yaml.contains("mode: direct"))
        XCTAssertTrue(yaml.contains("- MATCH,DIRECT"))
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

        XCTAssertTrue(yaml.contains("mode: global"))
        XCTAssertTrue(yaml.contains("- MATCH,Cusp"))
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

        XCTAssertTrue(yaml.contains("mode: rule"))
        XCTAssertTrue(yaml.contains("GEOIP,CN,DIRECT"))
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

        XCTAssertTrue(yaml.contains("DOMAIN,api.openai.com,Cusp"))
        XCTAssertTrue(yaml.contains("MATCH,DIRECT"))
    }
}
