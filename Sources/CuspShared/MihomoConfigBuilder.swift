import Foundation

public enum MihomoConfigBuilder {
    public static func build(
        from configuration: ShadowsocksConfiguration,
        allConfigurations: [ShadowsocksConfiguration] = [],
        mode: RuntimeMode = .rules,
        routingRules: [RoutingRule] = RoutingRulePreset.commonMVP,
        proxyGroups: [MihomoProxyGroup] = [],
        activeProxyGroupName: String = "Cusp",
        localControllerSecret: String = CuspConstants.localControllerSecret,
        localHTTPPort: Int = CuspConstants.localHTTPProxyPort,
        localSOCKSPort: Int = CuspConstants.localSOCKSProxyPort
    ) -> String {
        let all = [configuration] + allConfigurations
        let uniqueConfigurations = deduplicatedConfigurations(all)
        let proxyRecords = proxyRecords(for: uniqueConfigurations)
        let proxyBlock = proxyRecords
            .map { proxyYAML(for: $0.configuration, quotedProxyName: $0.quotedName) }
            .joined(separator: "\n")
        let availableProxyNames = Set(proxyRecords.map(\.name))
        let defaultGroupName = "Cusp"
        let requestedProxyGroupName = normalizedGroupName(activeProxyGroupName, fallback: defaultGroupName)
        let renderedGroups = renderedProxyGroups(
            explicitGroups: proxyGroups,
            availableProxyNames: availableProxyNames,
            defaultGroupName: defaultGroupName
        )
        let effectiveProxyGroupName = renderedGroups.names.contains(requestedProxyGroupName) ? requestedProxyGroupName : defaultGroupName

        let modeLine: String
        let rulesBlock: String

        switch mode {
        case .direct:
            modeLine = "mode: direct"
            rulesBlock = """
            rules:
              - MATCH,DIRECT
            """
        case .global:
            modeLine = "mode: global"
            rulesBlock = """
            rules:
              - MATCH,\(effectiveProxyGroupName)
            """
        case .rules:
            modeLine = "mode: rule"
            let effectiveRules = routingRules.isEmpty ? RoutingRulePreset.commonMVP : routingRules
            let rendered = effectiveRules.map { "  - \(clashRuleLine(for: $0, proxyActionTarget: effectiveProxyGroupName))" }
                .joined(separator: "\n")
            rulesBlock = "rules:\n\(rendered)"
        }

        return """
        mixed-port: \(localHTTPPort)
        socks-port: \(localSOCKSPort)
        external-controller: "\(CuspConstants.localProxyHost):\(CuspConstants.localControllerPort)"
        secret: "\(localControllerSecret)"
        find-process-mode: strict
        allow-lan: false
        \(modeLine)
        log-level: info
        ipv6: false
        proxies:
        \(proxyBlock)
        proxy-groups:
        \(renderedGroups.block)
        \(rulesBlock)
        """
    }

    private static func sanitizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func proxyYAML(
        for configuration: ShadowsocksConfiguration,
        quotedProxyName: String
    ) -> String {
        var lines = [
            "  - name: \(quotedProxyName)",
            "    type: \(configuration.protocolType.rawValue)",
            "    server: \(yamlQuoted(configuration.host))",
            "    port: \(configuration.port)"
        ]

        switch configuration.protocolType {
        case .shadowsocks:
            lines.append("    cipher: \(yamlQuoted(configuration.method))")
            lines.append("    password: \(yamlQuoted(configuration.password))")
            if let udp = configuration.udp {
                lines.append("    udp: \(yamlBool(udp))")
            }
        case .vless:
            if let uuid = configuration.uuid {
                lines.append("    uuid: \(yamlQuoted(uuid))")
            }
            if let udp = configuration.udp {
                lines.append("    udp: \(yamlBool(udp))")
            }
            lines.append("    tls: \(yamlBool(configuration.tls))")
            if let skipCertVerify = configuration.skipCertVerify {
                lines.append("    skip-cert-verify: \(yamlBool(skipCertVerify))")
            }
            if let flow = configuration.flow, !flow.isEmpty {
                lines.append("    flow: \(yamlQuoted(flow))")
            }
            if let clientFingerprint = configuration.clientFingerprint, !clientFingerprint.isEmpty {
                lines.append("    client-fingerprint: \(yamlQuoted(clientFingerprint))")
            }
            if let serverName = configuration.serverName, !serverName.isEmpty {
                lines.append("    servername: \(yamlQuoted(serverName))")
            }
        case .vmess:
            let cipher = configuration.method.isEmpty ? "auto" : configuration.method
            if let uuid = configuration.uuid {
                lines.append("    uuid: \(yamlQuoted(uuid))")
            }
            if let alterID = configuration.alterID {
                lines.append("    alterId: \(alterID)")
            }
            lines.append("    cipher: \(yamlQuoted(cipher))")
            if let udp = configuration.udp {
                lines.append("    udp: \(yamlBool(udp))")
            }
            lines.append("    tls: \(yamlBool(configuration.tls))")
            if let skipCertVerify = configuration.skipCertVerify {
                lines.append("    skip-cert-verify: \(yamlBool(skipCertVerify))")
            }
            if let network = configuration.network, !network.isEmpty {
                lines.append("    network: \(yamlQuoted(network))")
            }
            if let serverName = configuration.serverName, !serverName.isEmpty {
                lines.append("    servername: \(yamlQuoted(serverName))")
            }
            if configuration.wsPath != nil || configuration.wsHost != nil {
                lines.append("    ws-opts:")
                if let wsPath = configuration.wsPath, !wsPath.isEmpty {
                    lines.append("      path: \(yamlQuoted(wsPath))")
                }
                if let wsHost = configuration.wsHost, !wsHost.isEmpty {
                    lines.append("      headers:")
                    lines.append("        Host: \(yamlQuoted(wsHost))")
                }
            }
        case .trojan:
            lines.append("    password: \(yamlQuoted(configuration.password))")
            if let udp = configuration.udp {
                lines.append("    udp: \(yamlBool(udp))")
            }
            if let skipCertVerify = configuration.skipCertVerify {
                lines.append("    skip-cert-verify: \(yamlBool(skipCertVerify))")
            }
            if let serverName = configuration.serverName, !serverName.isEmpty {
                lines.append("    servername: \(yamlQuoted(serverName))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func yamlBool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private static func clashAction(for action: RoutingRuleAction, proxyActionTarget: String) -> String {
        switch action {
        case .proxy:
            return proxyActionTarget
        case .direct:
            return "DIRECT"
        case .reject:
            return "REJECT"
        }
    }

    private static func clashRuleLine(for rule: RoutingRule, proxyActionTarget: String) -> String {
        let action = clashAction(for: rule.action, proxyActionTarget: proxyActionTarget)
        if rule.type == .final {
            return "MATCH,\(action)"
        }
        return "\(rule.type.rawValue),\(rule.matcher),\(action)"
    }

    private static func deduplicatedConfigurations(_ all: [ShadowsocksConfiguration]) -> [ShadowsocksConfiguration] {
        var seen: Set<String> = []
        var result: [ShadowsocksConfiguration] = []
        for item in all.sorted(by: { $0.stableID < $1.stableID }) {
            if seen.insert(item.stableID).inserted {
                result.append(item)
            }
        }
        return result
    }

    private struct ProxyRecord {
        let configuration: ShadowsocksConfiguration
        let name: String
        let quotedName: String
    }

    private static func proxyRecords(for configurations: [ShadowsocksConfiguration]) -> [ProxyRecord] {
        var used: [String: Int] = [:]
        return configurations.map { configuration in
            let base = normalizedGroupName(sanitizedName(configuration.remark ?? configuration.host), fallback: configuration.host)
            let count = used[base, default: 0]
            used[base] = count + 1
            let finalName = count == 0 ? base : "\(base)-\(count + 1)"
            return ProxyRecord(
                configuration: configuration,
                name: finalName,
                quotedName: yamlQuoted(finalName)
            )
        }
    }

    private struct RenderedGroups {
        let block: String
        let names: Set<String>
    }

    private static func renderedProxyGroups(
        explicitGroups: [MihomoProxyGroup],
        availableProxyNames: Set<String>,
        defaultGroupName: String
    ) -> RenderedGroups {
        let defaultRendered = renderGroup(
            name: defaultGroupName,
            type: .select,
            proxies: Array(availableProxyNames).sorted(),
            testURL: nil,
            intervalSeconds: nil
        )

        var lines: [String] = [defaultRendered]
        var seenNames: Set<String> = [defaultGroupName]

        for group in explicitGroups {
            let normalizedName = normalizedGroupName(group.name, fallback: "Group")
            guard !seenNames.contains(normalizedName) else {
                continue
            }
            let scopedProxies = group.proxies.filter { availableProxyNames.contains($0) }
            guard !scopedProxies.isEmpty else {
                continue
            }
            lines.append(
                renderGroup(
                    name: normalizedName,
                    type: group.type,
                    proxies: scopedProxies,
                    testURL: group.testURL,
                    intervalSeconds: group.intervalSeconds
                )
            )
            seenNames.insert(normalizedName)
        }

        return RenderedGroups(
            block: lines.joined(separator: "\n"),
            names: seenNames
        )
    }

    private static func renderGroup(
        name: String,
        type: MihomoProxyGroupType,
        proxies: [String],
        testURL: String?,
        intervalSeconds: Int?
    ) -> String {
        var lines: [String] = [
            "  - name: \(yamlQuoted(name))",
            "    type: \(type.rawValue)"
        ]
        if type == .urlTest || type == .fallback || type == .loadBalance {
            lines.append("    url: \(yamlQuoted(testURL ?? "https://www.gstatic.com/generate_204"))")
            lines.append("    interval: \(intervalSeconds ?? 300)")
        }
        lines.append("    proxies:")
        lines.append(contentsOf: proxies.map { "      - \(yamlQuoted($0))" })
        return lines.joined(separator: "\n")
    }

    private static func normalizedGroupName(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        return value
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
