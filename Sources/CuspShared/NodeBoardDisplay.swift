import Foundation

public enum NodeSortMode: String, CaseIterable, Codable, Sendable {
    case manual
    case latency
    case name
}

public enum NodeBoardDisplay {
    public static func visibleNodes(
        from nodes: [CatalogNode],
        sources: [SubscriptionSource],
        selectedSourceFilterID: String?,
        sortMode: NodeSortMode
    ) -> [CatalogNode] {
        var current = nodesForEnabledSources(nodes, sources: sources)

        if let selectedSourceFilterID, !selectedSourceFilterID.isEmpty {
            current = current.filter { $0.sourceID == selectedSourceFilterID }
        }

        return sorted(current, sortMode: sortMode)
    }

    public static func currentViewNodes(
        from nodes: [CatalogNode],
        sources: [SubscriptionSource],
        selectedSourceFilterID: String?,
        searchQuery: String,
        sortMode: NodeSortMode
    ) -> [CatalogNode] {
        var current = visibleNodes(
            from: nodes,
            sources: sources,
            selectedSourceFilterID: selectedSourceFilterID,
            sortMode: .manual
        )

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let matchingIDs = Set(
                NodeFilter.filter(current.map(\.configuration), query: query).map(\.stableID)
            )
            current = current.filter { matchingIDs.contains($0.stableID) }
        }

        return sorted(current, sortMode: sortMode)
    }

    private static func nodesForEnabledSources(
        _ nodes: [CatalogNode],
        sources: [SubscriptionSource]
    ) -> [CatalogNode] {
        let enabledSourceIDs = Set(sources.filter(\.isEnabled).map(\.id))
        return nodes.filter { enabledSourceIDs.contains($0.sourceID) }
    }

    private static func sorted(_ nodes: [CatalogNode], sortMode: NodeSortMode) -> [CatalogNode] {
        switch sortMode {
        case .manual:
            return nodes
        case .latency:
            return NodeLatencyProbe.sortForDisplay(nodes)
        case .name:
            return nodes.sorted { lhs, rhs in
                let leftName = displayName(for: lhs.configuration)
                let rightName = displayName(for: rhs.configuration)
                let compare = leftName.localizedCaseInsensitiveCompare(rightName)
                if compare != .orderedSame {
                    return compare == .orderedAscending
                }
                return lhs.stableID < rhs.stableID
            }
        }
    }

    private static func displayName(for configuration: ShadowsocksConfiguration) -> String {
        let trimmed = configuration.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return configuration.host
    }
}
