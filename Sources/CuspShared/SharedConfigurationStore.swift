import Foundation

public final class SharedConfigurationStore {
    public enum Error: Swift.Error {
        case missingAppGroup(String)
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public convenience init(appGroupIdentifier: String = CuspConstants.appGroupIdentifier) throws {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            throw Error.missingAppGroup(appGroupIdentifier)
        }
        self.init(userDefaults: defaults)
    }

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public func save(_ configuration: ShadowsocksConfiguration) throws {
        let data = try encoder.encode(configuration)
        userDefaults.set(data, forKey: CuspConstants.sharedConfigKey)
    }

    public func saveCatalog(_ catalog: NodeCatalog) throws {
        let data = try encoder.encode(catalog)
        userDefaults.set(data, forKey: CuspConstants.sharedNodeCatalogKey)
        userDefaults.set(catalog.selectedNodeID, forKey: CuspConstants.selectedNodeIDKey)

        if let firstNode = catalog.nodes.first {
            try save(firstNode)
        } else {
            clear()
        }
    }

    public func saveSubscriptionCatalog(_ catalog: SubscriptionCatalog) throws {
        let data = try encoder.encode(catalog)
        userDefaults.set(data, forKey: CuspConstants.subscriptionCatalogKey)
        userDefaults.set(catalog.selectedNodeID, forKey: CuspConstants.selectedNodeIDKey)
        userDefaults.set(catalog.selectedMode.rawValue, forKey: CuspConstants.selectedModeKey)

        if let firstNode = catalog.nodes.first {
            try save(firstNode.configuration)
        }
    }

    public func load() throws -> ShadowsocksConfiguration? {
        guard let data = userDefaults.data(forKey: CuspConstants.sharedConfigKey) else {
            return nil
        }
        return try decoder.decode(ShadowsocksConfiguration.self, from: data)
    }

    public func loadCatalog() throws -> NodeCatalog? {
        if let data = userDefaults.data(forKey: CuspConstants.sharedNodeCatalogKey) {
            let catalog = try decoder.decode(NodeCatalog.self, from: data)
            return NodeCatalog(
                nodes: catalog.nodes,
                selectedNodeID: userDefaults.string(forKey: CuspConstants.selectedNodeIDKey) ?? catalog.selectedNodeID
            )
        }

        if let configuration = try load() {
            return NodeCatalog(nodes: [configuration], selectedNodeID: nil)
        }

        return nil
    }

    public func loadSubscriptionCatalog() throws -> SubscriptionCatalog? {
        if let data = userDefaults.data(forKey: CuspConstants.subscriptionCatalogKey) {
            let catalog = try decoder.decode(SubscriptionCatalog.self, from: data)
            return SubscriptionCatalog(
                sources: catalog.sources,
                nodes: catalog.nodes,
                selectedNodeID: userDefaults.string(forKey: CuspConstants.selectedNodeIDKey) ?? catalog.selectedNodeID,
                selectedMode: RuntimeMode(rawValue: userDefaults.string(forKey: CuspConstants.selectedModeKey) ?? "") ?? catalog.selectedMode,
                routingRules: catalog.routingRules
            )
        }

        if let legacyCatalog = try loadCatalog() {
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
            let nodes = legacyCatalog.nodes.map {
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
                selectedNodeID: legacyCatalog.selectedNodeID ?? nodes.first?.stableID,
                selectedMode: .rules,
                routingRules: RoutingRulePreset.commonMVP
            )
        }

        return nil
    }

    public func saveSelectedNodeID(_ id: String?) {
        userDefaults.set(id, forKey: CuspConstants.selectedNodeIDKey)
    }

    public func clear() {
        userDefaults.removeObject(forKey: CuspConstants.sharedConfigKey)
        userDefaults.removeObject(forKey: CuspConstants.sharedNodeCatalogKey)
        userDefaults.removeObject(forKey: CuspConstants.subscriptionCatalogKey)
        userDefaults.removeObject(forKey: CuspConstants.selectedNodeIDKey)
        userDefaults.removeObject(forKey: CuspConstants.selectedModeKey)
    }

    public func saveLastTunnelError(_ message: String) {
        userDefaults.set(message, forKey: CuspConstants.lastTunnelErrorKey)
    }

    public func loadLastTunnelError() -> String? {
        userDefaults.string(forKey: CuspConstants.lastTunnelErrorKey)
    }

    public func clearLastTunnelError() {
        userDefaults.removeObject(forKey: CuspConstants.lastTunnelErrorKey)
    }
}
