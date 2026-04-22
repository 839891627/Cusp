import Foundation

enum RuleTemplateCatalog {
    static func rules(for template: RuleTemplateKind) -> [RoutingRule] {
        switch template {
        case .smartCN:
            return [
                RoutingRule(type: .ipCIDR, matcher: "127.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "10.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "172.16.0.0/12", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "192.168.0.0/16", action: .direct),
                RoutingRule(type: .geoIP, matcher: "CN", action: .direct),
                RoutingRule(type: .domainSuffix, matcher: "doubleclick.net", action: .reject),
                RoutingRule(type: .domainKeyword, matcher: "adservice", action: .reject),
                RoutingRule(type: .domainSuffix, matcher: "openai.com", action: .proxy),
                RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
                RoutingRule(type: .domainSuffix, matcher: "anthropic.com", action: .proxy),
                RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
            ]
        case .aiAndGlobal:
            return [
                RoutingRule(type: .ipCIDR, matcher: "127.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "10.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "172.16.0.0/12", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "192.168.0.0/16", action: .direct),
                RoutingRule(type: .domainSuffix, matcher: "openai.com", action: .proxy),
                RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
                RoutingRule(type: .domainSuffix, matcher: "anthropic.com", action: .proxy),
                RoutingRule(type: .domainSuffix, matcher: "google.com", action: .proxy),
                RoutingRule(type: .domainSuffix, matcher: "github.com", action: .proxy),
                RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
            ]
        case .proxyFirst:
            return [
                RoutingRule(type: .ipCIDR, matcher: "127.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "10.0.0.0/8", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "172.16.0.0/12", action: .direct),
                RoutingRule(type: .ipCIDR, matcher: "192.168.0.0/16", action: .direct),
                RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
            ]
        }
    }
}

