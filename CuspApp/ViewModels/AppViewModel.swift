import AppKit
import Combine
import Darwin
import Foundation
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    enum ImportError: Swift.Error, Equatable {
        case invalidURL
        case invalidResponse
        case httpStatus(Int)
        case unreadableSubscription
        case timeout
        case networkUnavailable
    }

    struct SubscriptionFetchResult: Sendable {
        let body: String
        let usageInfo: SubscriptionUsageInfo?
    }

    enum SubscriptionRefreshTrigger {
        case manual
        case automatic
    }

    @Published var connectionState: ConnectionState = .disconnected {
        didSet {
            guard connectionState != oldValue else {
                return
            }
            appendLog(
                level: .info,
                category: "Connection",
                message: "State changed to \(localizedConnectionStateTitle(connectionState))."
            )
            Task {
                await refreshOverviewMetrics()
            }
        }
    }
    @Published var selectedSection: AppSection = .overview
    @Published var selectedLanguage: AppLanguage = .english {
        didSet {
            guard selectedLanguage != oldValue else {
                return
            }
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.selectedLanguageKey)
        }
    }
    @Published var selectedSubscriptionRefreshInterval: SubscriptionRefreshInterval = .manual {
        didSet {
            guard selectedSubscriptionRefreshInterval != oldValue else {
                return
            }
            UserDefaults.standard.set(selectedSubscriptionRefreshInterval.rawValue, forKey: Self.subscriptionRefreshIntervalKey)
            configureAutoRefreshTask()
        }
    }
    @Published var sourceGroupAliases: [String: String] = [:] {
        didSet {
            guard sourceGroupAliases != oldValue else {
                return
            }
            UserDefaults.standard.set(sourceGroupAliases, forKey: Self.sourceGroupAliasesKey)
        }
    }
    @Published var sourceGroupOrder: [String] = [] {
        didSet {
            guard sourceGroupOrder != oldValue else {
                return
            }
            UserDefaults.standard.set(sourceGroupOrder, forKey: Self.sourceGroupOrderKey)
        }
    }
    @Published var strategyGroupPolicies: [String: String] = [:] {
        didSet {
            guard strategyGroupPolicies != oldValue else {
                return
            }
            UserDefaults.standard.set(strategyGroupPolicies, forKey: Self.strategyGroupPoliciesKey)
        }
    }
    @Published var importText = ""
    @Published var subscriptionNameInput = ""
    @Published var editingSubscriptionID: String?
    @Published var nodeSearchText = ""
    @Published var activeConfiguration: ShadowsocksConfiguration?
    @Published var availableConfigurations: [ShadowsocksConfiguration] = []
    @Published var subscriptionSources: [SubscriptionSource] = []
    @Published var catalogNodes: [CatalogNode] = []
    @Published var selectedRuntimeMode: RuntimeMode = .rules
    @Published var routingRules: [RoutingRule] = RoutingRulePreset.commonMVP
    @Published var ruleMatcherInput = ""
    @Published var selectedRuleType: RoutingRuleType = .domainSuffix
    @Published var selectedRuleAction: RoutingRuleAction = .proxy
    @Published var launchAtLoginEnabled = false
    @Published var restoreConnectionOnLaunchEnabled = true
    @Published var notificationEnabled = true
    @Published var disconnectWhenOtherVPNActiveEnabled = true
    @Published var selectedSourceFilterID: String?
    @Published var nodeSortMode: NodeSortMode = .latency {
        didSet {
            guard nodeSortMode != oldValue else {
                return
            }
            UserDefaults.standard.set(nodeSortMode.rawValue, forKey: Self.nodeSortModeKey)
            availableConfigurations = visibleCatalogNodes.map(\.configuration)
        }
    }
    @Published var activeRuntimeProxyGroupName: String = "Cusp" {
        didSet {
            guard activeRuntimeProxyGroupName != oldValue else {
                return
            }
            UserDefaults.standard.set(activeRuntimeProxyGroupName, forKey: Self.activeRuntimeProxyGroupNameKey)
        }
    }
    @Published var customStrategyGroups: [CustomStrategyGroup] = [] {
        didSet {
            guard customStrategyGroups != oldValue else {
                return
            }
            saveCustomStrategyGroups()
        }
    }
    @Published var strategyGroupSwitchRecords: [String: StrategyGroupSwitchRecord] = [:] {
        didSet {
            guard strategyGroupSwitchRecords != oldValue else {
                return
            }
            saveStrategyGroupSwitchRecords()
        }
    }
    @Published var isRunningSpeedTest = false
    @Published var isApplyingRuntimeChange = false
    @Published var runtimeActivityMessage: String? {
        didSet {
            guard runtimeActivityMessage != oldValue else {
                return
            }
            guard let runtimeActivityMessage, !runtimeActivityMessage.isEmpty else {
                return
            }
            appendLog(level: .info, category: "Runtime", message: runtimeActivityMessage)
        }
    }
    @Published var probingNodeIDs: Set<String> = []
    @Published var speedTestCompletedCount = 0
    @Published var speedTestTotalCount = 0
    @Published var readinessReport = MVPReadinessEvaluator.report(
        hasConfiguration: false,
        hasBundledBinary: false,
        hasNetworkServices: false
    )
    @Published var setupGuide = TrialSetupGuideBuilder.build(
        from: MVPReadinessEvaluator.report(
            hasConfiguration: false,
            hasBundledBinary: false,
            hasNetworkServices: false
        )
    )
    @Published var latencyText = "-- ms"
    @Published var ipAddressText = "--"
    @Published var uploadRateText = "0 KB/s"
    @Published var downloadRateText = "0 KB/s"
    @Published var sessionUploadText = "0 B"
    @Published var sessionDownloadText = "0 B"
    @Published var todayTotalText = "0 B"
    @Published var monthlyTotalText = "0 B"
    @Published private(set) var trafficSamples: [TrafficSample] = []
    @Published var lastActionMessage: String? {
        didSet {
            guard lastActionMessage != oldValue else {
                return
            }
            guard let lastActionMessage, !lastActionMessage.isEmpty else {
                return
            }
            appendLog(level: .success, category: "Action", message: lastActionMessage)
        }
    }
    @Published var lastErrorMessage: String? {
        didSet {
            guard lastErrorMessage != oldValue else {
                return
            }
            guard let lastErrorMessage, !lastErrorMessage.isEmpty else {
                return
            }
            appendLog(level: .error, category: "Error", message: lastErrorMessage)
        }
    }
    @Published private(set) var logEntries: [AppLogEntry] = []

    let store: SharedConfigurationStore
    let proxyService: LocalProxyManagerService
    private let credentialStore: SecureCredentialStore
    private var hasBootstrapped = false
    private var metricsRefreshTask: Task<Void, Never>?
    var autoRefreshTask: Task<Void, Never>?
    private var trafficRefreshTask: Task<Void, Never>?
    private var externalVPNMonitorTask: Task<Void, Never>?
    private var proxyPreparationError: String?
    private var lastTrafficSnapshot: NetworkByteSnapshot?
    private var sessionUploadBytes: UInt64 = 0
    private var sessionDownloadBytes: UInt64 = 0
    private var todayTotalBytes: UInt64 = 0
    private var monthlyTotalBytes: UInt64 = 0
    private var lowTrafficNotifiedSourceIDs: Set<String> = []
    private var lastExternalVPNAutoDisconnectAt: Date?
    private var lastAutoFailoverAt: Date?
    private var keychainValueCache: [String: String] = [:]
    private var keychainMisses: Set<String> = []
    private let autoFailoverCooldown: TimeInterval = 30
    private let maxLogEntryCount = 500
    private let maxTrafficSamples = 10
    static let defaultRuntimeProxyGroupName = "Cusp"
    private static let selectedLanguageKey = "Cusp.selectedLanguage"
    private static let subscriptionRefreshIntervalKey = "Cusp.subscriptionRefreshInterval"
    private static let sourceGroupAliasesKey = "Cusp.sourceGroupAliases"
    private static let sourceGroupOrderKey = "Cusp.sourceGroupOrder"
    private static let strategyGroupPoliciesKey = "Cusp.strategyGroupPolicies"
    static let nodePageSourceIDKey = "Cusp.nodePageSourceID"
    private static let nodeSortModeKey = "Cusp.nodeSortMode"
    static let customStrategyGroupsKey = "Cusp.customStrategyGroups"
    private static let activeRuntimeProxyGroupNameKey = "Cusp.activeRuntimeProxyGroupName"
    static let launchAtLoginEnabledKey = "Cusp.launchAtLoginEnabled"
    static let restoreConnectionOnLaunchKey = "Cusp.restoreConnectionOnLaunchEnabled"
    static let notificationEnabledKey = "Cusp.notificationEnabled"
    static let disconnectWhenOtherVPNActiveKey = "Cusp.disconnectWhenOtherVPNActiveEnabled"
    private static let wasConnectedOnExitKey = "Cusp.wasConnectedOnExit"
    private static let todayTrafficDateKey = "Cusp.todayTrafficDate"
    private static let monthlyTrafficTagKey = "Cusp.monthlyTrafficTag"
    private static let todayTrafficBytesKey = "Cusp.todayTrafficBytes"
    private static let monthlyTrafficBytesKey = "Cusp.monthlyTrafficBytes"
    private static let lowTrafficNotifiedSourceIDsKey = "Cusp.lowTrafficNotifiedSourceIDs"
    private static let strategyGroupSwitchRecordsKey = "Cusp.strategyGroupSwitchRecords"
    static let didSeedDefaultStrategyGroupsKey = "Cusp.didSeedDefaultStrategyGroups"
    private static let keychainNodePasswordPrefix = "node-password:"
    private static let keychainSubscriptionURLPrefix = "subscription-url:"

    init(
        store: SharedConfigurationStore = (try? SharedConfigurationStore()) ?? SharedConfigurationStore(userDefaults: .standard),
        proxyService: LocalProxyManagerService = LocalProxyManagerService(),
        credentialStore: SecureCredentialStore = SecureCredentialStore()
    ) {
        self.store = store
        self.proxyService = proxyService
        self.credentialStore = credentialStore
        let savedLanguage = UserDefaults.standard.string(forKey: Self.selectedLanguageKey) ?? ""
        self.selectedLanguage = AppLanguage(rawValue: savedLanguage) ?? .english
        let savedRefreshInterval = UserDefaults.standard.string(forKey: Self.subscriptionRefreshIntervalKey) ?? ""
        self.selectedSubscriptionRefreshInterval = SubscriptionRefreshInterval(rawValue: savedRefreshInterval) ?? .manual
        self.sourceGroupAliases = UserDefaults.standard.dictionary(forKey: Self.sourceGroupAliasesKey) as? [String: String] ?? [:]
        self.sourceGroupOrder = UserDefaults.standard.stringArray(forKey: Self.sourceGroupOrderKey) ?? []
        self.strategyGroupPolicies = UserDefaults.standard.dictionary(forKey: Self.strategyGroupPoliciesKey) as? [String: String] ?? [:]
        self.selectedSourceFilterID = UserDefaults.standard.string(forKey: Self.nodePageSourceIDKey)
        let savedSortMode = UserDefaults.standard.string(forKey: Self.nodeSortModeKey) ?? ""
        let restoredSortMode = NodeSortMode(rawValue: savedSortMode) ?? .latency
        self.nodeSortMode = restoredSortMode == .manual ? .latency : restoredSortMode
        self.activeRuntimeProxyGroupName = UserDefaults.standard.string(forKey: Self.activeRuntimeProxyGroupNameKey) ?? Self.defaultRuntimeProxyGroupName
        self.customStrategyGroups = Self.loadCustomStrategyGroups()
        self.strategyGroupSwitchRecords = Self.loadStrategyGroupSwitchRecords()
        self.launchAtLoginEnabled = UserDefaults.standard.object(forKey: Self.launchAtLoginEnabledKey) == nil
            ? (SMAppService.mainApp.status == .enabled)
            : UserDefaults.standard.bool(forKey: Self.launchAtLoginEnabledKey)
        self.restoreConnectionOnLaunchEnabled = UserDefaults.standard.object(forKey: Self.restoreConnectionOnLaunchKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.restoreConnectionOnLaunchKey)
        self.notificationEnabled = UserDefaults.standard.object(forKey: Self.notificationEnabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.notificationEnabledKey)
        self.disconnectWhenOtherVPNActiveEnabled = UserDefaults.standard.object(forKey: Self.disconnectWhenOtherVPNActiveKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.disconnectWhenOtherVPNActiveKey)
        self.connectionState = proxyService.connectionState
        self.todayTotalBytes = UInt64(UserDefaults.standard.integer(forKey: Self.todayTrafficBytesKey))
        self.monthlyTotalBytes = UInt64(UserDefaults.standard.integer(forKey: Self.monthlyTrafficBytesKey))
        self.lowTrafficNotifiedSourceIDs = Set(UserDefaults.standard.stringArray(forKey: Self.lowTrafficNotifiedSourceIDsKey) ?? [])
        self.todayTotalText = Self.byteFormatter.string(fromByteCount: Int64(todayTotalBytes))
        self.monthlyTotalText = Self.byteFormatter.string(fromByteCount: Int64(monthlyTotalBytes))
        self.proxyService.statusDidChange = { [weak self] state in
            self?.connectionState = state
        }
    }

    deinit {
        metricsRefreshTask?.cancel()
        autoRefreshTask?.cancel()
        trafficRefreshTask?.cancel()
        externalVPNMonitorTask?.cancel()
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }
        hasBootstrapped = true

        if let catalog = try? store.loadSubscriptionCatalog() {
            hydrate(from: catalog)
        } else if let catalog = try? store.loadCatalog() {
            hydrate(from: legacySubscriptionCatalog(from: catalog))
        } else {
            activeConfiguration = try? store.load()
            availableConfigurations = activeConfiguration.map { [$0] } ?? []
        }

        do {
            try proxyService.prepare()
            proxyPreparationError = nil
        } catch {
            proxyPreparationError = friendlyProxyPreparationError(error)
            lastErrorMessage = proxyPreparationError
        }

        connectionState = proxyService.connectionState
        refreshReadiness()
        normalizeTrafficCountersIfNeeded()
        startMetricsRefreshLoop()
        startTrafficRefreshLoop()
        startExternalVPNMonitorLoop()
        configureAutoRefreshTask()
        configureLaunchAtLogin()
        if notificationEnabled {
            requestNotificationAuthorizationIfNeeded()
        }
        if restoreConnectionOnLaunchEnabled && UserDefaults.standard.bool(forKey: Self.wasConnectedOnExitKey) {
            attemptStartupReconnectIfPossible()
        }
        await refreshOverviewMetrics()
    }

    func toggleConnection() {
        Task {
            do {
                isApplyingRuntimeChange = true
                runtimeActivityMessage = connectionState == .connected || connectionState == .connecting
                    ? "Disconnecting proxy runtime..."
                    : "Starting proxy runtime..."
                defer {
                    isApplyingRuntimeChange = false
                    runtimeActivityMessage = nil
                }

                if connectionState == .connected || connectionState == .connecting {
                    try proxyService.stop()
                    lastActionMessage = "System proxy disabled."
                    UserDefaults.standard.set(false, forKey: Self.wasConnectedOnExitKey)
                    sendNotificationIfNeeded(
                        title: selectedLanguage == .simplifiedChinese ? "Cusp 已断开" : "Cusp Disconnected",
                        body: selectedLanguage == .simplifiedChinese ? "系统代理已关闭。" : "System proxy has been disabled."
                    )
                } else {
                    guard readinessReport.isReady else {
                        let missing = readinessReport.blockingItems.map(\.title).joined(separator: ", ")
                        lastActionMessage = nil
                        lastErrorMessage = "Cusp is not ready to trial yet: \(missing)."
                        return
                    }
                    guard let activeConfiguration else {
                        lastActionMessage = nil
                        lastErrorMessage = "Save a valid ss:// node before connecting."
                        return
                    }
                    try proxyService.start(
                        with: activeConfiguration,
                        allConfigurations: runtimeConfigurationCandidates(),
                        mode: selectedRuntimeMode,
                        routingRules: routingRules,
                        proxyGroups: runtimeProxyGroups(),
                        activeProxyGroupName: activeRuntimeProxyGroupName
                    )
                    lastActionMessage = "mihomo started and macOS proxy was enabled."
                    UserDefaults.standard.set(true, forKey: Self.wasConnectedOnExitKey)
                    resetSessionTraffic()
                    sendNotificationIfNeeded(
                        title: selectedLanguage == .simplifiedChinese ? "Cusp 已连接" : "Cusp Connected",
                        body: selectedLanguage == .simplifiedChinese ? "代理连接成功。" : "Proxy connection established."
                    )
                }
                lastErrorMessage = nil
                refreshReadiness()
                await refreshOverviewMetrics()
            } catch {
                lastActionMessage = nil
                lastErrorMessage = error.localizedDescription
                sendNotificationIfNeeded(
                    title: selectedLanguage == .simplifiedChinese ? "Cusp 连接失败" : "Cusp Connection Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    func pasteConfigurationFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            lastActionMessage = nil
            lastErrorMessage = "Clipboard does not contain a valid ss:// string."
            return
        }

        importText = value
        lastActionMessage = "Pasted configuration from clipboard."
        lastErrorMessage = nil
    }

    func clearImportedConfiguration() {
        clearCurrentSecretsFromKeychain()
        store.clear()
        activeConfiguration = nil
        availableConfigurations = []
        subscriptionSources = []
        catalogNodes = []
        selectedRuntimeMode = .rules
        routingRules = RoutingRulePreset.commonMVP
        selectedSourceFilterID = nil
        UserDefaults.standard.removeObject(forKey: Self.nodePageSourceIDKey)
        activeRuntimeProxyGroupName = Self.defaultRuntimeProxyGroupName
        UserDefaults.standard.removeObject(forKey: Self.activeRuntimeProxyGroupNameKey)
        customStrategyGroups = []
        strategyGroupSwitchRecords = [:]
        nodeSortMode = .latency
        importText = ""
        subscriptionNameInput = ""
        connectionState = proxyService.connectionState
        latencyText = "-- ms"
        ipAddressText = "--"
        syncStrategyGroupPreferences()
        lastActionMessage = "Cleared the saved configuration."
        lastErrorMessage = nil
        refreshReadiness()
    }

    func selectRuntimeMode(_ mode: RuntimeMode) {
        guard !isApplyingRuntimeChange else {
            return
        }
        guard mode != selectedRuntimeMode else {
            return
        }

        let previousMode = selectedRuntimeMode
        selectedRuntimeMode = mode
        persistCurrentSubscriptionCatalog()

        guard connectionState == .connected, let activeConfiguration else {
            lastActionMessage = "Runtime mode set to \(mode.rawValue.capitalized)."
            lastErrorMessage = nil
            refreshReadiness()
            return
        }

        Task {
            do {
                isApplyingRuntimeChange = true
                runtimeActivityMessage = "Applying \(mode.rawValue.capitalized) mode..."
                defer {
                    isApplyingRuntimeChange = false
                    runtimeActivityMessage = nil
                }

                try proxyService.stop()
                try proxyService.start(
                    with: activeConfiguration,
                    allConfigurations: runtimeConfigurationCandidates(),
                    mode: mode,
                    routingRules: routingRules,
                    proxyGroups: runtimeProxyGroups(),
                    activeProxyGroupName: activeRuntimeProxyGroupName
                )
                lastActionMessage = "Runtime mode switched to \(mode.rawValue.capitalized)."
                lastErrorMessage = nil
            } catch {
                selectedRuntimeMode = previousMode
                persistCurrentSubscriptionCatalog()
                lastActionMessage = nil
                lastErrorMessage = error.localizedDescription
            }
            refreshReadiness()
        }
    }

    func resetTrafficStatistics() {
        todayTotalBytes = 0
        monthlyTotalBytes = 0
        sessionUploadBytes = 0
        sessionDownloadBytes = 0
        trafficSamples = []
        uploadRateText = "0 KB/s"
        downloadRateText = "0 KB/s"
        sessionUploadText = "0 B"
        sessionDownloadText = "0 B"
        todayTotalText = "0 B"
        monthlyTotalText = "0 B"
        UserDefaults.standard.set(0, forKey: Self.todayTrafficBytesKey)
        UserDefaults.standard.set(0, forKey: Self.monthlyTrafficBytesKey)
        lastActionMessage = selectedLanguage == .simplifiedChinese ? "已重置流量统计。" : "Traffic statistics reset."
        lastErrorMessage = nil
    }

    func copyTerminalProxyCommand() {
        let host = CuspConstants.localProxyHost
        let httpURL = "http://\(host):\(CuspConstants.localHTTPProxyPort)"
        let socksURL = "socks5://\(host):\(CuspConstants.localSOCKSProxyPort)"
        let enableLine = "export http_proxy=\(httpURL) https_proxy=\(httpURL) all_proxy=\(socksURL) HTTP_PROXY=\(httpURL) HTTPS_PROXY=\(httpURL) ALL_PROXY=\(socksURL)"
        let disableLine = "unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY"
        let text = """
\(enableLine)
\(disableLine)
"""

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已复制终端代理命令。"
            : "Copied terminal proxy commands."
        lastErrorMessage = nil
    }

    func copySystemProxyCommand() {
        let services = proxyService.availableNetworkServices
        guard !services.isEmpty else {
            lastActionMessage = nil
            lastErrorMessage = selectedLanguage == .simplifiedChinese
                ? "没有可用网络服务，无法生成系统代理命令。"
                : "No available network services. Unable to generate system proxy commands."
            return
        }

        let commands: [ProxyCommand]
        if connectionState == .connected || connectionState == .connecting {
            commands = SystemProxyCommandBuilder.disableCommands(services: services)
        } else {
            commands = SystemProxyCommandBuilder.enableCommands(
                services: services,
                host: CuspConstants.localProxyHost,
                httpPort: CuspConstants.localHTTPProxyPort,
                socksPort: CuspConstants.localSOCKSProxyPort
            )
        }

        let text = commands.map { command in
            let escaped = command.arguments.map { argument in
                "\"\(argument.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return "sudo \(command.launchPath) \(escaped.joined(separator: " "))"
        }
        .joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "已复制系统代理命令。"
            : "Copied system proxy commands."
        lastErrorMessage = nil
    }

    func copyLogsToClipboard() {
        let exportText = buildLogsExportText()
        guard !exportText.isEmpty else {
            lastActionMessage = "No logs to copy."
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportText, forType: .string)
        lastActionMessage = "Copied \(logEntries.count) log entries."
    }

    func clearLogs() {
        logEntries.removeAll()
    }

    private func startMetricsRefreshLoop() {
        metricsRefreshTask?.cancel()
        metricsRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshOverviewMetrics()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    func refreshOverviewMetrics() async {
        let currentConfiguration = activeConfiguration
        async let ipResult = fetchPublicIPAddress()
        async let latencyResult: (String, NodeLatencyProbe.ProbeResult?) = {
            guard let currentConfiguration else {
                return ("-- ms", nil)
            }
            let probeResult = await NodeLatencyProbe.measureLatency(
                host: currentConfiguration.host,
                port: currentConfiguration.port
            )
            if let latency = probeResult.latencyMs {
                return ("\(latency) ms", probeResult)
            }
            return (probeResult.status == .timeout ? "Timeout" : "-- ms", probeResult)
        }()

        let (ipText, latencyPayload) = await (ipResult, latencyResult)
        let (latencyValue, probeResult) = latencyPayload
        latencyText = latencyValue
        ipAddressText = ipText

        if let currentConfiguration, let probeResult {
            updateProbeResult(for: currentConfiguration.stableID, result: probeResult)
            handleAutoFailoverIfNeeded(currentConfiguration: currentConfiguration, probeResult: probeResult)
        }
    }

    private func updateProbeResult(for stableID: String, result: NodeLatencyProbe.ProbeResult) {
        guard let index = catalogNodes.firstIndex(where: { $0.stableID == stableID }) else {
            return
        }

        let existing = catalogNodes[index]
        let resolvedLatency: Int?
        if result.status == .success, existing.latestLatencyMs != nil {
            // Keep list-card latency stable (typically from full speed test), and
            // only refresh status for periodic active-node probes.
            resolvedLatency = existing.latestLatencyMs
        } else {
            resolvedLatency = result.latencyMs
        }

        if existing.latestLatencyMs == resolvedLatency, existing.probeStatus == result.status {
            return
        }

        catalogNodes[index] = CatalogNode(
            configuration: existing.configuration,
            sourceID: existing.sourceID,
            latestLatencyMs: resolvedLatency,
            lastProbeAt: Date(),
            probeStatus: result.status
        )
        persistCurrentSubscriptionCatalog()
    }

    private func handleAutoFailoverIfNeeded(
        currentConfiguration: ShadowsocksConfiguration,
        probeResult: NodeLatencyProbe.ProbeResult
    ) {
        guard connectionState == .connected, !isApplyingRuntimeChange else {
            return
        }
        guard probeResult.status == .failure || probeResult.status == .timeout else {
            return
        }
        guard
            let activeCustomGroup = activeCustomStrategyGroup(),
            activeCustomGroup.type == .fallback,
            normalizedMihomoGroupName(activeCustomGroup.name) == activeRuntimeProxyGroupName,
            let currentNode = catalogNodes.first(where: { $0.stableID == currentConfiguration.stableID }),
            currentNode.sourceID == activeCustomGroup.sourceID
        else {
            return
        }

        if let lastAutoFailoverAt, Date().timeIntervalSince(lastAutoFailoverAt) < autoFailoverCooldown {
            return
        }

        let sameGroupNodes = catalogNodes
            .filter { $0.sourceID == activeCustomGroup.sourceID && $0.stableID != currentNode.stableID }
        guard let candidate = preferredNode(in: sameGroupNodes, policy: .fallback) else {
            return
        }
        guard candidate.stableID != currentNode.stableID else {
            return
        }

        lastAutoFailoverAt = Date()
        selectConfiguration(id: candidate.stableID)
        markStrategyGroupSwitched(id: activeCustomGroup.id, source: .autoFailover, at: lastAutoFailoverAt ?? Date())
        let groupName = activeCustomGroup.name
        lastActionMessage = selectedLanguage == .simplifiedChinese
            ? "检测到节点不可用，已按策略组「\(groupName)」自动切换。"
            : "Detected node failure and auto-switched by strategy group \"\(groupName)\"."
    }

    private func fetchPublicIPAddress() async -> String {
        let endpoints = [
            "https://api.ipify.org",
            "https://ipv4.icanhazip.com",
            "https://ifconfig.me/ip"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else {
                continue
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 6
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Cusp/1.0", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continue
                }
                let value = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            } catch {
                continue
            }
        }

        return "--"
    }

    func refreshReadiness() {
        let lastTunnelError = store.loadLastTunnelError()
        readinessReport = MVPReadinessEvaluator.report(
            hasConfiguration: activeConfiguration != nil,
            hasBundledBinary: hasBundledMihomoBinary(),
            hasNetworkServices: !proxyService.availableNetworkServices.isEmpty,
            proxyPreparationError: lastTunnelError ?? proxyPreparationError
        )
        setupGuide = TrialSetupGuideBuilder.build(from: readinessReport)

        if let lastTunnelError, !lastTunnelError.isEmpty,
           connectionState == .disconnected || connectionState == .invalid {
            lastErrorMessage = lastTunnelError
        }
    }

    private func hasBundledMihomoBinary() -> Bool {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.url(forResource: "mihomo", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("mihomo"),
            locateProjectRoot()?.appendingPathComponent("Resources/mihomo/mihomo")
        ]
        .compactMap { $0 }

        return candidates.contains { fileManager.isExecutableFile(atPath: $0.path) || fileManager.fileExists(atPath: $0.path) }
    }

    private func friendlyProxyPreparationError(_ error: Error) -> String {
        let description = error.localizedDescription
        if description.lowercased().contains("authorization")
            || description.lowercased().contains("permission")
            || description.lowercased().contains("administrator") {
            return "System proxy access failed. Cusp may need permission to change network settings on this Mac."
        }

        return "Local proxy runtime is not ready: \(description)"
    }

    private func locateProjectRoot() -> URL? {
        let candidates = [
            Bundle.main.bundleURL,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ]

        for candidate in candidates {
            var current = candidate
            for _ in 0..<8 {
                if FileManager.default.fileExists(atPath: current.appendingPathComponent("Cusp.xcodeproj").path) {
                    return current
                }
                current.deleteLastPathComponent()
            }
        }

        return nil
    }

    func hydrate(from catalog: SubscriptionCatalog) {
        let restoredCatalog = restoreSensitiveValues(in: catalog)
        subscriptionSources = restoredCatalog.sources
        catalogNodes = restoredCatalog.nodes
        selectedRuntimeMode = restoredCatalog.selectedMode
        routingRules = restoredCatalog.routingRules.isEmpty ? RoutingRulePreset.commonMVP : restoredCatalog.routingRules
        activeConfiguration = selectedConfiguration(from: restoredCatalog)
        syncStrategyGroupPreferences()
        ensureDefaultStrategyGroupsIfNeeded()
        ensureSelectedNodeSourceSelection()
        availableConfigurations = visibleCatalogNodes.map(\.configuration)
        persistCurrentSubscriptionCatalog()
    }

    private func legacySubscriptionCatalog(from catalog: NodeCatalog) -> SubscriptionCatalog {
        let source = SubscriptionSource(
            id: "manual-import",
            name: "Manual Import",
            urlString: "",
            isEnabled: true,
            lastRefreshAt: nil,
            lastRefreshStatus: .idle,
            lastErrorMessage: nil,
            usageInfo: nil
        )
        let nodes = catalog.nodes.map {
            CatalogNode(
                configuration: $0,
                sourceID: source.id,
                latestLatencyMs: nil,
                lastProbeAt: nil,
                probeStatus: .idle
            )
        }

        return SubscriptionCatalog(
            sources: [source],
            nodes: nodes,
            selectedNodeID: catalog.selectedNodeID ?? nodes.first?.stableID,
            selectedMode: .rules,
            routingRules: RoutingRulePreset.commonMVP
        )
    }

    private func selectedConfiguration(from catalog: NodeCatalog) -> ShadowsocksConfiguration? {
        if let selectedNodeID = catalog.selectedNodeID,
           let selected = catalog.nodes.first(where: { $0.stableID == selectedNodeID }) {
            return selected
        }

        return catalog.nodes.first
    }

    private func selectedConfiguration(from catalog: SubscriptionCatalog) -> ShadowsocksConfiguration? {
        if let selectedNodeID = catalog.selectedNodeID,
           let selected = catalog.nodes.first(where: { $0.stableID == selectedNodeID }) {
            return selected.configuration
        }

        return catalog.nodes.first?.configuration
    }

    func currentSubscriptionCatalog() -> SubscriptionCatalog? {
        guard !subscriptionSources.isEmpty || !catalogNodes.isEmpty else {
            return nil
        }

        return SubscriptionCatalog(
            sources: subscriptionSources,
            nodes: catalogNodes,
            selectedNodeID: activeConfiguration?.stableID,
            selectedMode: selectedRuntimeMode,
            routingRules: routingRules
        )
    }

    func persistCurrentSubscriptionCatalog() {
        guard let catalog = currentSubscriptionCatalog() else {
            return
        }

        _ = try? saveCatalogSecurely(catalog, restoreFromKeychain: false)
        availableConfigurations = visibleCatalogNodes.map(\.configuration)
    }

    @discardableResult
    func saveCatalogSecurely(
        _ catalog: SubscriptionCatalog,
        restoreFromKeychain: Bool = true
    ) throws -> SubscriptionCatalog {
        let catalogWithSensitiveValues = restoreFromKeychain
            ? restoreSensitiveValues(in: catalog)
            : catalog
        let sanitized = sanitizedCatalogForPersistence(catalogWithSensitiveValues)
        try store.saveSubscriptionCatalog(sanitized)
        return catalogWithSensitiveValues
    }

    private func restoreSensitiveValues(in catalog: SubscriptionCatalog) -> SubscriptionCatalog {
        let restoredSources = catalog.sources.map { source in
            let key = subscriptionURLKey(sourceID: source.id)
            let effectiveURL: String
            if let stored = keychainString(for: key), !stored.isEmpty {
                effectiveURL = stored
            } else {
                effectiveURL = source.urlString
                if !effectiveURL.isEmpty {
                    setKeychainString(effectiveURL, for: key)
                }
            }
            return SubscriptionSource(
                id: source.id,
                name: source.name,
                urlString: effectiveURL,
                isEnabled: source.isEnabled,
                lastRefreshAt: source.lastRefreshAt,
                lastRefreshStatus: source.lastRefreshStatus,
                lastErrorMessage: source.lastErrorMessage,
                usageInfo: source.usageInfo
            )
        }

        let restoredNodes = catalog.nodes.map { node in
            let key = nodePasswordKey(sourceID: node.sourceID, stableID: node.stableID)
            let effectivePassword: String
            if let stored = keychainString(for: key), !stored.isEmpty {
                effectivePassword = stored
            } else {
                effectivePassword = node.configuration.password
                if !effectivePassword.isEmpty {
                    setKeychainString(effectivePassword, for: key)
                }
            }
            let restoredConfiguration = configuration(node.configuration, replacingPassword: effectivePassword)
            return CatalogNode(
                configuration: restoredConfiguration,
                sourceID: node.sourceID,
                latestLatencyMs: node.latestLatencyMs,
                lastProbeAt: node.lastProbeAt,
                probeStatus: node.probeStatus
            )
        }

        return SubscriptionCatalog(
            sources: restoredSources,
            nodes: restoredNodes,
            selectedNodeID: catalog.selectedNodeID,
            selectedMode: catalog.selectedMode,
            routingRules: catalog.routingRules
        )
    }

    private func sanitizedCatalogForPersistence(_ catalog: SubscriptionCatalog) -> SubscriptionCatalog {
        let sanitizedSources = catalog.sources.map { source in
            let sanitizedURL = sanitizedSubscriptionURL(source.urlString)
            return SubscriptionSource(
                id: source.id,
                name: source.name,
                urlString: sanitizedURL,
                isEnabled: source.isEnabled,
                lastRefreshAt: source.lastRefreshAt,
                lastRefreshStatus: source.lastRefreshStatus,
                lastErrorMessage: source.lastErrorMessage,
                usageInfo: source.usageInfo
            )
        }
        let sanitizedNodes = catalog.nodes.map { node in
            let sanitizedConfiguration = configuration(node.configuration, replacingPassword: "")
            return CatalogNode(
                configuration: sanitizedConfiguration,
                sourceID: node.sourceID,
                latestLatencyMs: node.latestLatencyMs,
                lastProbeAt: node.lastProbeAt,
                probeStatus: node.probeStatus
            )
        }

        return SubscriptionCatalog(
            sources: sanitizedSources,
            nodes: sanitizedNodes,
            selectedNodeID: catalog.selectedNodeID,
            selectedMode: catalog.selectedMode,
            routingRules: catalog.routingRules
        )
    }

    func configurationDisplayName(_ configuration: ShadowsocksConfiguration) -> String {
        let remark = configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let remark, !remark.isEmpty {
            return remark
        }

        return configuration.host
    }

    func configuration(
        _ configuration: ShadowsocksConfiguration,
        replacingRemark remark: String?
    ) -> ShadowsocksConfiguration {
        ShadowsocksConfiguration(
            host: configuration.host,
            port: configuration.port,
            method: configuration.method,
            password: configuration.password,
            remark: remark,
            protocolType: configuration.protocolType,
            uuid: configuration.uuid,
            tls: configuration.tls,
            skipCertVerify: configuration.skipCertVerify,
            flow: configuration.flow,
            clientFingerprint: configuration.clientFingerprint,
            serverName: configuration.serverName,
            udp: configuration.udp,
            alterID: configuration.alterID,
            network: configuration.network,
            wsPath: configuration.wsPath,
            wsHost: configuration.wsHost
        )
    }

    private func configuration(
        _ configuration: ShadowsocksConfiguration,
        replacingPassword password: String
    ) -> ShadowsocksConfiguration {
        ShadowsocksConfiguration(
            host: configuration.host,
            port: configuration.port,
            method: configuration.method,
            password: password,
            remark: configuration.remark,
            protocolType: configuration.protocolType,
            uuid: configuration.uuid,
            tls: configuration.tls,
            skipCertVerify: configuration.skipCertVerify,
            flow: configuration.flow,
            clientFingerprint: configuration.clientFingerprint,
            serverName: configuration.serverName,
            udp: configuration.udp,
            alterID: configuration.alterID,
            network: configuration.network,
            wsPath: configuration.wsPath,
            wsHost: configuration.wsHost
        )
    }

    func subscriptionURLKey(sourceID: String) -> String {
        "\(Self.keychainSubscriptionURLPrefix)\(sourceID)"
    }

    func nodePasswordKey(sourceID: String, stableID: String) -> String {
        "\(Self.keychainNodePasswordPrefix)\(sourceID):\(stableID)"
    }

    private func sanitizedSubscriptionURL(_ urlString: String) -> String {
        guard !urlString.isEmpty, var components = URLComponents(string: urlString) else {
            return urlString
        }
        if components.queryItems?.isEmpty == false {
            components.queryItems = nil
            components.percentEncodedQuery = nil
        }
        return components.string ?? urlString
    }

    private func clearCurrentSecretsFromKeychain() {
        for source in subscriptionSources {
            removeKeychainValue(for: subscriptionURLKey(sourceID: source.id))
        }
        for node in catalogNodes {
            removeKeychainValue(for: nodePasswordKey(sourceID: node.sourceID, stableID: node.stableID))
        }
    }

    func keychainString(for account: String) -> String? {
        if let cached = keychainValueCache[account] {
            return cached
        }
        if keychainMisses.contains(account) {
            return nil
        }

        let value = credentialStore.string(for: account)
        if let value, !value.isEmpty {
            keychainValueCache[account] = value
            return value
        }

        keychainMisses.insert(account)
        return nil
    }

    func setKeychainString(_ value: String, for account: String) {
        credentialStore.setString(value, for: account)
        keychainValueCache[account] = value
        keychainMisses.remove(account)
    }

    func removeKeychainValue(for account: String) {
        credentialStore.removeValue(for: account)
        keychainValueCache.removeValue(forKey: account)
        keychainMisses.insert(account)
    }

    func uniqueDuplicateNodeName(base: String) -> String {
        let existingNames = Set(catalogNodes.compactMap {
            nonEmptyTrimmed($0.configuration.remark)
        })

        let suffix = selectedLanguage == .simplifiedChinese ? "副本" : "Copy"
        var candidate = "\(base) \(suffix)"
        var index = 2
        while existingNames.contains(candidate) {
            candidate = "\(base) \(suffix) \(index)"
            index += 1
        }
        return candidate
    }

    func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func reconcileSelectionIfNeeded() {
        let enabledSourceIDs = Set(subscriptionSources.filter(\.isEnabled).map(\.id))
        ensureSelectedNodeSourceSelection()
        let visibleNodes = catalogNodes.filter {
            enabledSourceIDs.contains($0.sourceID)
                && (selectedSourceFilterID == nil || $0.sourceID == selectedSourceFilterID)
        }
        guard let activeConfiguration else {
            availableConfigurations = visibleNodes.map(\.configuration)
            return
        }

        if visibleNodes.contains(where: { $0.stableID == activeConfiguration.stableID }) {
            availableConfigurations = visibleNodes.map(\.configuration)
            return
        }

        self.activeConfiguration = visibleNodes.first?.configuration
        availableConfigurations = visibleNodes.map(\.configuration)
    }

    private func appendLog(level: AppLogLevel, category: String, message: String) {
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else {
            return
        }

        logEntries.append(
            AppLogEntry(
                level: level,
                category: category,
                message: normalizedMessage
            )
        )

        if logEntries.count > maxLogEntryCount {
            logEntries.removeFirst(logEntries.count - maxLogEntryCount)
        }
    }

    func syncStrategyGroupPreferences() {
        let sourceIDs = subscriptionSources.map(\.id)
        let sourceIDSet = Set(sourceIDs)

        var updatedOrder = sourceGroupOrder.filter { sourceIDSet.contains($0) }
        for id in sourceIDs where !updatedOrder.contains(id) {
            updatedOrder.append(id)
        }
        if updatedOrder != sourceGroupOrder {
            sourceGroupOrder = updatedOrder
        }

        let filteredAliases = sourceGroupAliases.filter { sourceIDSet.contains($0.key) }
        if filteredAliases != sourceGroupAliases {
            sourceGroupAliases = filteredAliases
        }

        let filteredPolicies = strategyGroupPolicies.filter { sourceIDSet.contains($0.key) }
        if filteredPolicies != strategyGroupPolicies {
            strategyGroupPolicies = filteredPolicies
        }

        customStrategyGroups = customStrategyGroups.filter { sourceIDSet.contains($0.sourceID) }
        let validCustomGroupIDs = Set(customStrategyGroups.map(\.id))
        strategyGroupSwitchRecords = strategyGroupSwitchRecords.filter { validCustomGroupIDs.contains($0.key) }
        let validRuntimeGroups = Set(customStrategyGroups.map { normalizedMihomoGroupName($0.name) })
        if activeRuntimeProxyGroupName != Self.defaultRuntimeProxyGroupName,
           !validRuntimeGroups.contains(activeRuntimeProxyGroupName) {
            activeRuntimeProxyGroupName = Self.defaultRuntimeProxyGroupName
        }
        ensureSelectedNodeSourceSelection()
    }

    private func ensureSelectedNodeSourceSelection() {
        let enabledSourceIDs = subscriptionSources.filter(\.isEnabled).map(\.id)
        guard !enabledSourceIDs.isEmpty else {
            selectedSourceFilterID = nil
            UserDefaults.standard.removeObject(forKey: Self.nodePageSourceIDKey)
            return
        }

        if let selectedSourceFilterID, enabledSourceIDs.contains(selectedSourceFilterID) {
            return
        }

        selectedSourceFilterID = enabledSourceIDs[0]
        UserDefaults.standard.set(selectedSourceFilterID, forKey: Self.nodePageSourceIDKey)
    }

    private func buildLogsExportText() -> String {
        guard !logEntries.isEmpty else {
            return ""
        }

        return logEntries.map { entry in
            let timestamp = Self.logTimestampFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        }
        .joined(separator: "\n")
    }

    func sendNotificationIfNeeded(title: String, body: String) {
        guard notificationEnabled else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "Cusp-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func attemptStartupReconnectIfPossible() {
        guard connectionState == .disconnected, readinessReport.isReady, activeConfiguration != nil else {
            return
        }
        toggleConnection()
    }

    func restartRuntimeIfNeededAfterRuleChange() {
        guard connectionState == .connected, let activeConfiguration else {
            return
        }
        Task {
            do {
                try proxyService.stop()
                try proxyService.start(
                    with: activeConfiguration,
                    allConfigurations: runtimeConfigurationCandidates(),
                    mode: selectedRuntimeMode,
                    routingRules: routingRules,
                    proxyGroups: runtimeProxyGroups(),
                    activeProxyGroupName: activeRuntimeProxyGroupName
                )
                lastActionMessage = selectedLanguage == .simplifiedChinese
                    ? "规则已应用。"
                    : "Rules applied."
                lastErrorMessage = nil
            } catch {
                lastActionMessage = nil
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func startTrafficRefreshLoop() {
        trafficRefreshTask?.cancel()
        trafficRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refreshTrafficMetrics()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startExternalVPNMonitorLoop() {
        externalVPNMonitorTask?.cancel()
        externalVPNMonitorTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.checkExternalVPNConflict()
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    private func checkExternalVPNConflict() async {
        guard disconnectWhenOtherVPNActiveEnabled else {
            return
        }
        guard connectionState == .connected else {
            return
        }
        guard externalVPNLooksActive() else {
            return
        }
        if let last = lastExternalVPNAutoDisconnectAt, Date().timeIntervalSince(last) < 15 {
            return
        }

        lastExternalVPNAutoDisconnectAt = Date()
        do {
            try proxyService.stop()
            lastActionMessage = selectedLanguage == .simplifiedChinese
                ? "检测到其他 VPN 已连接，Cusp 已自动断开。"
                : "Detected another active VPN. Cusp disconnected automatically."
            lastErrorMessage = nil
            UserDefaults.standard.set(false, forKey: Self.wasConnectedOnExitKey)
            sendNotificationIfNeeded(
                title: selectedLanguage == .simplifiedChinese ? "Cusp 已自动断开" : "Cusp Auto Disconnected",
                body: selectedLanguage == .simplifiedChinese ? "检测到系统已有其他 VPN 连接。" : "Another VPN connection was detected on this Mac."
            )
        } catch {
            lastActionMessage = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    private func externalVPNLooksActive() -> Bool {
        let process = Process()
        let stdout = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--nwi"]
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return false
        }

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .lowercased() ?? ""
        return output.contains("utun") || output.contains("ipsec")
    }

    private func refreshTrafficMetrics() async {
        normalizeTrafficCountersIfNeeded()
        guard let current = currentNetworkByteSnapshot() else {
            return
        }

        defer {
            lastTrafficSnapshot = current
        }

        guard let previous = lastTrafficSnapshot else {
            lastTrafficSnapshot = current
            return
        }

        let deltaSeconds = max(0.001, current.timestamp.timeIntervalSince(previous.timestamp))
        let uploadDelta = current.uploadBytes >= previous.uploadBytes ? current.uploadBytes - previous.uploadBytes : 0
        let downloadDelta = current.downloadBytes >= previous.downloadBytes ? current.downloadBytes - previous.downloadBytes : 0

        let uploadRate = Double(uploadDelta) / deltaSeconds
        let downloadRate = Double(downloadDelta) / deltaSeconds
        uploadRateText = Self.rateFormatter(bytesPerSecond: uploadRate)
        downloadRateText = Self.rateFormatter(bytesPerSecond: downloadRate)

        guard connectionState == .connected || connectionState == .connecting else {
            return
        }

        sessionUploadBytes += uploadDelta
        sessionDownloadBytes += downloadDelta
        todayTotalBytes += uploadDelta + downloadDelta
        monthlyTotalBytes += uploadDelta + downloadDelta

        sessionUploadText = Self.byteFormatter.string(fromByteCount: Int64(sessionUploadBytes))
        sessionDownloadText = Self.byteFormatter.string(fromByteCount: Int64(sessionDownloadBytes))
        todayTotalText = Self.byteFormatter.string(fromByteCount: Int64(todayTotalBytes))
        monthlyTotalText = Self.byteFormatter.string(fromByteCount: Int64(monthlyTotalBytes))

        UserDefaults.standard.set(Int(todayTotalBytes), forKey: Self.todayTrafficBytesKey)
        UserDefaults.standard.set(Int(monthlyTotalBytes), forKey: Self.monthlyTrafficBytesKey)

        trafficSamples.append(
            TrafficSample(
                uploadBytesPerSecond: uploadRate,
                downloadBytesPerSecond: downloadRate
            )
        )
        if trafficSamples.count > maxTrafficSamples {
            trafficSamples.removeFirst(trafficSamples.count - maxTrafficSamples)
        }
    }

    private func currentNetworkByteSnapshot() -> NetworkByteSnapshot? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        var sent: UInt64 = 0
        var received: UInt64 = 0
        var pointer = firstAddr
        while true {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp && !isLoopback,
               interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                sent += UInt64(data.pointee.ifi_obytes)
                received += UInt64(data.pointee.ifi_ibytes)
            }
            guard let next = interface.ifa_next else {
                break
            }
            pointer = next
        }

        return NetworkByteSnapshot(timestamp: Date(), uploadBytes: sent, downloadBytes: received)
    }

    private func resetSessionTraffic() {
        sessionUploadBytes = 0
        sessionDownloadBytes = 0
        sessionUploadText = "0 B"
        sessionDownloadText = "0 B"
        trafficSamples = []
    }

    private func normalizeTrafficCountersIfNeeded() {
        let now = Date()
        let dateFormatter = Self.dayFormatter
        let monthFormatter = Self.monthFormatter
        let todayTag = dateFormatter.string(from: now)
        let monthTag = monthFormatter.string(from: now)

        let savedTodayTag = UserDefaults.standard.string(forKey: Self.todayTrafficDateKey) ?? todayTag
        let savedMonthTag = UserDefaults.standard.string(forKey: Self.monthlyTrafficTagKey) ?? monthTag

        if savedTodayTag != todayTag {
            todayTotalBytes = 0
            UserDefaults.standard.set(0, forKey: Self.todayTrafficBytesKey)
        }
        if savedMonthTag != monthTag {
            monthlyTotalBytes = 0
            UserDefaults.standard.set(0, forKey: Self.monthlyTrafficBytesKey)
        }

        UserDefaults.standard.set(todayTag, forKey: Self.todayTrafficDateKey)
        UserDefaults.standard.set(monthTag, forKey: Self.monthlyTrafficTagKey)
        todayTotalText = Self.byteFormatter.string(fromByteCount: Int64(todayTotalBytes))
        monthlyTotalText = Self.byteFormatter.string(fromByteCount: Int64(monthlyTotalBytes))
    }

    func notifyIfLowRemainingTraffic() {
        for source in subscriptionSources {
            guard let info = source.usageInfo,
                  let total = info.totalBytes,
                  total > 0 else {
                continue
            }
            let used = max(0, (info.uploadBytes ?? 0) + (info.downloadBytes ?? 0))
            let remainingRatio = Double(max(0, total - used)) / Double(total)
            if remainingRatio <= 0.1 && !lowTrafficNotifiedSourceIDs.contains(source.id) {
                lowTrafficNotifiedSourceIDs.insert(source.id)
                UserDefaults.standard.set(Array(lowTrafficNotifiedSourceIDs), forKey: Self.lowTrafficNotifiedSourceIDsKey)
                sendNotificationIfNeeded(
                    title: selectedLanguage == .simplifiedChinese ? "流量接近上限" : "Traffic Near Limit",
                    body: selectedLanguage == .simplifiedChinese
                        ? "\(source.name) 剩余流量低于 10%。"
                        : "\(source.name) remaining traffic is below 10%."
                )
            }
        }
    }

    private static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static func rateFormatter(bytesPerSecond: Double) -> String {
        let clamped = max(0, bytesPerSecond)
        let amount = byteFormatter.string(fromByteCount: Int64(clamped))
        return "\(amount)/s"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static func loadStrategyGroupSwitchRecords() -> [String: StrategyGroupSwitchRecord] {
        guard let data = UserDefaults.standard.data(forKey: Self.strategyGroupSwitchRecordsKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: StrategyGroupSwitchRecord].self, from: data)) ?? [:]
    }

    private func saveStrategyGroupSwitchRecords() {
        guard let data = try? JSONEncoder().encode(strategyGroupSwitchRecords) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.strategyGroupSwitchRecordsKey)
    }

}
