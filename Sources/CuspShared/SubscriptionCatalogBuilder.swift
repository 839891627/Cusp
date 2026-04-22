import Foundation

public enum SubscriptionCatalogBuilder {
    public static func merging(
        existing: SubscriptionCatalog,
        sourceID: String? = nil,
        importName: String,
        importURLString: String,
        configurations: [ShadowsocksConfiguration],
        refreshedAt: Date,
        usageInfo: SubscriptionUsageInfo? = nil
    ) -> SubscriptionCatalog {
        let sourceID = sourceID ?? normalizedSourceID(from: importName, fallback: importURLString)
        let source = SubscriptionSource(
            id: sourceID,
            name: importName,
            urlString: importURLString,
            isEnabled: true,
            lastRefreshAt: refreshedAt,
            lastRefreshStatus: .success,
            lastErrorMessage: nil,
            usageInfo: usageInfo
        )
        let replacementNodes = configurations.map {
            CatalogNode(
                configuration: $0,
                sourceID: sourceID,
                latestLatencyMs: nil,
                lastProbeAt: nil,
                probeStatus: .idle
            )
        }
        let otherSources = existing.sources.filter { $0.id != sourceID }
        let otherNodes = existing.nodes.filter { $0.sourceID != sourceID }

        return SubscriptionCatalog(
            sources: otherSources + [source],
            nodes: otherNodes + replacementNodes,
            selectedNodeID: existing.selectedNodeID ?? replacementNodes.first?.stableID,
            selectedMode: existing.selectedMode,
            routingRules: existing.routingRules
        )
    }

    private static func normalizedSourceID(from name: String, fallback: String) -> String {
        let raw = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : name
        let lowered = raw.lowercased()
        let allowed = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }

            return "-"
        }
        let collapsed = String(allowed)
            .split(separator: "-")
            .map(String.init)
            .joined(separator: "-")

        return collapsed.isEmpty ? "subscription-source" : collapsed
    }
}
