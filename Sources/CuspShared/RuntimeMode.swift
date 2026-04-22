import Foundation

public enum RuntimeMode: String, Codable, CaseIterable, Equatable, Sendable {
    case direct
    case global
    case rules
}

public enum RoutingRuleType: String, Codable, CaseIterable, Equatable, Sendable {
    case domainSuffix = "DOMAIN-SUFFIX"
    case domainKeyword = "DOMAIN-KEYWORD"
    case domain = "DOMAIN"
    case ipCIDR = "IP-CIDR"
    case geoIP = "GEOIP"
    case geoSite = "GEOSITE"
    case final = "FINAL"
}

public enum RoutingRuleAction: String, Codable, CaseIterable, Equatable, Sendable {
    case proxy = "PROXY"
    case direct = "DIRECT"
    case reject = "REJECT"
}

public enum MihomoProxyGroupType: String, Codable, CaseIterable, Equatable, Sendable {
    case select
    case urlTest = "url-test"
    case fallback
    case loadBalance = "load-balance"
}

public struct MihomoProxyGroup: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let type: MihomoProxyGroupType
    public let proxies: [String]
    public let testURL: String?
    public let intervalSeconds: Int?

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: MihomoProxyGroupType,
        proxies: [String],
        testURL: String? = nil,
        intervalSeconds: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.proxies = proxies
        self.testURL = testURL
        self.intervalSeconds = intervalSeconds
    }
}

public struct RoutingRule: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let type: RoutingRuleType
    public let matcher: String
    public let action: RoutingRuleAction

    public init(
        id: String = UUID().uuidString,
        type: RoutingRuleType,
        matcher: String,
        action: RoutingRuleAction
    ) {
        self.id = id
        self.type = type
        self.matcher = matcher
        self.action = action
    }
}

public enum RoutingRulePreset {
    public static let commonMVP: [RoutingRule] = [
        RoutingRule(type: .ipCIDR, matcher: "127.0.0.0/8", action: .direct),
        RoutingRule(type: .ipCIDR, matcher: "10.0.0.0/8", action: .direct),
        RoutingRule(type: .ipCIDR, matcher: "172.16.0.0/12", action: .direct),
        RoutingRule(type: .ipCIDR, matcher: "192.168.0.0/16", action: .direct),
        RoutingRule(type: .geoIP, matcher: "CN", action: .direct),
        RoutingRule(type: .domainSuffix, matcher: "doubleclick.net", action: .reject),
        RoutingRule(type: .domainKeyword, matcher: "adservice", action: .reject),
        RoutingRule(type: .domain, matcher: "api.openai.com", action: .proxy),
        RoutingRule(type: .final, matcher: "MATCH", action: .proxy)
    ]
}

public enum RoutingRuleCodec {
    public static func parse(from text: String) -> [RoutingRule] {
        var rules: [RoutingRule] = []
        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }
            if line.hasPrefix("#") {
                continue
            }
            if line.hasPrefix("- ") {
                line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if line.lowercased().hasPrefix("rules:") {
                continue
            }

            let parts = line.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count >= 2 else {
                continue
            }

            let typeRaw = parts[0].uppercased()
            let matcher: String
            let actionRaw: String
            if typeRaw == "MATCH" {
                matcher = "MATCH"
                actionRaw = parts[1].uppercased()
            } else {
                guard parts.count >= 3 else {
                    continue
                }
                matcher = parts[1]
                actionRaw = parts[2].uppercased()
            }
            let normalizedAction: String
            if actionRaw == "FLOWGATE" || actionRaw == "PROXY" {
                normalizedAction = RoutingRuleAction.proxy.rawValue
            } else {
                normalizedAction = actionRaw
            }

            let normalizedTypeRaw = typeRaw == "MATCH" ? RoutingRuleType.final.rawValue : typeRaw
            guard
                let type = RoutingRuleType(rawValue: normalizedTypeRaw),
                let action = RoutingRuleAction(rawValue: normalizedAction)
            else {
                continue
            }
            rules.append(RoutingRule(type: type, matcher: matcher, action: action))
        }
        return rules
    }

    public static func exportConf(_ rules: [RoutingRule]) -> String {
        rules.map(ruleLine).joined(separator: "\n")
    }

    public static func exportYAML(_ rules: [RoutingRule]) -> String {
        let rows = rules.map { "  - \(ruleLine($0))" }.joined(separator: "\n")
        return """
        rules:
        \(rows)
        """
    }

    private static func ruleLine(_ rule: RoutingRule) -> String {
        if rule.type == .final {
            return "MATCH,\(rule.action.rawValue)"
        }
        return "\(rule.type.rawValue),\(rule.matcher),\(rule.action.rawValue)"
    }
}
