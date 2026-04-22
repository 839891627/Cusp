import Foundation

public struct NodeCatalog: Codable, Equatable, Sendable {
    public let nodes: [ShadowsocksConfiguration]
    public let selectedNodeID: String?

    public init(nodes: [ShadowsocksConfiguration], selectedNodeID: String?) {
        self.nodes = nodes
        self.selectedNodeID = selectedNodeID
    }
}
