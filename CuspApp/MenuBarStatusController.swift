import AppKit
import Foundation

@MainActor
final class MenuBarStatusController: NSObject, NSMenuDelegate {
    private let viewModel: AppViewModel
    private let statusItem: NSStatusItem
    private let rootMenu = NSMenu()
    private let outboundModeSubmenu = NSMenu()
    private let strategyGroupsSubmenu = NSMenu()
    private let nodesSubmenu = NSMenu()
    private let functionsSubmenu = NSMenu()
    private let sourceFilterSubmenu = NSMenu()

    private var refreshTimer: Timer?
    private var started = false

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

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
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
        viewModel.selectedLanguage == .simplifiedChinese
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

    private func refreshInteractiveStates() {
        connectItem.title = viewModel.connectionState == .connected ? viewModel.text(.disconnect) : viewModel.text(.connect)
        connectItem.isEnabled = viewModel.isConnectButtonEnabled

        modeRulesItem.state = viewModel.selectedRuntimeMode == .rules ? .on : .off
        modeGlobalItem.state = viewModel.selectedRuntimeMode == .global ? .on : .off
        modeDirectItem.state = viewModel.selectedRuntimeMode == .direct ? .on : .off

        toggleLaunchAtLoginItem.state = viewModel.launchAtLoginEnabled ? .on : .off
        toggleRestoreConnectionItem.state = viewModel.restoreConnectionOnLaunchEnabled ? .on : .off
        toggleDisconnectOnOtherVPNItem.state = viewModel.disconnectWhenOtherVPNActiveEnabled ? .on : .off
    }

    private func refreshLiveMetricsOnly() {
        downloadItem.title = "\(t("Download", "下载")): \(viewModel.downloadRateText)"
        uploadItem.title = "\(t("Upload", "上传")): \(viewModel.uploadRateText)"
        updateStatusButton()
    }

    private func refreshSnapshotLines() {
        runtimeItem.title = "\(t("Runtime", "运行状态")): \(viewModel.localizedConnectionStateTitle(viewModel.connectionState))"
        strategyGroupItem.title = "\(t("Strategy Group", "策略组")): \(viewModel.activeRuntimeProxyGroupName)"
        currentNodeItem.title = "\(t("Current Node", "当前节点")): \(viewModel.selectedNodeDisplayName)"
        latencyItem.title = "\(t("Latency", "延迟")): \(viewModel.latencyText)"
        ipItem.title = "IP: \(viewModel.ipAddressText)"
        refreshInteractiveStates()
        refreshLiveMetricsOnly()
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(systemSymbolName: viewModel.menuBarIconName, accessibilityDescription: "Cusp")
        button.image?.isTemplate = true
        button.toolTip = "Cusp"
    }

    func menuWillOpen(_ menu: NSMenu) {
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
        sourceFilterSubmenu.removeAllItems()
        configureRelativeDateFormatterLocale()
        let enabledSources = viewModel.subscriptionSources.filter(\.isEnabled)
        let totalNodes = enabledSources.reduce(0) { partial, source in
            partial + viewModel.catalogNodes.filter { $0.sourceID == source.id }.count
        }

        let allItem = NSMenuItem(
            title: "\(t("All Enabled Sources", "所有已启用订阅源")) · \(localizedNodesCount(totalNodes))",
            action: #selector(selectSourceFilter(_:)),
            keyEquivalent: ""
        )
        allItem.target = self
        allItem.representedObject = ""
        if viewModel.selectedSourceFilterID == nil {
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
            let item = NSMenuItem(title: sourceFilterDisplayTitle(source), action: #selector(selectSourceFilter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = source.id
            if source.id == viewModel.selectedSourceFilterID {
                item.state = .on
            }
            sourceFilterSubmenu.addItem(item)
        }
    }

    private func sourceFilterDisplayTitle(_ source: SubscriptionSource) -> String {
        let nodeCount = viewModel.catalogNodes.filter { $0.sourceID == source.id }.count
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
        strategyGroupsSubmenu.removeAllItems()
        let groups = viewModel.customStrategyGroups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard !groups.isEmpty else {
            let empty = NSMenuItem(title: t("No strategy groups", "暂无策略组"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            strategyGroupsSubmenu.addItem(empty)
            return
        }

        for group in groups {
            let parent = NSMenuItem(title: customGroupTitle(group), action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let canPickNodeManually = group.type == .manual

            let apply = NSMenuItem(title: t("Apply", "应用"), action: #selector(applyCustomStrategyGroup(_:)), keyEquivalent: "")
            apply.target = self
            apply.representedObject = group.id
            if normalizedGroupName(group.name) == viewModel.activeRuntimeProxyGroupName {
                apply.state = .on
            }
            submenu.addItem(apply)
            submenu.addItem(.separator())

            let latestSwitch = NSMenuItem(
                title: "\(t("Latest", "最近切换")): \(viewModel.strategyGroupLatestSwitchSummary(for: group.id))",
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
            let activeNodeID = viewModel.activeConfiguration?.stableID
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
    }

    private func rebuildNodesMenu() {
        nodesSubmenu.removeAllItems()
        let groups = sourceGroups
        guard !groups.isEmpty else {
            let empty = NSMenuItem(title: t("No nodes", "暂无节点"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            nodesSubmenu.addItem(empty)
            return
        }

        for group in groups {
            let parent = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for node in group.nodes {
                let item = NSMenuItem(title: menuNodeTitle(node), action: #selector(selectNode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = node.configuration.stableID
                if node.configuration.stableID == viewModel.activeConfiguration?.stableID {
                    item.state = .on
                }
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
        guard let group = viewModel.customStrategyGroups.first(where: { $0.id == parts[0] }) else {
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
        guard let sourceID = viewModel.selectedSourceFilterID else {
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
        viewModel.setLaunchAtLoginEnabled(!viewModel.launchAtLoginEnabled)
        refreshInteractiveStates()
    }

    @objc private func toggleRestoreConnection() {
        viewModel.setRestoreConnectionOnLaunchEnabled(!viewModel.restoreConnectionOnLaunchEnabled)
        refreshInteractiveStates()
    }

    @objc private func toggleDisconnectOnOtherVPN() {
        viewModel.setDisconnectWhenOtherVPNActiveEnabled(!viewModel.disconnectWhenOtherVPNActiveEnabled)
        refreshInteractiveStates()
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
        if normalizedName == viewModel.activeRuntimeProxyGroupName {
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
        let groupNodes = viewModel.catalogNodes.filter { $0.sourceID == sourceID }
        return NodeLatencyProbe.sortForDisplay(groupNodes)
    }

    private var sourceGroups: [SourceGroup] {
        let sourceNameByID = Dictionary(uniqueKeysWithValues: viewModel.subscriptionSources.map { ($0.id, viewModel.strategyGroupTitle(for: $0)) })
        let enabledSourceIDs = Set(viewModel.subscriptionSources.filter(\.isEnabled).map(\.id))
        let candidates = viewModel.catalogNodes
            .filter { enabledSourceIDs.contains($0.sourceID) || enabledSourceIDs.isEmpty }

        var grouped: [String: [CatalogNode]] = [:]
        for node in candidates {
            grouped[node.sourceID, default: []].append(node)
        }

        let unordered = grouped.map { sourceID, nodes in
            SourceGroup(
                id: sourceID,
                name: sourceNameByID[sourceID] ?? t("Ungrouped", "未分组"),
                nodes: NodeLatencyProbe.sortForDisplay(nodes)
            )
        }

        let orderMap = Dictionary(uniqueKeysWithValues: viewModel.sourceGroupOrder.enumerated().map { ($1, $0) })
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

