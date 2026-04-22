import Foundation

struct LocalProjectSetupStatus {
    let appEntitlements: LoadedEntitlements
    let tunnelEntitlements: LoadedEntitlements

    static let empty = LocalProjectSetupStatus(
        appEntitlements: LoadedEntitlements(appGroups: [], networkExtensions: []),
        tunnelEntitlements: LoadedEntitlements(appGroups: [], networkExtensions: [])
    )
}

struct LocalProjectSetupInspector {
    func inspect() -> LocalProjectSetupStatus {
        guard let root = locateProjectRoot() else {
            return .empty
        }

        let appURL = root.appendingPathComponent("CuspApp/Cusp.entitlements")
        let tunnelURL = root.appendingPathComponent("CuspTunnel/CuspTunnel.entitlements")

        let appEntitlements = (try? EntitlementsInspector.load(from: appURL)) ?? .init(appGroups: [], networkExtensions: [])
        let tunnelEntitlements = (try? EntitlementsInspector.load(from: tunnelURL)) ?? .init(appGroups: [], networkExtensions: [])

        return LocalProjectSetupStatus(
            appEntitlements: appEntitlements,
            tunnelEntitlements: tunnelEntitlements
        )
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
}
