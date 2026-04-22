import Foundation

public struct LoadedEntitlements: Equatable, Sendable {
    public let appGroups: [String]
    public let networkExtensions: [String]

    public init(appGroups: [String], networkExtensions: [String]) {
        self.appGroups = appGroups
        self.networkExtensions = networkExtensions
    }

    public var supportsPacketTunnel: Bool {
        networkExtensions.contains("packet-tunnel-provider")
    }
}

public enum EntitlementsInspector {
    public static func load(from fileURL: URL) throws -> LoadedEntitlements {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadedEntitlements(appGroups: [], networkExtensions: [])
        }

        let data = try Data(contentsOf: fileURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = object as? [String: Any] else {
            return LoadedEntitlements(appGroups: [], networkExtensions: [])
        }

        let groups = dictionary["com.apple.security.app-groups"] as? [String] ?? []
        let networkExtensions = dictionary["com.apple.developer.networking.networkextension"] as? [String] ?? []

        return LoadedEntitlements(appGroups: groups, networkExtensions: networkExtensions)
    }
}
