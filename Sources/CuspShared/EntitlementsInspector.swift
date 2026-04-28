import Foundation

public struct LoadedEntitlements: Equatable, Sendable {
    public let appGroups: [String]
    public let appSandboxEnabled: Bool

    public init(appGroups: [String], appSandboxEnabled: Bool) {
        self.appGroups = appGroups
        self.appSandboxEnabled = appSandboxEnabled
    }
}

public enum EntitlementsInspector {
    public static func load(from fileURL: URL) throws -> LoadedEntitlements {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadedEntitlements(appGroups: [], appSandboxEnabled: false)
        }

        let data = try Data(contentsOf: fileURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = object as? [String: Any] else {
            return LoadedEntitlements(appGroups: [], appSandboxEnabled: false)
        }

        let groups = dictionary["com.apple.security.app-groups"] as? [String] ?? []
        let sandboxEnabled = dictionary["com.apple.security.app-sandbox"] as? Bool ?? false

        return LoadedEntitlements(
            appGroups: groups,
            appSandboxEnabled: sandboxEnabled
        )
    }
}
