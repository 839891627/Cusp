import Foundation

extension AppViewModel {
    var menuBarIconName: String {
        switch connectionState {
        case .connected:
            return "bolt.horizontal.circle.fill"
        case .connecting, .disconnecting, .disconnected, .invalid:
            return "bolt.horizontal.circle"
        }
    }

    var configurationSummary: String {
        guard let activeConfiguration else {
            return selectedLanguage == .simplifiedChinese
                ? "请粘贴 ss:// 链接以配置 Cusp。"
                : "Paste an ss:// link to configure Cusp."
        }

        let remark = activeConfiguration.remark ?? "Unnamed"
        return "\(remark) · \(activeConfiguration.host):\(activeConfiguration.port)"
    }

    var readinessHint: String {
        if selectedLanguage == .simplifiedChinese {
            return setupGuide.isComplete
                ? "本地检查均已通过。Cusp 现在可以启动 mihomo 并直接切换 macOS 系统代理。"
                : "请按顺序完成下方引导步骤。每完成一步后重新打开 Cusp，以刷新就绪检查。"
        }

        return setupGuide.isComplete
            ? "The local checks are green. Cusp can now launch mihomo and switch your macOS system proxy directly."
            : "Follow the setup guide below in order. After each step, relaunch Cusp so the readiness checks can refresh."
    }

    var nodeCountText: String {
        "\(visibleCatalogNodes.count)"
    }

    var filteredConfigurations: [ShadowsocksConfiguration] {
        filteredCatalogNodes.map(\.configuration)
    }

    var visibleCatalogNodes: [CatalogNode] {
        NodeBoardDisplay.visibleNodes(
            from: catalogNodes,
            sources: subscriptionSources,
            selectedSourceFilterID: selectedSourceFilterID,
            sortMode: nodeSortMode
        )
    }

    var filteredCatalogNodes: [CatalogNode] {
        NodeBoardDisplay.currentViewNodes(
            from: catalogNodes,
            sources: subscriptionSources,
            selectedSourceFilterID: selectedSourceFilterID,
            searchQuery: nodeSearchText,
            sortMode: nodeSortMode
        )
    }

    var selectedSourceName: String? {
        guard
            let activeConfiguration,
            let node = catalogNodes.first(where: { $0.stableID == activeConfiguration.stableID }),
            let source = subscriptionSources.first(where: { $0.id == node.sourceID })
        else {
            return nil
        }

        return source.name
    }

    var totalSavedNodeCountText: String {
        "\(catalogNodes.count)"
    }

    var totalSubscriptionCountText: String {
        "\(subscriptionSources.count)"
    }

    var orderedSubscriptionSources: [SubscriptionSource] {
        let orderMap = Dictionary(uniqueKeysWithValues: sourceGroupOrder.enumerated().map { ($1, $0) })
        return subscriptionSources.sorted { lhs, rhs in
            let left = orderMap[lhs.id] ?? Int.max
            let right = orderMap[rhs.id] ?? Int.max
            if left != right {
                return left < right
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var selectedNodeDisplayName: String {
        guard let activeConfiguration else {
            return selectedLanguage == .simplifiedChinese ? "无" : "None"
        }

        return configurationDisplayName(activeConfiguration)
    }

    func displayName(for interval: SubscriptionRefreshInterval) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch interval {
            case .manual:
                return "手动"
            case .hourly:
                return "每小时"
            case .daily:
                return "每天"
            case .weekly:
                return "每周"
            }
        }

        switch interval {
        case .manual:
            return "Manual"
        case .hourly:
            return "Hourly"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }

    func displayName(for ruleType: RoutingRuleType) -> String {
        switch ruleType {
        case .domainSuffix:
            return "DOMAIN-SUFFIX"
        case .domainKeyword:
            return "DOMAIN-KEYWORD"
        case .domain:
            return "DOMAIN"
        case .ipCIDR:
            return "IP-CIDR"
        case .geoIP:
            return "GEOIP"
        case .geoSite:
            return "GEOSITE"
        case .final:
            return "FINAL"
        }
    }

    func displayName(for action: RoutingRuleAction) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch action {
            case .proxy:
                return "代理"
            case .direct:
                return "直连"
            case .reject:
                return "拒绝"
            }
        }

        switch action {
        case .proxy:
            return "Proxy"
        case .direct:
            return "Direct"
        case .reject:
            return "Reject"
        }
    }

    func displayName(for template: RuleTemplateKind) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch template {
            case .smartCN:
                return "智能分流（推荐）"
            case .aiAndGlobal:
                return "AI 与海外优先代理"
            case .proxyFirst:
                return "全局代理优先"
            }
        }

        switch template {
        case .smartCN:
            return "Smart Split (Recommended)"
        case .aiAndGlobal:
            return "AI + Global Proxy"
        case .proxyFirst:
            return "Proxy First"
        }
    }

    func displayName(for policy: StrategyGroupPolicy) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch policy {
            case .manual:
                return "手动"
            case .fastest:
                return "最低延迟"
            case .fallback:
                return "故障转移"
            }
        }

        switch policy {
        case .manual:
            return "Manual"
        case .fastest:
            return "Fastest"
        case .fallback:
            return "Fallback"
        }
    }

    func displayName(for strategyType: CustomStrategyGroupType) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch strategyType {
            case .manual:
                return "手动选择策略组"
            case .smart:
                return "智能稳定策略组"
            case .urlTest:
                return "URL 测速策略组"
            case .fallback:
                return "Fallback 策略组"
            case .loadBalance:
                return "随机分流策略组"
            }
        }

        switch strategyType {
        case .manual:
            return "Manual Group"
        case .smart:
            return "Smart Stable Group"
        case .urlTest:
            return "URL Test Group"
        case .fallback:
            return "Fallback Group"
        case .loadBalance:
            return "Random Balance Group"
        }
    }

    func displayName(for nodeSortMode: NodeSortMode) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch nodeSortMode {
            case .manual:
                return "手动"
            case .latency:
                return "按延迟"
            case .name:
                return "按名称"
            }
        }

        switch nodeSortMode {
        case .manual:
            return "Manual"
        case .latency:
            return "Latency"
        case .name:
            return "Name"
        }
    }

    func strategyTypeDescription(_ type: CustomStrategyGroupType) -> String {
        if selectedLanguage == .simplifiedChinese {
            switch type {
            case .manual:
                return "由你手动指定使用哪个节点。"
            case .smart:
                return "优先保持当前健康节点，必要时再切到低延迟节点。"
            case .urlTest:
                return "根据 URL 测试结果，始终优先最低延迟节点。"
            case .fallback:
                return "当前节点失败时自动切到可用备用节点。"
            case .loadBalance:
                return "在健康节点中随机选一个节点（非流量级负载均衡）。"
            }
        }

        switch type {
        case .manual:
            return "Pick the node manually."
        case .smart:
            return "Keep current healthy node first, then switch to low-latency backup."
        case .urlTest:
            return "Always prefer the lowest-latency URL-test result."
        case .fallback:
            return "Switch to backup nodes when current fails."
        case .loadBalance:
            return "Randomly choose one healthy node (not per-flow balancing)."
        }
    }

    var trafficTrendText: String {
        guard !trafficSamples.isEmpty else {
            return "--"
        }
        let peaks = trafficSamples.map { max($0.uploadBytesPerSecond, $0.downloadBytesPerSecond) }
        guard let maxValue = peaks.max(), maxValue > 0 else {
            return ".........."
        }
        let levels = [".", ":", "-", "=", "+", "*", "#"]
        return peaks.map { value in
            let ratio = value / maxValue
            let idx = min(levels.count - 1, Int(ratio * Double(levels.count - 1)))
            return levels[idx]
        }.joined()
    }

    var isEditingSubscription: Bool {
        editingSubscriptionID != nil
    }

    var isConnectButtonEnabled: Bool {
        if connectionState == .connected || connectionState == .connecting || connectionState == .disconnecting {
            return true
        }
        return readinessReport.isReady
    }
}

