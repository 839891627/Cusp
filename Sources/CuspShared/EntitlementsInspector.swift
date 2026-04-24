import Foundation

public struct LoadedEntitlements: Equatable, Sendable {
    public let appGroups: [String]
    public let networkExtensionCapabilities: [String]

    public init(appGroups: [String], networkExtensionCapabilities: [String]) {
        self.appGroups = appGroups
        self.networkExtensionCapabilities = networkExtensionCapabilities
    }

    public var hasNetworkExtensionEntitlement: Bool {
        !networkExtensionCapabilities.isEmpty
    }

    @available(*, deprecated, renamed: "hasNetworkExtensionEntitlement")
    public var supportsPacketTunnel: Bool {
        hasNetworkExtensionEntitlement
    }
}

public enum EntitlementsInspector {
    public static func load(from fileURL: URL) throws -> LoadedEntitlements {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadedEntitlements(appGroups: [], networkExtensionCapabilities: [])
        }

        let data = try Data(contentsOf: fileURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = object as? [String: Any] else {
            return LoadedEntitlements(appGroups: [], networkExtensionCapabilities: [])
        }

        let groups = dictionary["com.apple.security.app-groups"] as? [String] ?? []
        let networkExtensionCapabilities =
            dictionary["com.apple.developer.networking.networkextension"] as? [String] ?? []

        return LoadedEntitlements(
            appGroups: groups,
            networkExtensionCapabilities: networkExtensionCapabilities
        )
    }
}
