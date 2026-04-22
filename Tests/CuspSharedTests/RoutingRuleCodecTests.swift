import XCTest
@testable import CuspShared

final class RoutingRuleCodecTests: XCTestCase {
    func testParsesConfAndYAMLStyledRules() {
        let text = """
        rules:
          - DOMAIN-SUFFIX,google.com,PROXY
          - GEOIP,CN,DIRECT
        """

        let rules = RoutingRuleCodec.parse(from: text)

        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].type, .domainSuffix)
        XCTAssertEqual(rules[0].matcher, "google.com")
        XCTAssertEqual(rules[0].action, .proxy)
        XCTAssertEqual(rules[1].type, .geoIP)
        XCTAssertEqual(rules[1].action, .direct)
    }

    func testExportsConf() {
        let rules = [
            RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
            RoutingRule(type: .final, matcher: "MATCH", action: .direct)
        ]

        let conf = RoutingRuleCodec.exportConf(rules)

        XCTAssertTrue(conf.contains("DOMAIN,api.openai.com,PROXY"))
        XCTAssertTrue(conf.contains("MATCH,DIRECT"))
    }
}
