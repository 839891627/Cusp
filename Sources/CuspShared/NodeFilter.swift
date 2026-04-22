import Foundation

public enum NodeFilter {
    public static func filter(_ configurations: [ShadowsocksConfiguration], query: String) -> [ShadowsocksConfiguration] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard !normalizedQuery.isEmpty else {
            return configurations
        }

        return configurations.filter { configuration in
            searchableFields(for: configuration).contains { field in
                field.localizedCaseInsensitiveContains(normalizedQuery)
            }
        }
    }

    private static func searchableFields(for configuration: ShadowsocksConfiguration) -> [String] {
        [
            configuration.remark ?? "",
            configuration.host,
            configuration.protocolType.rawValue,
            configuration.method,
            configuration.serverName ?? "",
            configuration.uuid ?? "",
            configuration.network ?? "",
            configuration.wsHost ?? "",
            configuration.wsPath ?? "",
            "\(configuration.port)"
        ]
    }
}
