import Foundation

public struct SubscriptionCatalog: Codable, Equatable, Sendable {
    public let sources: [SubscriptionSource]
    public let nodes: [CatalogNode]
    public let selectedNodeID: String?
    public let selectedMode: RuntimeMode
    public let routingRules: [RoutingRule]

    public init(
        sources: [SubscriptionSource],
        nodes: [CatalogNode],
        selectedNodeID: String?,
        selectedMode: RuntimeMode,
        routingRules: [RoutingRule] = []
    ) {
        self.sources = sources
        self.nodes = nodes
        self.selectedNodeID = selectedNodeID
        self.selectedMode = selectedMode
        self.routingRules = routingRules
    }

    private enum CodingKeys: String, CodingKey {
        case sources
        case nodes
        case selectedNodeID
        case selectedMode
        case routingRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decode([SubscriptionSource].self, forKey: .sources)
        self.nodes = try container.decode([CatalogNode].self, forKey: .nodes)
        self.selectedNodeID = try container.decodeIfPresent(String.self, forKey: .selectedNodeID)
        self.selectedMode = try container.decode(RuntimeMode.self, forKey: .selectedMode)
        self.routingRules = try container.decodeIfPresent([RoutingRule].self, forKey: .routingRules) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sources, forKey: .sources)
        try container.encode(nodes, forKey: .nodes)
        try container.encodeIfPresent(selectedNodeID, forKey: .selectedNodeID)
        try container.encode(selectedMode, forKey: .selectedMode)
        try container.encode(routingRules, forKey: .routingRules)
    }

    public static let empty = SubscriptionCatalog(
        sources: [],
        nodes: [],
        selectedNodeID: nil,
        selectedMode: .rules,
        routingRules: RoutingRulePreset.commonMVP
    )
}
