import Foundation

extension AppViewModel {
    func ensureDefaultStrategyGroupsIfNeeded() {
        guard customStrategyGroups.isEmpty else {
            return
        }
        guard !UserDefaults.standard.bool(forKey: Self.didSeedDefaultStrategyGroupsKey) else {
            return
        }

        let enabledSources = subscriptionSources.filter(\.isEnabled)
        let preferredSource = enabledSources.first(where: { $0.id == selectedSourceFilterID }) ?? enabledSources.first
        guard let source = preferredSource else {
            return
        }

        let sourceNodes = catalogNodes.filter { $0.sourceID == source.id }
        guard !sourceNodes.isEmpty else {
            return
        }

        let manualName = selectedLanguage == .simplifiedChinese ? "手动策略组" : "Manual Group"
        let fastestName = selectedLanguage == .simplifiedChinese ? "智能策略组" : "Smart Group"
        let fallbackName = selectedLanguage == .simplifiedChinese ? "故障转移策略组" : "Fallback Group"

        customStrategyGroups = [
            CustomStrategyGroup(
                id: UUID().uuidString,
                name: manualName,
                type: .manual,
                sourceID: source.id,
                preferredNodeID: sourceNodes.first?.stableID,
                testURL: nil,
                intervalSeconds: nil
            ),
            CustomStrategyGroup(
                id: UUID().uuidString,
                name: fastestName,
                type: .urlTest,
                sourceID: source.id,
                preferredNodeID: nil,
                testURL: "https://www.gstatic.com/generate_204",
                intervalSeconds: 300
            ),
            CustomStrategyGroup(
                id: UUID().uuidString,
                name: fallbackName,
                type: .fallback,
                sourceID: source.id,
                preferredNodeID: nil,
                testURL: "https://www.gstatic.com/generate_204",
                intervalSeconds: 300
            )
        ]

        UserDefaults.standard.set(true, forKey: Self.didSeedDefaultStrategyGroupsKey)
    }

    func createCustomStrategyGroup(
        name: String,
        type: CustomStrategyGroupType,
        sourceID: String,
        testURL: String? = nil,
        intervalSeconds: Int? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? displayName(for: type) : trimmedName
        customStrategyGroups.append(
            CustomStrategyGroup(
                id: UUID().uuidString,
                name: finalName,
                type: type,
                sourceID: sourceID,
                preferredNodeID: nil,
                testURL: testURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                intervalSeconds: intervalSeconds
            )
        )
    }

    func updateCustomStrategyGroup(
        id: String,
        name: String,
        type: CustomStrategyGroupType,
        sourceID: String,
        testURL: String? = nil,
        intervalSeconds: Int? = nil
    ) {
        guard let index = customStrategyGroups.firstIndex(where: { $0.id == id }) else {
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? displayName(for: type) : trimmedName
        let existing = customStrategyGroups[index]
        let preferredNodeID = existing.sourceID == sourceID ? existing.preferredNodeID : nil
        customStrategyGroups[index] = CustomStrategyGroup(
            id: existing.id,
            name: finalName,
            type: type,
            sourceID: sourceID,
            preferredNodeID: preferredNodeID,
            testURL: testURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            intervalSeconds: intervalSeconds
        )
    }

    func duplicateCustomStrategyGroup(id: String) {
        guard let group = customStrategyGroups.first(where: { $0.id == id }) else {
            return
        }
        let duplicateName = selectedLanguage == .simplifiedChinese
            ? "\(group.name) 副本"
            : "\(group.name) Copy"
        customStrategyGroups.append(
            CustomStrategyGroup(
                id: UUID().uuidString,
                name: duplicateName,
                type: group.type,
                sourceID: group.sourceID,
                preferredNodeID: group.preferredNodeID,
                testURL: group.testURL,
                intervalSeconds: group.intervalSeconds
            )
        )
    }

    func setPreferredNodeForCustomStrategyGroup(id: String, nodeID: String?) {
        guard let index = customStrategyGroups.firstIndex(where: { $0.id == id }) else {
            return
        }
        let current = customStrategyGroups[index]
        customStrategyGroups[index] = CustomStrategyGroup(
            id: current.id,
            name: current.name,
            type: current.type,
            sourceID: current.sourceID,
            preferredNodeID: nodeID,
            testURL: current.testURL,
            intervalSeconds: current.intervalSeconds
        )
    }

    func displaySelectedNodeName(forCustomStrategyGroupID id: String) -> String {
        guard let group = customStrategyGroups.first(where: { $0.id == id }),
              let node = resolvedNode(for: group) else {
            return selectedLanguage == .simplifiedChinese ? "未选择节点" : "No Node"
        }
        return node.configuration.remark ?? node.configuration.host
    }

    func strategyGroupResolvedNodeSummary(for id: String) -> String {
        guard let group = customStrategyGroups.first(where: { $0.id == id }),
              let node = resolvedNode(for: group) else {
            return selectedLanguage == .simplifiedChinese ? "未选择节点" : "No Node"
        }

        let name = node.configuration.remark ?? node.configuration.host
        switch node.probeStatus {
        case .success:
            if let latency = node.latestLatencyMs {
                return "\(name) · \(latency) ms"
            }
            return name
        case .timeout:
            return selectedLanguage == .simplifiedChinese ? "\(name) · 超时" : "\(name) · timeout"
        case .failure:
            return selectedLanguage == .simplifiedChinese ? "\(name) · 失败" : "\(name) · failed"
        case .idle:
            return selectedLanguage == .simplifiedChinese ? "\(name) · 待测" : "\(name) · pending"
        }
    }

    func strategyGroupDecisionSummary(for id: String) -> String {
        guard let group = customStrategyGroups.first(where: { $0.id == id }) else {
            return selectedLanguage == .simplifiedChinese ? "无可用策略信息" : "No strategy detail"
        }
        let nodes = catalogNodes.filter { $0.sourceID == group.sourceID }
        switch group.type {
        case .manual:
            if group.preferredNodeID != nil {
                return selectedLanguage == .simplifiedChinese ? "手动固定节点" : "Manually pinned node"
            }
            return selectedLanguage == .simplifiedChinese ? "手动模式（未固定）" : "Manual mode (not pinned)"
        case .smart:
            if normalizedMihomoGroupName(group.name) == activeRuntimeProxyGroupName,
               let active = activeConfiguration,
               let activeNode = nodes.first(where: { $0.stableID == active.stableID }),
               activeNode.probeStatus == .success {
                return selectedLanguage == .simplifiedChinese ? "保持当前健康节点" : "Keeping current healthy node"
            }
            if nodes.contains(where: { $0.probeStatus == .success && $0.latestLatencyMs != nil }) {
                return selectedLanguage == .simplifiedChinese ? "智能优选低延迟可用节点" : "Smart-picked healthy low-latency node"
            }
            return selectedLanguage == .simplifiedChinese ? "缺少测速结果，回退可用节点" : "Missing probe data, falling back to available node"
        case .urlTest:
            if nodes.contains(where: { $0.probeStatus == .success && $0.latestLatencyMs != nil }) {
                return selectedLanguage == .simplifiedChinese ? "URL 测试最低延迟优先" : "URL test chose lowest latency"
            }
            return selectedLanguage == .simplifiedChinese ? "尚无测试结果，回退首个节点" : "No test result, fell back to first node"
        case .fallback:
            if normalizedMihomoGroupName(group.name) == activeRuntimeProxyGroupName,
               let active = activeConfiguration,
               let activeNode = nodes.first(where: { $0.stableID == active.stableID }),
               activeNode.probeStatus == .success {
                return selectedLanguage == .simplifiedChinese ? "主节点健康，继续保持" : "Primary is healthy, keeping current"
            }
            return selectedLanguage == .simplifiedChinese ? "主节点异常，自动切备用" : "Primary failed, switched to backup"
        case .loadBalance:
            if nodes.contains(where: { $0.probeStatus == .success }) {
                return selectedLanguage == .simplifiedChinese ? "在健康节点中随机分配" : "Random choice among healthy nodes"
            }
            return selectedLanguage == .simplifiedChinese ? "无健康节点，随机选择可用节点" : "No healthy nodes, random fallback"
        }
    }

    func strategyGroupLatestSwitchSummary(for id: String) -> String {
        guard let record = strategyGroupSwitchRecords[id] else {
            return selectedLanguage == .simplifiedChinese ? "尚未切换" : "No switch yet"
        }
        guard let group = customStrategyGroups.first(where: { $0.id == id }) else {
            return selectedLanguage == .simplifiedChinese ? "尚未切换" : "No switch yet"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = selectedLanguage == .simplifiedChinese
            ? Locale(identifier: "zh-Hans-CN")
            : Locale(identifier: "en_US_POSIX")
        let timeText = formatter.localizedString(for: record.switchedAt, relativeTo: Date())
        let sourceText: String
        switch record.source {
        case .manualApply:
            sourceText = selectedLanguage == .simplifiedChinese ? "手动应用" : "manual apply"
        case .autoFailover:
            sourceText = selectedLanguage == .simplifiedChinese ? "自动故障转移" : "auto failover"
        }
        let nodeName: String
        if let node = resolvedNode(for: group) {
            nodeName = node.configuration.remark ?? node.configuration.host
        } else {
            nodeName = selectedLanguage == .simplifiedChinese ? "未选择节点" : "No Node"
        }
        return "\(timeText) · \(sourceText) · \(nodeName)"
    }

    func isManualCustomStrategyGroup(id: String) -> Bool {
        customStrategyGroups.first(where: { $0.id == id })?.type == .manual
    }

    func markStrategyGroupSwitched(id: String, source: StrategyGroupSwitchSource, at: Date = Date()) {
        strategyGroupSwitchRecords[id] = StrategyGroupSwitchRecord(switchedAt: at, source: source)
    }

    func activeCustomStrategyGroup() -> CustomStrategyGroup? {
        customStrategyGroups.first {
            normalizedMihomoGroupName($0.name) == activeRuntimeProxyGroupName
        }
    }

    func strategyGroupCardTitle(_ group: CustomStrategyGroup) -> String {
        guard let source = subscriptionSources.first(where: { $0.id == group.sourceID }) else {
            return group.name
        }
        let sourceName = strategyGroupTitle(for: source).trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "\(sourceName) "
        guard !sourceName.isEmpty, group.name.hasPrefix(prefix) else {
            return group.name
        }
        let stripped = String(group.name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? group.name : stripped
    }

    func removeCustomStrategyGroup(id: String) {
        guard let removed = customStrategyGroups.first(where: { $0.id == id }) else {
            return
        }
        customStrategyGroups.removeAll { $0.id == id }
        strategyGroupSwitchRecords.removeValue(forKey: id)
        if activeRuntimeProxyGroupName == normalizedMihomoGroupName(removed.name) {
            activeRuntimeProxyGroupName = Self.defaultRuntimeProxyGroupName
        }
    }

    func applyCustomStrategyGroup(id: String) {
        guard let group = customStrategyGroups.first(where: { $0.id == id }) else {
            return
        }
        let nodes = catalogNodes.filter { $0.sourceID == group.sourceID }
        guard !nodes.isEmpty else {
            return
        }

        let picked: CatalogNode?
        switch group.type {
        case .manual:
            if let preferredNodeID = group.preferredNodeID {
                picked = nodes.first(where: { $0.stableID == preferredNodeID }) ?? nodes.first
            } else {
                picked = nodes.first
            }
        case .smart:
            picked = preferredNodeForSmart(in: nodes)
        case .urlTest:
            picked = preferredNodeForURLTest(in: nodes)
        case .fallback:
            picked = preferredNode(in: nodes, policy: .fallback)
        case .loadBalance:
            let healthy = nodes.filter { $0.probeStatus == .success }
            picked = (healthy.isEmpty ? nodes : healthy).randomElement()
        }

        guard let picked else {
            return
        }
        selectSourceFilter(id: group.sourceID)
        activeRuntimeProxyGroupName = normalizedMihomoGroupName(group.name)
        selectConfiguration(id: picked.stableID)
        markStrategyGroupSwitched(id: group.id, source: .manualApply)
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已应用策略组「\(group.name)」。"
            : "Applied strategy group \"\(group.name)\"."
    }

    func strategyGroupTitle(for source: SubscriptionSource) -> String {
        let alias = sourceGroupAliases[source.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return alias.isEmpty ? source.name : alias
    }

    func strategyGroupPolicy(for sourceID: String) -> StrategyGroupPolicy {
        guard let raw = strategyGroupPolicies[sourceID], let policy = StrategyGroupPolicy(rawValue: raw) else {
            return .manual
        }
        return policy
    }

    func setStrategyGroupPolicy(sourceID: String, policy: StrategyGroupPolicy) {
        strategyGroupPolicies[sourceID] = policy.rawValue
    }

    func applyStrategyGroup(sourceID: String) {
        let nodes = catalogNodes.filter { $0.sourceID == sourceID }
        guard !nodes.isEmpty else {
            return
        }

        let policy = strategyGroupPolicy(for: sourceID)
        guard let selectedNode = preferredNode(in: nodes, policy: policy) else {
            return
        }

        selectConfiguration(id: selectedNode.stableID)
        let groupName = subscriptionSources.first(where: { $0.id == sourceID }).map(strategyGroupTitle(for:)) ?? sourceID
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "策略组「\(groupName)」已应用：\(displayName(for: policy))。"
            : "Applied strategy group \"\(groupName)\" as \(displayName(for: policy))."
    }

    func setStrategyGroupAlias(sourceID: String, alias: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            sourceGroupAliases.removeValue(forKey: sourceID)
        } else {
            sourceGroupAliases[sourceID] = trimmed
        }
    }

    func moveStrategyGroup(sourceID: String, by offset: Int) {
        guard let index = sourceGroupOrder.firstIndex(of: sourceID) else {
            return
        }
        let target = index + offset
        guard sourceGroupOrder.indices.contains(target) else {
            return
        }
        sourceGroupOrder.swapAt(index, target)
    }

    static func loadCustomStrategyGroups() -> [CustomStrategyGroup] {
        guard let data = UserDefaults.standard.data(forKey: Self.customStrategyGroupsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([CustomStrategyGroup].self, from: data)) ?? []
    }

    func saveCustomStrategyGroups() {
        guard let data = try? JSONEncoder().encode(customStrategyGroups) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.customStrategyGroupsKey)
    }

    func runtimeConfigurationCandidates() -> [ShadowsocksConfiguration] {
        let enabledSourceIDs = Set(subscriptionSources.filter(\.isEnabled).map(\.id))
        let scoped = catalogNodes
            .filter { enabledSourceIDs.contains($0.sourceID) || enabledSourceIDs.isEmpty }
            .map(\.configuration)
        let sorted = scoped.sorted(by: { $0.stableID < $1.stableID })
        var seen: Set<String> = []
        var result: [ShadowsocksConfiguration] = []
        for item in sorted where seen.insert(item.stableID).inserted {
            result.append(item)
        }
        return result
    }

    func runtimeProxyGroups() -> [MihomoProxyGroup] {
        let configs = runtimeConfigurationCandidates()
        let proxyNameByID = runtimeProxyNameByStableID(from: configs)
        guard !proxyNameByID.isEmpty else {
            return []
        }

        return customStrategyGroups.compactMap { group in
            let sourceNodes = catalogNodes.filter { $0.sourceID == group.sourceID }
            var names = sourceNodes.compactMap { proxyNameByID[$0.stableID] }
            if let preferredNodeID = group.preferredNodeID, let preferredName = proxyNameByID[preferredNodeID] {
                names.removeAll { $0 == preferredName }
                names.insert(preferredName, at: 0)
            }
            names = Array(NSOrderedSet(array: names)) as? [String] ?? names
            guard !names.isEmpty else {
                return nil
            }
            return MihomoProxyGroup(
                name: normalizedMihomoGroupName(group.name),
                type: mihomoGroupType(for: group.type),
                proxies: names,
                testURL: normalizedTestURL(group.testURL),
                intervalSeconds: normalizedIntervalSeconds(group.intervalSeconds)
            )
        }
    }

    private func normalizedTestURL(_ url: String?) -> String {
        let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "https://www.gstatic.com/generate_204" : trimmed
    }

    private func normalizedIntervalSeconds(_ value: Int?) -> Int {
        guard let value else {
            return 300
        }
        return min(max(value, 10), 86400)
    }

    private func preferredNodeForSmart(in nodes: [CatalogNode]) -> CatalogNode? {
        if let active = activeConfiguration,
           let activeNode = nodes.first(where: { $0.stableID == active.stableID }),
           activeNode.probeStatus == .success {
            return activeNode
        }

        let healthyWithLatency = nodes.filter { $0.probeStatus == .success && $0.latestLatencyMs != nil }
        if let best = healthyWithLatency.min(by: { ($0.latestLatencyMs ?? Int.max) < ($1.latestLatencyMs ?? Int.max) }) {
            return best
        }

        if let idle = nodes.first(where: { $0.probeStatus == .idle }) {
            return idle
        }
        return nodes.first
    }

    private func preferredNodeForURLTest(in nodes: [CatalogNode]) -> CatalogNode? {
        let healthyWithLatency = nodes.filter { $0.probeStatus == .success && $0.latestLatencyMs != nil }
        if let best = healthyWithLatency.min(by: { ($0.latestLatencyMs ?? Int.max) < ($1.latestLatencyMs ?? Int.max) }) {
            return best
        }
        return nodes.first
    }

    private func runtimeProxyNameByStableID(from configurations: [ShadowsocksConfiguration]) -> [String: String] {
        var used: [String: Int] = [:]
        var mapping: [String: String] = [:]
        for configuration in configurations {
            let preferredName = configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceName = (preferredName?.isEmpty == false) ? (preferredName ?? configuration.host) : configuration.host
            let base = normalizedMihomoGroupName(sourceName)
            let count = used[base, default: 0]
            used[base] = count + 1
            let final = count == 0 ? base : "\(base)-\(count + 1)"
            mapping[configuration.stableID] = final
        }
        return mapping
    }

    func normalizedMihomoGroupName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = Self.defaultRuntimeProxyGroupName
        let base = trimmed.isEmpty ? fallback : trimmed
        return base
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func mihomoGroupType(for type: CustomStrategyGroupType) -> MihomoProxyGroupType {
        switch type {
        case .manual:
            return .select
        case .smart, .urlTest:
            return .urlTest
        case .fallback:
            return .fallback
        case .loadBalance:
            return .loadBalance
        }
    }

    func preferredNode(in nodes: [CatalogNode], policy: StrategyGroupPolicy) -> CatalogNode? {
        switch policy {
        case .manual:
            if let active = activeConfiguration,
               let matched = nodes.first(where: { $0.stableID == active.stableID }) {
                return matched
            }
            return nodes.first
        case .fastest:
            let successful = nodes.filter { $0.probeStatus == .success && $0.latestLatencyMs != nil }
            if let best = successful.min(by: { ($0.latestLatencyMs ?? Int.max) < ($1.latestLatencyMs ?? Int.max) }) {
                return best
            }
            return nodes.first
        case .fallback:
            if let active = activeConfiguration,
               let matched = nodes.first(where: { $0.stableID == active.stableID && $0.probeStatus == .success }) {
                return matched
            }

            let sorted = nodes.sorted { lhs, rhs in
                let left = Self.fallbackRank(for: lhs)
                let right = Self.fallbackRank(for: rhs)
                if left != right {
                    return left < right
                }
                return (lhs.latestLatencyMs ?? Int.max) < (rhs.latestLatencyMs ?? Int.max)
            }
            return sorted.first
        }
    }

    static func fallbackRank(for node: CatalogNode) -> Int {
        switch node.probeStatus {
        case .success:
            return 0
        case .idle:
            return 1
        case .timeout:
            return 2
        case .failure:
            return 3
        }
    }

    private func resolvedNode(for group: CustomStrategyGroup) -> CatalogNode? {
        let sourceNodes = catalogNodes.filter { $0.sourceID == group.sourceID }
        guard !sourceNodes.isEmpty else {
            return nil
        }

        if let preferredNodeID = group.preferredNodeID,
           let preferred = sourceNodes.first(where: { $0.stableID == preferredNodeID }) {
            return preferred
        }
        if normalizedMihomoGroupName(group.name) == activeRuntimeProxyGroupName,
           let active = activeConfiguration,
           let matched = sourceNodes.first(where: { $0.stableID == active.stableID }) {
            return matched
        }
        switch group.type {
        case .manual:
            return preferredNode(in: sourceNodes, policy: .manual) ?? sourceNodes.first
        case .smart:
            return preferredNodeForSmart(in: sourceNodes) ?? sourceNodes.first
        case .urlTest:
            return preferredNodeForURLTest(in: sourceNodes) ?? sourceNodes.first
        case .fallback:
            return preferredNode(in: sourceNodes, policy: .fallback) ?? sourceNodes.first
        case .loadBalance:
            let healthy = sourceNodes.filter { $0.probeStatus == .success }
            return (healthy.isEmpty ? sourceNodes : healthy).first
        }
    }
}
