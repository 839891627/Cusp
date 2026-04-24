import AppKit
import Foundation

@MainActor
final class MenuBarStatusController: NSObject, NSMenuDelegate {
    private let viewModel: AppViewModel
    private let snapshotProvider: MenuBarSnapshotProvider
    private let statusItem: NSStatusItem
    private let rootMenu = NSMenu()
    private let outboundModeSubmenu = NSMenu()
    private let strategyGroupsSubmenu = NSMenu()
    private let nodesSubmenu = NSMenu()
    private let functionsSubmenu = NSMenu()
    private let sourceFilterSubmenu = NSMenu()

    private var refreshTimer: Timer?
    private var started = false
    private var isQuitting = false

    private let runtimeItem = NSMenuItem()
    private let strategyGroupItem = NSMenuItem()
    private let currentNodeItem = NSMenuItem()
    private let latencyItem = NSMenuItem()
    private let ipItem = NSMenuItem()
    private let connectItem = NSMenuItem()
    private let downloadItem = NSMenuItem()
    private let uploadItem = NSMenuItem()

    private let modeRulesItem = NSMenuItem()
    private let modeGlobalItem = NSMenuItem()
    private let modeDirectItem = NSMenuItem()

    private let toggleLaunchAtLoginItem = NSMenuItem()
    private let toggleRestoreConnectionItem = NSMenuItem()
    private let toggleDisconnectOnOtherVPNItem = NSMenuItem()
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    private var cachedSourceGroups: [SourceGroup] = []
    private var cachedSourceGroupsSignature: SourceGroupsCacheSignature?
    private var cachedSourceFilterSignature: SourceFilterMenuSignature?
    private var cachedStrategyGroupsSignature: StrategyGroupsMenuSignature?
    private var snapshot: MenuBarSnapshot

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self.snapshotProvider = MenuBarSnapshotProvider(viewModel: viewModel)
        self.snapshot = snapshotProvider.makeSnapshot()
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        relativeDateFormatter.unitsStyle = .short
        buildMenu()
        refreshSnapshotLines()
    }

    func startIfNeeded() {
        guard !started else {
            return
        }
        started = true
        statusItem.menu = rootMenu
        rootMenu.delegate = self
        strategyGroupsSubmenu.delegate = self
        nodesSubmenu.delegate = self
        sourceFilterSubmenu.delegate = self
        rebuildSourceFilterMenu()
        updateStatusButton()
        startRefreshTimer()
    }

    private var isChinese: Bool {
        snapshot.selectedLanguage == .simplifiedChinese
    }

    private func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    private func buildMenu() {
        runtimeItem.isEnabled = false
        strategyGroupItem.isEnabled = false
        currentNodeItem.isEnabled = false
        latencyItem.isEnabled = false
        ipItem.isEnabled = false

        rootMenu.addItem(runtimeItem)
        rootMenu.addItem(strategyGroupItem)
        rootMenu.addItem(currentNodeItem)
        rootMenu.addItem(latencyItem)
        rootMenu.addItem(ipItem)
        rootMenu.addItem(.separator())

        let showWindowItem = NSMenuItem(
            title: t("Show Main Window", "显示主窗口"),
            action: #selector(showMainWindow),
            keyEquivalent: "m"
        )
        showWindowItem.target = self
        rootMenu.addItem(showWindowItem)
        rootMenu.addItem(.separator())

        let modeParent = NSMenuItem(title: t("Outbound Mode", "出站模式"), action: nil, keyEquivalent: "")
        modeParent.submenu = outboundModeSubmenu
        rootMenu.addItem(modeParent)
        buildOutboundModeMenu()

        let strategyParent = NSMenuItem(title: t("Strategy Groups", "策略组"), action: nil, keyEquivalent: "")
        strategyParent.submenu = strategyGroupsSubmenu
        rootMenu.addItem(strategyParent)

        let nodesParent = NSMenuItem(title: t("Nodes", "节点"), action: nil, keyEquivalent: "")
        nodesParent.submenu = nodesSubmenu
        rootMenu.addItem(nodesParent)

        rootMenu.addItem(.separator())

        connectItem.target = self
        connectItem.action = #selector(toggleConnection)
        connectItem.keyEquivalent = "s"
        rootMenu.addItem(connectItem)

        rootMenu.addItem(menuItem(t("Open Overview", "打开总览"), action: #selector(openOverview)))
        rootMenu.addItem(menuItem(t("Open Routes", "打开连接路由"), action: #selector(openProcesses)))
        rootMenu.addItem(menuItem(t("Open Strategy", "打开策略"), action: #selector(openStrategy)))
        rootMenu.addItem(menuItem(t("Open Logs", "打开日志"), action: #selector(openLogs)))
        rootMenu.addItem(menuItem(t("Open Rules", "打开规则"), action: #selector(openRules)))
        rootMenu.addItem(menuItem(t("Open Subscriptions", "打开订阅"), action: #selector(openSubscriptions)))
        rootMenu.addItem(menuItem(t("Open Settings", "打开设置"), action: #selector(openSettings)))
        rootMenu.addItem(.separator())

        let functionsParent = NSMenuItem(title: t("Functions", "功能"), action: nil, keyEquivalent: "")
        functionsParent.submenu = functionsSubmenu
        rootMenu.addItem(functionsParent)
        buildFunctionsMenu()

        rootMenu.addItem(.separator())
        downloadItem.isEnabled = false
        uploadItem.isEnabled = false
        rootMenu.addItem(downloadItem)
        rootMenu.addItem(uploadItem)
        rootMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: t("Quit Cusp", "退出 Cusp"),
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        rootMenu.addItem(quitItem)
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func buildOutboundModeMenu() {
        modeRulesItem.title = t("Rules", "规则")
        modeRulesItem.target = self
        modeRulesItem.action = #selector(selectRuntimeMode(_:))
        modeRulesItem.representedObject = RuntimeMode.rules

        modeGlobalItem.title = t("Global", "全局")
        modeGlobalItem.target = self
        modeGlobalItem.action = #selector(selectRuntimeMode(_:))
        modeGlobalItem.representedObject = RuntimeMode.global

        modeDirectItem.title = "Direct"
        modeDirectItem.target = self
        modeDirectItem.action = #selector(selectRuntimeMode(_:))
        modeDirectItem.representedObject = RuntimeMode.direct

        outboundModeSubmenu.addItem(modeRulesItem)
        outboundModeSubmenu.addItem(modeGlobalItem)
        outboundModeSubmenu.addItem(modeDirectItem)
    }

    private func buildFunctionsMenu() {
        functionsSubmenu.addItem(menuItem(t("Refresh Enabled Sources", "刷新已启用来源"), action: #selector(refreshEnabledSources)))
        functionsSubmenu.addItem(menuItem(t("Refresh Current Source", "刷新当前订阅源"), action: #selector(refreshCurrentSource)))
        let sourceFilterParent = NSMenuItem(title: t("Select Source", "选择订阅源"), action: nil, keyEquivalent: "")
        sourceFilterParent.submenu = sourceFilterSubmenu
        functionsSubmenu.addItem(sourceFilterParent)
        functionsSubmenu.addItem(menuItem(t("Run Speed Test", "执行测速"), action: #selector(runSpeedTest)))
        functionsSubmenu.addItem(menuItem(t("Copy Terminal Proxy Env", "复制终端代理环境变量"), action: #selector(copyTerminalProxyCommands)))
        functionsSubmenu.addItem(menuItem(t("Copy System Proxy Commands", "复制系统代理命令"), action: #selector(copySystemProxyCommands)))
        functionsSubmenu.addItem(menuItem(t("Copy Logs", "复制日志"), action: #selector(copyLogs)))
        functionsSubmenu.addItem(.separator())

        toggleLaunchAtLoginItem.title = t("Launch At Login", "开机自启")
        toggleLaunchAtLoginItem.target = self
        toggleLaunchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        functionsSubmenu.addItem(toggleLaunchAtLoginItem)

        toggleRestoreConnectionItem.title = t("Restore Connection", "启动恢复连接")
        toggleRestoreConnectionItem.target = self
        toggleRestoreConnectionItem.action = #selector(toggleRestoreConnection)
        functionsSubmenu.addItem(toggleRestoreConnectionItem)

        toggleDisconnectOnOtherVPNItem.title = t("Disconnect On Other VPN", "检测其他 VPN 自动断开")
        toggleDisconnectOnOtherVPNItem.target = self
        toggleDisconnectOnOtherVPNItem.action = #selector(toggleDisconnectOnOtherVPN)
        functionsSubmenu.addItem(toggleDisconnectOnOtherVPNItem)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.refreshLiveMetricsOnly()
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func refreshSnapshot() {
        snapshot = snapshotProvider.makeSnapshot()
    }

    private func refreshInteractiveStates() {
        connectItem.title = snapshot.connectionState == .connected ? viewModel.text(.disconnect) : viewModel.text(.connect)
        connectItem.isEnabled = snapshot.isConnectButtonEnabled

        modeRulesItem.state = snapshot.selectedRuntimeMode == .rules ? .on : .off
        modeGlobalItem.state = snapshot.selectedRuntimeMode == .global ? .on : .off
        modeDirectItem.state = snapshot.selectedRuntimeMode == .direct ? .on : .off

        toggleLaunchAtLoginItem.state = snapshot.launchAtLoginEnabled ? .on : .off
        toggleRestoreConnectionItem.state = snapshot.restoreConnectionOnLaunchEnabled ? .on : .off
        toggleDisconnectOnOtherVPNItem.state = snapshot.disconnectWhenOtherVPNActiveEnabled ? .on : .off
    }

    private func refreshLiveMetricsOnly() {
        refreshSnapshot()
        downloadItem.title = "\(t("Download", "下载")): \(snapshot.downloadRateText)"
        uploadItem.title = "\(t("Upload", "上传")): \(snapshot.uploadRateText)"
        updateStatusButton()
    }

    private func refreshSnapshotLines() {
        refreshSnapshot()
        runtimeItem.title = "\(t("Runtime", "运行状态")): \(snapshot.runtimeStateTitle)"
        strategyGroupItem.title = "\(t("Strategy Group", "策略组")): \(snapshot.activeRuntimeProxyGroupName)"
        currentNodeItem.title = "\(t("Current Node", "当前节点")): \(snapshot.selectedNodeDisplayName)"
        latencyItem.title = "\(t("Latency", "延迟")): \(snapshot.latencyText)"
        ipItem.title = "IP: \(snapshot.ipAddressText)"
        refreshInteractiveStates()
        refreshLiveMetricsOnly()
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: snapshot.menuBarIconName, accessibilityDescription: "Cusp")
        button.image?.isTemplate = true
        button.toolTip = "Cusp"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshSnapshot()
        refreshSnapshotLines()
        if menu == strategyGroupsSubmenu {
            rebuildStrategyGroupsMenu()
        } else if menu == nodesSubmenu {
            rebuildNodesMenu()
        } else if menu == sourceFilterSubmenu {
            rebuildSourceFilterMenu()
        }
    }

    private func rebuildSourceFilterMenu() {
        configureRelativeDateFormatterLocale()
        let enabledSources = snapshot.enabledSources
        let nodeCountsBySourceID = Dictionary(grouping: snapshot.catalogNodes, by: \.sourceID)
            .mapValues(\.count)
        let signature = sourceFilterMenuSignature(
            enabledSources: enabledSources,
            nodeCountsBySourceID: nodeCountsBySourceID
        )
        if signature == cachedSourceFilterSignature {
            return
        }

        sourceFilterSubmenu.removeAllItems()
        let totalNodes = enabledSources.reduce(0) { partial, source in
            partial + nodeCountsBySourceID[source.id, default: 0]
        }

        let allItem = NSMenuItem(
            title: "\(t("All Enabled Sources", "所有已启用订阅源")) · \(localizedNodesCount(totalNodes))",
            action: #selector(selectSourceFilter(_:)),
            keyEquivalent: ""
        )
        allItem.target = self
        allItem.representedObject = ""
        if snapshot.selectedSourceFilterID == nil {
            allItem.state = .on
        }
        sourceFilterSubmenu.addItem(allItem)
        sourceFilterSubmenu.addItem(.separator())

        guard !enabledSources.isEmpty else {
            let empty = NSMenuItem(title: t("No enabled sources", "暂无启用订阅源"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            sourceFilterSubmenu.addItem(empty)
            return
        }

        for source in enabledSources {
            let item = NSMenuItem(
                title: sourceFilterDisplayTitle(source, nodeCountsBySourceID: nodeCountsBySourceID),
                action: #selector(selectSourceFilter(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = source.id
            if source.id == snapshot.selectedSourceFilterID {
                item.state = .on
            }
            sourceFilterSubmenu.addItem(item)
        }
        cachedSourceFilterSignature = signature
    }

    private func sourceFilterDisplayTitle(_ source: SubscriptionSource, nodeCountsBySourceID: [String: Int]) -> String {
        let nodeCount = nodeCountsBySourceID[source.id, default: 0]
        let nodePart = localizedNodesCount(nodeCount)
        let refreshPart = localizedRefreshSummary(source)
        return "\(source.name) · \(nodePart) · \(refreshPart)"
    }

    private func localizedNodesCount(_ count: Int) -> String {
        isChinese ? "\(count) 节点" : "\(count) nodes"
    }

    private func localizedRefreshSummary(_ source: SubscriptionSource) -> String {
        guard let lastRefreshAt = source.lastRefreshAt else {
            return t("never", "未刷新")
        }
        let relative = relativeDateFormatter.localizedString(for: lastRefreshAt, relativeTo: Date())
        switch source.lastRefreshStatus {
        case .failure:
            return isChinese ? "失败 · \(relative)" : "failed · \(relative)"
        case .success, .idle:
            return relative
        }
    }

    private func configureRelativeDateFormatterLocale() {
        relativeDateFormatter.locale = isChinese
            ? Locale(identifier: "zh-Hans-CN")
            : Locale(identifier: "en_US_POSIX")
    }

    private func rebuildStrategyGroupsMenu() {
        let groups = snapshot.customStrategyGroups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let signature = strategyGroupsMenuSignature(groups: groups)
        if signature == cachedStrategyGroupsSignature {
            return
        }

        if canIncrementallyUpdateStrategyGroupsMenu(with: groups) {
            updateExistingStrategyGroupsMenu(with: groups)
            cachedStrategyGroupsSignature = signature
            return
        }

        strategyGroupsSubmenu.removeAllItems()

        guard !groups.isEmpty else {
            let empty = NSMenuItem(title: t("No strategy groups", "暂无策略组"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            strategyGroupsSubmenu.addItem(empty)
            cachedStrategyGroupsSignature = signature
            return
        }

        for group in groups {
            let parent = NSMenuItem(title: customGroupTitle(group), action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let canPickNodeManually = group.type == .manual

            let apply = NSMenuItem(title: t("Apply", "应用"), action: #selector(applyCustomStrategyGroup(_:)), keyEquivalent: "")
            apply.target = self
            apply.representedObject = group.id
            if normalizedGroupName(group.name) == snapshot.activeRuntimeProxyGroupName {
                apply.state = .on
            }
            submenu.addItem(apply)
            submenu.addItem(.separator())

            let latestSwitch = NSMenuItem(
                title: "\(t("Latest", "最近切换")): \(snapshot.strategyGroupLatestSwitchSummaryByID[group.id, default: t("No switch yet", "尚未切换")])",
                action: nil,
                keyEquivalent: ""
            )
            latestSwitch.isEnabled = false
            submenu.addItem(latestSwitch)
            submenu.addItem(.separator())

            if !canPickNodeManually {
                let autoHint = NSMenuItem(
                    title: t("Node selection is automatic", "节点由策略自动选择"),
                    action: nil,
                    keyEquivalent: ""
                )
                autoHint.isEnabled = false
                submenu.addItem(autoHint)
                submenu.addItem(.separator())
            }

            let groupNodes = nodes(forSourceID: group.sourceID)
            let activeNodeID = snapshot.activeNodeID
            for node in groupNodes {
                let title = menuNodeTitle(node)
                let item = NSMenuItem(
                    title: title,
                    action: canPickNodeManually ? #selector(selectNodeForCustomGroup(_:)) : nil,
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = "\(group.id)|\(node.configuration.stableID)"
                if node.configuration.stableID == activeNodeID {
                    item.state = .on
                }
                item.isEnabled = canPickNodeManually
                submenu.addItem(item)
            }

            parent.submenu = submenu
            strategyGroupsSubmenu.addItem(parent)
        }
        cachedStrategyGroupsSignature = signature
    }

    private func canIncrementallyUpdateStrategyGroupsMenu(with groups: [CustomStrategyGroup]) -> Bool {
        guard strategyGroupsSubmenu.items.count == groups.count else {
            return false
        }

        for (index, group) in groups.enumerated() {
            let parent = strategyGroupsSubmenu.items[index]
            guard let submenu = parent.submenu else {
                return false
            }

            let canPickNodeManually = group.type == .manual
            let groupNodes = nodes(forSourceID: group.sourceID)
            let prefixCount = canPickNodeManually ? 4 : 6
            guard submenu.items.count == prefixCount + groupNodes.count else {
                return false
            }
            guard submenu.items.indices.contains(0),
                  submenu.items.indices.contains(2) else {
                return false
            }
            guard submenu.items[0].representedObject as? String == group.id else {
                return false
            }

            for (nodeIndex, node) in groupNodes.enumerated() {
                let menuIndex = prefixCount + nodeIndex
                guard submenu.items.indices.contains(menuIndex),
                      submenu.items[menuIndex].representedObject as? String == "\(group.id)|\(node.configuration.stableID)" else {
                    return false
                }
            }
        }

        return true
    }

    private func updateExistingStrategyGroupsMenu(with groups: [CustomStrategyGroup]) {
        let activeNodeID = snapshot.activeNodeID
        for (index, group) in groups.enumerated() {
            let parent = strategyGroupsSubmenu.items[index]
            parent.title = customGroupTitle(group)
            guard let submenu = parent.submenu else {
                continue
            }

            let canPickNodeManually = group.type == .manual
            let prefixCount = canPickNodeManually ? 4 : 6

            let apply = submenu.items[0]
            apply.title = t("Apply", "应用")
            apply.target = self
            apply.action = #selector(applyCustomStrategyGroup(_:))
            apply.representedObject = group.id
            apply.state = normalizedGroupName(group.name) == snapshot.activeRuntimeProxyGroupName ? .on : .off

            let latestSwitch = submenu.items[2]
            latestSwitch.title = "\(t("Latest", "最近切换")): \(snapshot.strategyGroupLatestSwitchSummaryByID[group.id, default: t("No switch yet", "尚未切换")])"
            latestSwitch.isEnabled = false

            if !canPickNodeManually, submenu.items.indices.contains(4) {
                let autoHint = submenu.items[4]
                autoHint.title = t("Node selection is automatic", "节点由策略自动选择")
                autoHint.isEnabled = false
            }

            let groupNodes = nodes(forSourceID: group.sourceID)
            for (nodeIndex, node) in groupNodes.enumerated() {
                let menuIndex = prefixCount + nodeIndex
                guard submenu.items.indices.contains(menuIndex) else {
                    continue
                }
                let item = submenu.items[menuIndex]
                item.title = menuNodeTitle(node)
                item.target = self
                item.action = canPickNodeManually ? #selector(selectNodeForCustomGroup(_:)) : nil
                item.representedObject = "\(group.id)|\(node.configuration.stableID)"
                item.state = node.configuration.stableID == activeNodeID ? .on : .off
                item.isEnabled = canPickNodeManually
            }
        }
    }

    private func sourceFilterMenuSignature(
        enabledSources: [SubscriptionSource],
        nodeCountsBySourceID: [String: Int]
    ) -> SourceFilterMenuSignature {
        let sourceSnapshots = enabledSources
            .map { source in
                SourceFilterSourceSnapshot(
                    id: source.id,
                    name: source.name,
                    nodeCount: nodeCountsBySourceID[source.id, default: 0],
                    lastRefreshAt: source.lastRefreshAt,
                    refreshStatusRawValue: source.lastRefreshStatus.rawValue
                )
            }
            .sorted { $0.id < $1.id }

        return SourceFilterMenuSignature(
            language: snapshot.selectedLanguage.rawValue,
            selectedSourceFilterID: snapshot.selectedSourceFilterID,
            minuteBucket: Int(Date().timeIntervalSince1970 / 60),
            sources: sourceSnapshots
        )
    }

    private func strategyGroupsMenuSignature(groups: [CustomStrategyGroup]) -> StrategyGroupsMenuSignature {
        let nodes = snapshot.catalogNodes
        let nodeSnapshots = groups
            .flatMap { group in
                nodes
                    .filter { $0.sourceID == group.sourceID }
                    .map { node in
                        StrategyGroupNodeSnapshot(
                            groupID: group.id,
                            stableID: node.stableID,
                            latestLatencyMs: node.latestLatencyMs,
                            probeStatusRawValue: node.probeStatus.rawValue
                        )
                    }
            }
            .sorted {
                if $0.groupID == $1.groupID {
                    return $0.stableID < $1.stableID
                }
                return $0.groupID < $1.groupID
            }

        return StrategyGroupsMenuSignature(
            language: snapshot.selectedLanguage.rawValue,
            minuteBucket: Int(Date().timeIntervalSince1970 / 60),
            activeRuntimeProxyGroupName: snapshot.activeRuntimeProxyGroupName,
            activeNodeID: snapshot.activeNodeID,
            groups: groups,
            switchRecords: snapshot.strategyGroupSwitchRecords,
            nodeSnapshots: nodeSnapshots
        )
    }

    private func rebuildNodesMenu() {
        let groups = sourceGroups
        guard !groups.isEmpty else {
            nodesSubmenu.removeAllItems()
            let empty = NSMenuItem(title: t("No nodes", "暂无节点"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            nodesSubmenu.addItem(empty)
            return
        }

        if canIncrementallyUpdateNodesMenu(with: groups) {
            updateExistingNodesMenu(with: groups)
            return
        }

        rebuildNodesMenuFull(with: groups)
    }

    private func canIncrementallyUpdateNodesMenu(with groups: [SourceGroup]) -> Bool {
        guard nodesSubmenu.items.count == groups.count else {
            return false
        }

        for (index, group) in groups.enumerated() {
            let parent = nodesSubmenu.items[index]
            guard parent.title == group.name, let submenu = parent.submenu else {
                return false
            }
            guard submenu.items.count == group.nodes.count else {
                return false
            }

            for (itemIndex, node) in group.nodes.enumerated() {
                guard let stableID = submenu.items[itemIndex].representedObject as? String,
                      stableID == node.configuration.stableID else {
                    return false
                }
            }
        }

        return true
    }

    private func updateExistingNodesMenu(with groups: [SourceGroup]) {
        let activeNodeID = snapshot.activeNodeID
        for (index, group) in groups.enumerated() {
            let parent = nodesSubmenu.items[index]
            parent.title = group.name
            guard let submenu = parent.submenu else {
                continue
            }

            for (itemIndex, node) in group.nodes.enumerated() {
                let item = submenu.items[itemIndex]
                item.title = menuNodeTitle(node)
                item.target = self
                item.action = #selector(selectNode(_:))
                item.representedObject = node.configuration.stableID
                item.state = node.configuration.stableID == activeNodeID ? .on : .off
            }
        }
    }

    private func rebuildNodesMenuFull(with groups: [SourceGroup]) {
        nodesSubmenu.removeAllItems()
        let activeNodeID = snapshot.activeNodeID
        for group in groups {
            let parent = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for node in group.nodes {
                let item = NSMenuItem(title: menuNodeTitle(node), action: #selector(selectNode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = node.configuration.stableID
                item.state = node.configuration.stableID == activeNodeID ? .on : .off
                submenu.addItem(item)
            }
            parent.submenu = submenu
            nodesSubmenu.addItem(parent)
        }
    }

    @objc private func showMainWindow() {
        bringMainWindow(section: nil)
    }

    @objc private func openStrategy() {
        bringMainWindow(section: .nodes)
    }

    @objc private func openOverview() {
        bringMainWindow(section: .overview)
    }

    @objc private func openProcesses() {
        bringMainWindow(section: .processes)
    }

    @objc private func openLogs() {
        bringMainWindow(section: .logs)
    }

    @objc private func openRules() {
        bringMainWindow(section: .rules)
    }

    @objc private func openSubscriptions() {
        bringMainWindow(section: .subscriptions)
    }

    @objc private func openSettings() {
        bringMainWindow(section: .settings)
    }

    private func bringMainWindow(section: AppSection?) {
        if let section {
            viewModel.selectedSection = section
        }
        AppVisibilityController.shared.prepareToShowMainWindow()
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func selectRuntimeMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? RuntimeMode else {
            return
        }
        viewModel.selectRuntimeMode(mode)
        refreshSnapshotLines()
    }

    @objc private func applyCustomStrategyGroup(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        viewModel.applyCustomStrategyGroup(id: id)
        refreshSnapshotLines()
    }

    @objc private func selectNodeForCustomGroup(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? String else {
            return
        }
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return
        }
        guard let group = snapshot.customStrategyGroups.first(where: { $0.id == parts[0] }) else {
            return
        }
        guard group.type == .manual else {
            viewModel.lastActionMessage = isChinese
                ? "当前为自动策略组，节点由策略自动选择。若需手动切换，请先应用手动策略组。"
                : "This is an automatic strategy group. Node choice is handled automatically. Apply a manual group first to switch nodes manually."
            viewModel.lastErrorMessage = nil
            refreshSnapshotLines()
            return
        }
        viewModel.setPreferredNodeForCustomStrategyGroup(id: parts[0], nodeID: parts[1])
        viewModel.applyCustomStrategyGroup(id: parts[0])
        refreshSnapshotLines()
    }

    @objc private func selectNode(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        viewModel.selectConfigurationFromNodeTap(id: id)
        refreshSnapshotLines()
    }

    @objc private func toggleConnection() {
        viewModel.toggleConnection()
        refreshSnapshotLines()
    }

    @objc private func refreshEnabledSources() {
        viewModel.refreshAllSubscriptions()
    }

    @objc private func refreshCurrentSource() {
        refreshSnapshot()
        guard let sourceID = snapshot.selectedSourceFilterID else {
            return
        }
        viewModel.refreshSubscription(id: sourceID)
    }

    @objc private func selectSourceFilter(_ sender: NSMenuItem) {
        if let sourceID = sender.representedObject as? String, !sourceID.isEmpty {
            viewModel.selectSourceFilter(id: sourceID)
        } else {
            viewModel.selectSourceFilter(id: nil)
        }
        refreshSnapshotLines()
    }

    @objc private func runSpeedTest() {
        viewModel.runSpeedTest()
    }

    @objc private func copyTerminalProxyCommands() {
        viewModel.copyTerminalProxyCommand()
    }

    @objc private func copySystemProxyCommands() {
        viewModel.copySystemProxyCommand()
    }

    @objc private func copyLogs() {
        viewModel.copyLogsToClipboard()
    }

    @objc private func toggleLaunchAtLogin() {
        refreshSnapshot()
        viewModel.setLaunchAtLoginEnabled(!snapshot.launchAtLoginEnabled)
        refreshInteractiveStates()
    }

    @objc private func toggleRestoreConnection() {
        refreshSnapshot()
        viewModel.setRestoreConnectionOnLaunchEnabled(!snapshot.restoreConnectionOnLaunchEnabled)
        refreshInteractiveStates()
    }

    @objc private func toggleDisconnectOnOtherVPN() {
        refreshSnapshot()
        viewModel.setDisconnectWhenOtherVPNActiveEnabled(!snapshot.disconnectWhenOtherVPNActiveEnabled)
        refreshInteractiveStates()
    }

    @objc private func quitApplication() {
        guard !isQuitting else {
            return
        }
        isQuitting = true
        Task { @MainActor in
            await viewModel.disconnectBeforeQuitIfNeeded()
            NSApplication.shared.terminate(nil)
        }
    }

    private func nodeDisplayName(_ configuration: ShadowsocksConfiguration) -> String {
        let trimmed = configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return "\(configuration.host):\(configuration.port)"
    }

    private func menuNodeTitle(_ node: CatalogNode) -> String {
        "\(nodeDisplayName(node.configuration)) · \(nodeLatencyText(node))"
    }

    private func nodeLatencyText(_ node: CatalogNode) -> String {
        if let latency = node.latestLatencyMs {
            return "\(latency)ms"
        }
        switch node.probeStatus {
        case .timeout:
            return t("timeout", "超时")
        case .failure:
            return t("failed", "失败")
        case .idle, .success:
            return "--"
        }
    }

    private func customGroupTitle(_ group: CustomStrategyGroup) -> String {
        let normalizedName = normalizedGroupName(group.name)
        if normalizedName == snapshot.activeRuntimeProxyGroupName {
            return "\(group.name) ✓"
        }
        return group.name
    }

    private func normalizedGroupName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func nodes(forSourceID sourceID: String) -> [CatalogNode] {
        let groupNodes = snapshot.catalogNodes.filter { $0.sourceID == sourceID }
        return NodeLatencyProbe.sortForDisplay(groupNodes)
    }

    private var sourceGroups: [SourceGroup] {
        let signature = sourceGroupsCacheSignature()
        if signature == cachedSourceGroupsSignature {
            return cachedSourceGroups
        }

        let sorted = snapshot.sourceGroups.map {
            SourceGroup(id: $0.id, name: $0.name, nodes: $0.nodes)
        }
        cachedSourceGroups = sorted
        cachedSourceGroupsSignature = signature
        return sorted
    }

    private func sourceGroupsCacheSignature() -> SourceGroupsCacheSignature {
        var hasher = Hasher()
        hasher.combine(snapshot.selectedLanguage.rawValue)
        snapshot.sourceGroupOrder.forEach { hasher.combine($0) }

        let enabledSourceIDs = snapshot.enabledSources
            .map(\.id)
            .sorted()
        enabledSourceIDs.forEach { hasher.combine($0) }

        let sourceNamePairs = snapshot.strategyGroupTitleBySourceID
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
        for (id, title) in sourceNamePairs {
            hasher.combine(id)
            hasher.combine(title)
        }

        let sortedNodes = snapshot.catalogNodes.sorted {
            if $0.sourceID == $1.sourceID {
                return $0.stableID < $1.stableID
            }
            return $0.sourceID < $1.sourceID
        }
        hasher.combine(sortedNodes.count)
        for node in sortedNodes {
            hasher.combine(node.sourceID)
            hasher.combine(node.stableID)
            hasher.combine(node.latestLatencyMs)
            hasher.combine(node.probeStatus.rawValue)
        }

        return SourceGroupsCacheSignature(digest: hasher.finalize())
    }
}

private struct MenuBarSourceGroup {
    let id: String
    let name: String
    let nodes: [CatalogNode]
}

private struct MenuBarSnapshot {
    let selectedLanguage: AppLanguage
    let connectionState: ConnectionState
    let isConnectButtonEnabled: Bool
    let selectedRuntimeMode: RuntimeMode
    let launchAtLoginEnabled: Bool
    let restoreConnectionOnLaunchEnabled: Bool
    let disconnectWhenOtherVPNActiveEnabled: Bool
    let downloadRateText: String
    let uploadRateText: String
    let runtimeStateTitle: String
    let activeRuntimeProxyGroupName: String
    let selectedNodeDisplayName: String
    let latencyText: String
    let ipAddressText: String
    let menuBarIconName: String
    let selectedSourceFilterID: String?
    let enabledSources: [SubscriptionSource]
    let catalogNodes: [CatalogNode]
    let customStrategyGroups: [CustomStrategyGroup]
    let activeNodeID: String?
    let strategyGroupSwitchRecords: [String: StrategyGroupSwitchRecord]
    let sourceGroupOrder: [String]
    let strategyGroupTitleBySourceID: [String: String]
    let strategyGroupLatestSwitchSummaryByID: [String: String]
    let sourceGroups: [MenuBarSourceGroup]
}

@MainActor
private final class MenuBarSnapshotProvider {
    private let viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func makeSnapshot() -> MenuBarSnapshot {
        let subscriptionSources = viewModel.subscriptionSources
        let enabledSources = subscriptionSources.filter(\.isEnabled)
        let catalogNodes = viewModel.catalogNodes
        let customGroups = viewModel.customStrategyGroups
        let strategyGroupTitleBySourceID = Dictionary(
            uniqueKeysWithValues: subscriptionSources.map { ($0.id, viewModel.strategyGroupTitle(for: $0)) }
        )
        let strategyGroupLatestSwitchSummaryByID = Dictionary(
            uniqueKeysWithValues: customGroups.map { ($0.id, viewModel.strategyGroupLatestSwitchSummary(for: $0.id)) }
        )

        return MenuBarSnapshot(
            selectedLanguage: viewModel.selectedLanguage,
            connectionState: viewModel.connectionState,
            isConnectButtonEnabled: viewModel.isConnectButtonEnabled,
            selectedRuntimeMode: viewModel.selectedRuntimeMode,
            launchAtLoginEnabled: viewModel.launchAtLoginEnabled,
            restoreConnectionOnLaunchEnabled: viewModel.restoreConnectionOnLaunchEnabled,
            disconnectWhenOtherVPNActiveEnabled: viewModel.disconnectWhenOtherVPNActiveEnabled,
            downloadRateText: viewModel.downloadRateText,
            uploadRateText: viewModel.uploadRateText,
            runtimeStateTitle: viewModel.localizedConnectionStateTitle(viewModel.connectionState),
            activeRuntimeProxyGroupName: viewModel.activeRuntimeProxyGroupName,
            selectedNodeDisplayName: viewModel.selectedNodeDisplayName,
            latencyText: viewModel.latencyText,
            ipAddressText: viewModel.ipAddressText,
            menuBarIconName: viewModel.menuBarIconName,
            selectedSourceFilterID: viewModel.selectedSourceFilterID,
            enabledSources: enabledSources,
            catalogNodes: catalogNodes,
            customStrategyGroups: customGroups,
            activeNodeID: viewModel.activeConfiguration?.stableID,
            strategyGroupSwitchRecords: viewModel.strategyGroupSwitchRecords,
            sourceGroupOrder: viewModel.sourceGroupOrder,
            strategyGroupTitleBySourceID: strategyGroupTitleBySourceID,
            strategyGroupLatestSwitchSummaryByID: strategyGroupLatestSwitchSummaryByID,
            sourceGroups: makeSourceGroups(
                catalogNodes: catalogNodes,
                enabledSourceIDs: Set(enabledSources.map(\.id)),
                sourceGroupOrder: viewModel.sourceGroupOrder,
                strategyGroupTitleBySourceID: strategyGroupTitleBySourceID,
                language: viewModel.selectedLanguage
            )
        )
    }

    private func makeSourceGroups(
        catalogNodes: [CatalogNode],
        enabledSourceIDs: Set<String>,
        sourceGroupOrder: [String],
        strategyGroupTitleBySourceID: [String: String],
        language: AppLanguage
    ) -> [MenuBarSourceGroup] {
        let candidates = catalogNodes
            .filter { enabledSourceIDs.contains($0.sourceID) || enabledSourceIDs.isEmpty }

        var grouped: [String: [CatalogNode]] = [:]
        for node in candidates {
            grouped[node.sourceID, default: []].append(node)
        }

        let fallbackName = language == .simplifiedChinese ? "未分组" : "Ungrouped"
        let unordered = grouped.map { sourceID, nodes in
            MenuBarSourceGroup(
                id: sourceID,
                name: strategyGroupTitleBySourceID[sourceID] ?? fallbackName,
                nodes: NodeLatencyProbe.sortForDisplay(nodes)
            )
        }

        let orderMap = Dictionary(uniqueKeysWithValues: sourceGroupOrder.enumerated().map { ($1, $0) })
        return unordered.sorted { lhs, rhs in
            let left = orderMap[lhs.id] ?? Int.max
            let right = orderMap[rhs.id] ?? Int.max
            if left != right {
                return left < right
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private struct SourceGroup {
    let id: String
    let name: String
    let nodes: [CatalogNode]
}

private struct SourceGroupsCacheSignature: Equatable {
    let digest: Int
}

private struct SourceFilterSourceSnapshot: Equatable {
    let id: String
    let name: String
    let nodeCount: Int
    let lastRefreshAt: Date?
    let refreshStatusRawValue: String
}

private struct SourceFilterMenuSignature: Equatable {
    let language: String
    let selectedSourceFilterID: String?
    let minuteBucket: Int
    let sources: [SourceFilterSourceSnapshot]
}

private struct StrategyGroupNodeSnapshot: Equatable {
    let groupID: String
    let stableID: String
    let latestLatencyMs: Int?
    let probeStatusRawValue: String
}

private struct StrategyGroupsMenuSignature: Equatable {
    let language: String
    let minuteBucket: Int
    let activeRuntimeProxyGroupName: String
    let activeNodeID: String?
    let groups: [CustomStrategyGroup]
    let switchRecords: [String: StrategyGroupSwitchRecord]
    let nodeSnapshots: [StrategyGroupNodeSnapshot]
}

