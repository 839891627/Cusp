import Foundation

extension AppViewModel {
    func selectConfigurationFromNodeTap(id: String) {
        if let activeGroup = activeCustomStrategyGroup(),
           activeGroup.type != .manual,
           let node = catalogNodes.first(where: { $0.stableID == id }),
           node.sourceID == activeGroup.sourceID {
            lastActionMessage = selectedLanguage == .simplifiedChinese
                ? "当前为自动策略组，节点由策略自动选择。若需手动切换，请先应用手动策略组。"
                : "This is an automatic strategy group. Node choice is handled automatically. Apply a manual group first to switch nodes manually."
            lastErrorMessage = nil
            return
        }
        selectConfiguration(id: id)
    }

    func selectConfiguration(id: String) {
        guard !isApplyingRuntimeChange else {
            return
        }
        let configuration = availableConfigurations.first(where: { $0.stableID == id })
            ?? catalogNodes.first(where: { $0.stableID == id })?.configuration
        guard let configuration else {
            return
        }

        let previousConfiguration = activeConfiguration
        activeConfiguration = configuration
        store.saveSelectedNodeID(id)
        if let sourceID = catalogNodes.first(where: { $0.stableID == id })?.sourceID {
            selectedSourceFilterID = sourceID
            UserDefaults.standard.set(sourceID, forKey: Self.nodePageSourceIDKey)
            customStrategyGroups = customStrategyGroups.map { group in
                guard group.type == .manual, group.sourceID == sourceID else {
                    return group
                }
                return CustomStrategyGroup(
                    id: group.id,
                    name: group.name,
                    type: group.type,
                    sourceID: group.sourceID,
                    preferredNodeID: id,
                    testURL: group.testURL,
                    intervalSeconds: group.intervalSeconds
                )
            }
        }
        persistCurrentSubscriptionCatalog()
        let summary = configuration.remark ?? configuration.host
        if connectionState == .connected {
            Task {
                do {
                    isApplyingRuntimeChange = true
                    runtimeActivityMessage = "Switching node to \(summary)..."
                    defer {
                        isApplyingRuntimeChange = false
                        runtimeActivityMessage = nil
                    }

                    try proxyService.stop()
                    try proxyService.start(
                        with: configuration,
                        allConfigurations: runtimeConfigurationCandidates(),
                        mode: selectedRuntimeMode,
                        routingRules: routingRules,
                        proxyGroups: runtimeProxyGroups(),
                        activeProxyGroupName: activeRuntimeProxyGroupName
                    )
                    lastActionMessage = "Switched to node \(summary)."
                    lastErrorMessage = nil
                } catch {
                    activeConfiguration = previousConfiguration
                    persistCurrentSubscriptionCatalog()
                    lastActionMessage = nil
                    lastErrorMessage = error.localizedDescription
                }
                refreshReadiness()
                await refreshOverviewMetrics()
            }
        } else {
            lastActionMessage = "Selected node \(summary)."
            lastErrorMessage = nil
            refreshReadiness()
            Task {
                await refreshOverviewMetrics()
            }
        }
    }

    func runSpeedTest() {
        let targetNodeIDs = Set(filteredCatalogNodes.map(\.stableID))
        guard !targetNodeIDs.isEmpty else {
            return
        }

        Task {
            isRunningSpeedTest = true
            probingNodeIDs = targetNodeIDs
            speedTestCompletedCount = 0
            speedTestTotalCount = targetNodeIDs.count
            defer {
                isRunningSpeedTest = false
                probingNodeIDs = []
                nodeSortMode = .latency
                availableConfigurations = visibleCatalogNodes.map(\.configuration)
            }

            await withTaskGroup(of: (String, NodeLatencyProbe.ProbeResult).self) { group in
                for node in filteredCatalogNodes {
                    let host = node.configuration.host
                    let port = node.configuration.port
                    let stableID = node.stableID
                    group.addTask {
                        let result = await NodeLatencyProbe.measureLatency(host: host, port: port)
                        return (stableID, result)
                    }
                }

                for await (stableID, result) in group {
                    if let index = catalogNodes.firstIndex(where: { $0.stableID == stableID }) {
                        let original = catalogNodes[index]
                        catalogNodes[index] = CatalogNode(
                            configuration: original.configuration,
                            sourceID: original.sourceID,
                            latestLatencyMs: result.latencyMs,
                            lastProbeAt: Date(),
                            probeStatus: result.status
                        )
                    }
                    probingNodeIDs.remove(stableID)
                    speedTestCompletedCount += 1
                }
            }

            persistCurrentSubscriptionCatalog()
            lastActionMessage = "Speed test finished for \(targetNodeIDs.count) visible nodes."
            lastErrorMessage = nil
            refreshReadiness()
            await refreshOverviewMetrics()
        }
    }

    func toggleLatencySorting() {
        nodeSortMode = nodeSortMode == .latency ? .manual : .latency
    }

    func setNodeSortMode(_ mode: NodeSortMode) {
        nodeSortMode = mode
    }

    func moveNode(id: String, by offset: Int) {
        guard nodeSortMode == .manual else {
            return
        }
        guard
            let currentIndex = catalogNodes.firstIndex(where: { $0.stableID == id }),
            offset != 0
        else {
            return
        }
        let sourceID = catalogNodes[currentIndex].sourceID
        let sourceIndexes = catalogNodes.indices.filter { catalogNodes[$0].sourceID == sourceID }
        guard let sourcePosition = sourceIndexes.firstIndex(of: currentIndex) else {
            return
        }
        let targetPosition = sourcePosition + offset
        guard sourceIndexes.indices.contains(targetPosition) else {
            return
        }

        let targetIndex = sourceIndexes[targetPosition]
        catalogNodes.swapAt(currentIndex, targetIndex)
        persistCurrentSubscriptionCatalog()
    }

    func setDefaultNode(id: String) {
        selectConfiguration(id: id)
    }

    func renameNode(id: String, to newName: String) {
        guard let index = catalogNodes.firstIndex(where: { $0.stableID == id }) else {
            return
        }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRemark = trimmed.isEmpty ? nil : trimmed
        let current = catalogNodes[index]
        let previousID = current.stableID
        let oldPasswordKey = nodePasswordKey(sourceID: current.sourceID, stableID: previousID)
        let updatedConfiguration = configuration(current.configuration, replacingRemark: normalizedRemark)
        let updated = CatalogNode(
            configuration: updatedConfiguration,
            sourceID: current.sourceID,
            latestLatencyMs: current.latestLatencyMs,
            lastProbeAt: current.lastProbeAt,
            probeStatus: current.probeStatus
        )
        catalogNodes[index] = updated

        let updatedID = updated.stableID
        let newPasswordKey = nodePasswordKey(sourceID: current.sourceID, stableID: updatedID)
        if let password = keychainString(for: oldPasswordKey) ?? nonEmptyTrimmed(current.configuration.password) {
            setKeychainString(password, for: newPasswordKey)
            if oldPasswordKey != newPasswordKey {
                removeKeychainValue(for: oldPasswordKey)
            }
        }
        if activeConfiguration?.stableID == previousID {
            activeConfiguration = updatedConfiguration
            store.saveSelectedNodeID(updatedID)
        }

        customStrategyGroups = customStrategyGroups.map { group in
            guard group.preferredNodeID == previousID else {
                return group
            }
            return CustomStrategyGroup(
                id: group.id,
                name: group.name,
                type: group.type,
                sourceID: group.sourceID,
                preferredNodeID: updatedID,
                testURL: group.testURL,
                intervalSeconds: group.intervalSeconds
            )
        }

        persistCurrentSubscriptionCatalog()
        let displayName = updatedConfiguration.remark ?? updatedConfiguration.host
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已重命名节点：\(displayName)。"
            : "Renamed node: \(displayName)."
        lastErrorMessage = nil
    }

    func duplicateNode(id: String) {
        guard let index = catalogNodes.firstIndex(where: { $0.stableID == id }) else {
            return
        }
        let original = catalogNodes[index]
        let duplicateName = uniqueDuplicateNodeName(
            base: nonEmptyTrimmed(original.configuration.remark) ?? original.configuration.host
        )
        let duplicatedConfiguration = configuration(original.configuration, replacingRemark: duplicateName)
        let duplicatedNode = CatalogNode(
            configuration: duplicatedConfiguration,
            sourceID: original.sourceID,
            latestLatencyMs: nil,
            lastProbeAt: nil,
            probeStatus: .idle
        )
        let sourcePasswordKey = nodePasswordKey(sourceID: original.sourceID, stableID: original.stableID)
        let duplicatedPasswordKey = nodePasswordKey(sourceID: duplicatedNode.sourceID, stableID: duplicatedNode.stableID)
        if let password = keychainString(for: sourcePasswordKey) ?? nonEmptyTrimmed(original.configuration.password) {
            setKeychainString(password, for: duplicatedPasswordKey)
        }
        catalogNodes.insert(duplicatedNode, at: min(index + 1, catalogNodes.count))
        persistCurrentSubscriptionCatalog()
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已复制节点：\(duplicateName)。"
            : "Duplicated node: \(duplicateName)."
        lastErrorMessage = nil
    }

    func deleteNode(id: String) {
        guard let index = catalogNodes.firstIndex(where: { $0.stableID == id }) else {
            return
        }

        let removed = catalogNodes.remove(at: index)
        let removedID = removed.stableID
        let removedPasswordKey = nodePasswordKey(sourceID: removed.sourceID, stableID: removedID)
        removeKeychainValue(for: removedPasswordKey)
        customStrategyGroups = customStrategyGroups.map { group in
            guard group.preferredNodeID == removedID else {
                return group
            }
            return CustomStrategyGroup(
                id: group.id,
                name: group.name,
                type: group.type,
                sourceID: group.sourceID,
                preferredNodeID: nil,
                testURL: group.testURL,
                intervalSeconds: group.intervalSeconds
            )
        }

        let deletedDisplayName = removed.configuration.remark ?? removed.configuration.host
        let wasActive = activeConfiguration?.stableID == removedID
        if wasActive {
            if let fallbackNode = visibleCatalogNodes.first {
                selectConfiguration(id: fallbackNode.stableID)
            } else {
                activeConfiguration = nil
                store.saveSelectedNodeID(nil)
                persistCurrentSubscriptionCatalog()
                if connectionState == .connected {
                    Task {
                        do {
                            try proxyService.stop()
                            await refreshOverviewMetrics()
                        } catch {
                            lastActionMessage = nil
                            lastErrorMessage = error.localizedDescription
                        }
                    }
                }
            }
        } else {
            persistCurrentSubscriptionCatalog()
        }

        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已删除节点：\(deletedDisplayName)。"
            : "Deleted node: \(deletedDisplayName)."
        lastErrorMessage = nil
        refreshReadiness()
        Task {
            await refreshOverviewMetrics()
        }
    }

    func selectSourceFilter(id: String?) {
        if let id {
            selectedSourceFilterID = id
        } else {
            selectedSourceFilterID = subscriptionSources.first(where: \.isEnabled)?.id
        }
        UserDefaults.standard.set(selectedSourceFilterID, forKey: Self.nodePageSourceIDKey)
        availableConfigurations = visibleCatalogNodes.map(\.configuration)
        reconcileSelectionIfNeeded()
    }
}
